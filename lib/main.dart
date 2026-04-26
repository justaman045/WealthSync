// lib/main.dart

import 'package:flutter/material.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:money_control/Components/methods.dart';

import 'package:money_control/firebase_options.dart';
import 'package:money_control/Screens/homescreen.dart';
import 'package:money_control/Screens/splashscreen.dart';
import 'package:money_control/Screens/onboarding_screen.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/background_worker.dart';
import 'package:money_control/Services/local_backup_service.dart';
import 'package:money_control/Services/update_checker.dart';
import 'package:money_control/Services/biometric_service.dart';
import 'package:money_control/Services/notification_service.dart';
import 'package:money_control/Controllers/privacy_controller.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/tutorial_controller.dart';
import 'package:money_control/Controllers/subscription_controller.dart';
import 'package:money_control/Controllers/goals_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Services/widget_service.dart';
import 'package:money_control/Services/iap_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'package:money_control/Screens/add_transaction.dart';

// ---- THEME CONTROLLER ----
class ThemeController extends GetxController {
  // Default to system theme until loaded
  Rx<ThemeMode> currentTheme = ThemeMode.system.obs;

  ThemeMode get themeMode => currentTheme.value;
  StreamSubscription<DocumentSnapshot>? _themeSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenToThemeChanges();
  }

  @override
  void onClose() {
    _themeSubscription?.cancel();
    super.onClose();
  }

  void setTheme(bool dark) {
    final mode = dark ? ThemeMode.dark : ThemeMode.light;
    if (currentTheme.value != mode) {
      currentTheme.value = mode;
      Get.changeThemeMode(mode);
      _saveThemeToFirestore(dark);
    }
  }

  // Called locally when setting updates, but avoid loop if update comes from stream
  Future<void> _saveThemeToFirestore(bool isDark) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      await FirebaseFirestore.instance.collection("users").doc(user.email).set({
        "darkMode": isDark,
      }, SetOptions(merge: true));
    }
  }

  void _listenToThemeChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      _themeSubscription = FirebaseFirestore.instance
          .collection("users")
          .doc(user.email)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.exists) {
              final data = snapshot.data();
              if (data != null && data.containsKey("darkMode")) {
                final isDark = data["darkMode"] as bool;
                final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
                if (currentTheme.value != newMode) {
                  currentTheme.value = newMode;
                  Get.changeThemeMode(newMode);
                }
              }
            }
          });
    }
  }
}

final ThemeController themeController = Get.put(ThemeController());
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// ---- MAIN ----
// ---- MAIN ----
void main() {
  mainCommon();
}

Future<void> mainCommon({bool isTest = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  TutorialController.isTestMode = isTest;
  Get.testMode = isTest;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!isTest) {
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      // Print error locally so we can see it even if Crashlytics fails
      debugPrint("🔴 Async Error: $error");
      debugPrint(stack.toString());

      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (e) {
        debugPrint("⚠️ Failed to report to Crashlytics: $e");
      }
      return true;
    };
  }

  // Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

  // Initialize Controllers
  Get.put(PrivacyController());
  Get.put(CurrencyController());
  Get.put(SubscriptionController());
  Get.put(GoalsController());
  await WidgetService.init();
  await IapService().init();
  final bioService = Get.put(BiometricService());

  // await _loadThemeFromFirebase(); // Handled by ThemeController listener
  await BackgroundWorker.init();

  if (!isTest) {
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  FirebaseFirestore.instance.enableNetwork().then((_) {
    syncPendingTransactions();
  });

  // Check biometrics on launch
  await bioService.checkBiometricOnLaunch();

  // Init Notifications with callback
  await NotificationService.init(
    onDidReceiveNotificationResponse: (response) {
      if (response.payload == "home") {
        Get.to(() => const BankingHomeScreen());
      }
    },
  );

  runApp(RootApp(isTest: isTest));
}

// Load theme BEFORE app builds

// ---- ROOT APP ----
class RootApp extends StatefulWidget {
  final bool isTest;
  const RootApp({super.key, this.isTest = false});

  @override
  State<RootApp> createState() => _RootAppState();
}

class _RootAppState extends State<RootApp> with WidgetsBindingObserver {
  final BiometricService _bioService = Get.find();
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initWidgetClickHandling();
  }

  void _initWidgetClickHandling() {
    // Cold start: app opened via widget tap
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri?.host == 'add_transaction') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.to(() => const PaymentScreen(type: PaymentType.send));
        });
      }
    });
    // Warm start: app already running when widget tapped
    _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri?.host == 'add_transaction') {
        Get.to(() => const PaymentScreen(type: PaymentType.send));
      }
    });
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Lock app when backgrounded
      if (_bioService.isBiometricEnabled.value) {
        _bioService.isAuthenticated.value = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Trigger auth on resume
      if (_bioService.isBiometricEnabled.value &&
          !_bioService.isAuthenticated.value) {
        _bioService.authenticate();
      }
      // Check subscription on resume
      SubscriptionController.to.checkSubscriptionStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) {
        return GetMaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          // navigatorKey is properly handled by GetX internally
          debugShowCheckedModeBanner: false,
          title: "Money Control",
          defaultTransition: Transition.fadeIn,
          transitionDuration: const Duration(milliseconds: 300),
          themeMode: themeController.themeMode,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Obx(() {
            if (_bioService.isBiometricEnabled.value &&
                !_bioService.isAuthenticated.value) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "App Locked",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return AuthChecker(isTest: widget.isTest);
          }),
        );
      },
    );
  }
}

// ---- AUTH CHECK ----
class AuthChecker extends StatefulWidget {
  final bool isTest;
  const AuthChecker({super.key, this.isTest = false});

  @override
  State<AuthChecker> createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  bool _didInitialBackup = false;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    if (!widget.isTest) {
      UpdateChecker.checkForUpdate(context);
    }
    _handleAuthChange(FirebaseAuth.instance.currentUser);
    _authSub = FirebaseAuth.instance.authStateChanges().skip(1).listen(_handleAuthChange);
  }

  void _handleAuthChange(User? user) {
    if (user != null && user.emailVerified) {
      if (!Get.isRegistered<TransactionController>()) {
        Get.put(TransactionController());
      }
      if (!Get.isRegistered<ProfileController>()) {
        Get.put(ProfileController());
      }
      if (!_didInitialBackup && user.email != null) {
        _didInitialBackup = true;
        LocalBackupService.backupUserTransactions(user.email!);
      }
    } else {
      if (Get.isRegistered<TransactionController>()) {
        Get.delete<TransactionController>(force: true);
      }
      if (Get.isRegistered<ProfileController>()) {
        Get.delete<ProfileController>(force: true);
      }
      _didInitialBackup = false;
      if (user != null && !user.emailVerified) {
        FirebaseAuth.instance.signOut();
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (user != null && user.emailVerified) {
          return FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, prefsSnapshot) {
              if (prefsSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final isOnboarded =
                  prefsSnapshot.data?.getBool('is_onboarded') ?? false;

              if (isOnboarded) {
                return const BankingHomeScreen();
              } else {
                return const OnboardingScreen();
              }
            },
          );
        }

        return const AnimatedSplashScreen();
      },
    );
  }
}
