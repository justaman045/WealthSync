# Seamless Firebase Project Migration Guide

This guide details how to migrate all users, authentication states, Firestore data, and Storage files from `moneycontroljustaman045` (Account Aman) to `company-24267` (Account Shay) in a way that is completely invisible to the end-user. 

## The "Seamless" Challenge
If you simply swap the `google-services.json` and `GoogleService-Info.plist` in your app update, **all users will be instantly logged out**. This happens because their cached authentication tokens are cryptographically signed by the old project and will be rejected by the new project.

To achieve a true "stealth" migration where users suspect nothing, we must implement a two-part strategy:
1. **Backend Migration:** Clone all data to the new project.
2. **Client-Side Token Exchange:** Ship an app update that temporarily talks to *both* projects to silently migrate the user's active session.

---

## Phase 1: Backend Data Migration

You will need the [Firebase CLI](https://firebase.google.com/docs/cli) and [Google Cloud CLI (`gcloud`)](https://cloud.google.com/sdk/docs/install) installed.

### 1. Migrate Authentication (Users)
This preserves user accounts, UIDs, and passwords (allowing normal logins to work).
1. Login to the old account: `firebase login`
2. Export users: 
   ```bash
   firebase auth:export users.json --format=json --project moneycontroljustaman045
   ```
3. Login to the new account (`Shay`): `firebase login:add`
4. Import users:
   ```bash
   firebase auth:import users.json --project company-24267
   ```

### 2. Migrate Cloud Firestore (Database)
1. Authenticate `gcloud` with the old account: `gcloud auth login`
2. Set the old project: `gcloud config set project moneycontroljustaman045`
3. Create a Cloud Storage bucket in the old project (e.g., `gs://moneycontrol-export-bucket`) via the Google Cloud Console.
4. Export the database:
   ```bash
   gcloud firestore export gs://moneycontrol-export-bucket
   ```
   *(Note the output path, e.g., `gs://moneycontrol-export-bucket/2023-10-27T10:00:00_54321`)*
5. Grant the **Target Project's** default compute service account (`<PROJECT_NUMBER>-compute@developer.gserviceaccount.com`) **Storage Object Admin** access to this bucket.
6. Authenticate `gcloud` with the new account: `gcloud auth login`
7. Set the new project: `gcloud config set project company-24267`
8. Import the database:
   ```bash
   gcloud firestore import gs://moneycontrol-export-bucket/2023-10-27T10:00:00_54321
   ```

### 3. Migrate Firebase Storage (Images/Receipts)
1. Still using the new account in `gcloud`, run the `rsync` command to copy files directly between the project buckets:
   ```bash
   gcloud storage rsync gs://moneycontroljustaman045.appspot.com gs://company-24267.appspot.com --recursive
   ```

---

## Phase 2: The Seamless Client Update (No Logouts)

To prevent users from being logged out when they update the app, you need to ship a "Bridge" update. 

### Step 1: Create a Migration Cloud Function
Deploy a Cloud Function on your **NEW** project (`company-24267`). This function will accept a token from the old project, verify it, and return a Custom Token for the new project.

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize the NEW project admin SDK (default)
admin.initializeApp();

// Initialize the OLD project admin SDK (using a service account key)
const oldProjectApp = admin.initializeApp({
  credential: admin.credential.cert(require('./old-project-service-account.json'))
}, 'oldProject');

exports.migrateSession = functions.https.onCall(async (data, context) => {
    const oldToken = data.oldToken;
    
    try {
        // 1. Verify the token belongs to the old project
        const decodedToken = await oldProjectApp.auth().verifyIdToken(oldToken);
        const uid = decodedToken.uid;

        // 2. Generate a Custom Token for the new project
        const customToken = await admin.auth().createCustomToken(uid);
        
        return { customToken: customToken };
    } catch (error) {
        throw new functions.https.HttpsError('unauthenticated', 'Invalid old token');
    }
});
```

### Step 2: Update the Flutter App Code
In your app update, you will initialize *both* Firebase projects.

1. Keep the old `google-services.json` as the default.
2. Add the new project's configuration manually in Dart.

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Old Project (Default)
  await Firebase.initializeApp(); 
  
  // 2. Initialize New Project (Company)
  final newApp = await Firebase.initializeApp(
    name: 'companyApp',
    options: const FirebaseOptions(
      apiKey: "NEW_API_KEY",
      appId: "NEW_APP_ID",
      messagingSenderId: "NEW_SENDER_ID",
      projectId: "company-24267",
    ),
  );

  runApp(MyApp());
  
  // 3. Perform Silent Migration in the background
  await performSilentMigration(newApp);
}

Future<void> performSilentMigration(FirebaseApp newApp) async {
  final prefs = await SharedPreferences.getInstance();
  final isMigrated = prefs.getBool('is_migrated_to_company') ?? false;
  
  if (isMigrated) return;

  final oldAuth = FirebaseAuth.instance;
  final newAuth = FirebaseAuth.instanceFor(app: newApp);

  // If user is logged into the old project, but not the new one yet
  if (oldAuth.currentUser != null && newAuth.currentUser == null) {
    try {
      // Get token from old project
      final oldToken = await oldAuth.currentUser!.getIdToken();
      
      // Call the Cloud Function on the NEW project
      final functions = FirebaseFunctions.instanceFor(app: newApp);
      final result = await functions.httpsCallable('migrateSession').call({
        'oldToken': oldToken,
      });
      
      final customToken = result.data['customToken'];
      
      // Sign into the new project silently
      await newAuth.signInWithCustomToken(customToken);
      
      // Mark as migrated
      await prefs.setBool('is_migrated_to_company', true);
    } catch (e) {
      print("Migration failed: $e");
    }
  }
}
```

### Step 3: Switch Data Sources
Ensure all your repositories and controllers use the new Firebase instance for data:
```dart
final newApp = Firebase.app('companyApp');
final firestore = FirebaseFirestore.instanceFor(app: newApp);
final storage = FirebaseStorage.instanceFor(app: newApp);
final auth = FirebaseAuth.instanceFor(app: newApp);
```

### Summary of the User Experience
1. The user downloads the app update from the Play Store/App Store.
2. The app opens, and they are still logged in (via the old project's cached session).
3. In the background, the app fetches a token, talks to the new server, and logs them into the new project via `signInWithCustomToken`.
4. All future reads/writes happen on the new `company` project database.
5. The user notices absolutely nothing! After a few months, you can remove the old project initialization entirely in a future update.

---

> 💡 **Alternative (Zero Code / Zero Migration): Transfer Project Ownership**
> 
> If you don't strictly *need* a new Project ID and just want to transfer ownership to Shay:
> 1. In Aman's Firebase Console (`moneycontroljustaman045`), go to **Project settings > Users and permissions**.
> 2. Click **Add member** and invite Shay's Google account with the **Owner** role.
> 3. Shay accepts the invitation via email.
> 4. Shay logs in and removes Aman's access.
> 5. You can rename the display name to "company" in settings. 
> 
> **This requires NO code changes, NO data migration, and has ZERO downtime or risk of users logging out.**
