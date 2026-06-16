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
import 'package:money_control/Platform/notification_platform.dart';
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
import 'package:money_control/Controllers/auth_controller.dart';
import 'package:money_control/Controllers/goals_controller.dart';
import 'package:money_control/Controllers/loan_controller.dart';
import 'package:money_control/Controllers/challenges_controller.dart';
import 'package:money_control/Controllers/analytics_controller.dart';
import 'package:money_control/Controllers/budget_controller.dart';
import 'package:money_control/Controllers/lent_money_controller.dart';
import 'package:money_control/Controllers/recurring_payment_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Controllers/profile_controller.dart';
import 'package:money_control/Services/widget_service.dart';
import 'package:money_control/Services/iap_service.dart';
import 'package:money_control/Services/payment_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/Platform/widget_platform.dart';
import 'package:money_control/Screens/add_transaction.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/sms_service.dart';

// ---- THEME CONTROLLER ----
class ThemeController extends GetxController {
  // Default to system theme until loaded
  Rx<ThemeMode> currentTheme = ThemeMode.system.obs;

  ThemeMode get themeMode => currentTheme.value;
  StreamSubscription<DocumentSnapshot>? _themeSubscription;


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

  void resubscribe() {
    _themeSubscription?.cancel();
    _themeSubscription = null;
    _listenToThemeChanges();
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

// Accessed via Get.find<ThemeController>() after mainCommon() registers it.
late final ThemeController themeController;
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// ---- MAIN ----
void main() {
  mainCommon();
}

Future<void> mainCommon({bool isTest = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCacheService.init();
  // Must be registered after ensureInitialized so GetX platform channels work.
  themeController = Get.put(ThemeController());
  TutorialController.isTestMode = isTest;
  Get.testMode = isTest;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  themeController.resubscribe();

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
  Get.put(AuthController());
  Get.put(SubscriptionController());
  Get.put(PaymentConfigService());
  await WidgetService.init();
  await Get.put(IapService()).init();
  final bioService = Get.put(BiometricService());

  await BackgroundWorker.init();

  if (!isTest && !kIsWeb) {
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  FirebaseFirestore.instance.enableNetwork().then((_) {
    syncPendingTransactions();
  }).catchError((e) {
    debugPrint('enableNetwork error: $e');
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
  late final BiometricService _bioService;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    _bioService = Get.find<BiometricService>();
    WidgetsBinding.instance.addObserver(this);
    _initWidgetClickHandling();
  }

  void _initWidgetClickHandling() {
    if (kIsWeb) return;
    // Cold start: app opened via widget tap
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri?.host == 'add_transaction') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Get.to(() => const PaymentScreen(type: PaymentType.send));
        });
      }
    }).catchError((e) {
      debugPrint('HomeWidget error: $e');
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
          title: "WealthSync",
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
      unawaited(UpdateChecker.checkForUpdate());
    }
    _handleAuthChange(FirebaseAuth.instance.currentUser);
    _authSub = FirebaseAuth.instance.authStateChanges().skip(1).listen(_handleAuthChange);
  }

  void _handleAuthChange(User? user) {
    final isOAuthUser = user?.providerData.any(
          (p) => p.providerId == 'google.com' || p.providerId == 'apple.com',
        ) ??
        false;
    if (user != null && (user.emailVerified || isOAuthUser)) {
      Get.find<ThemeController>().resubscribe();
      if (!Get.isRegistered<TransactionController>()) {
        Get.put(TransactionController());
      }
      if (!Get.isRegistered<ProfileController>()) {
        Get.put(ProfileController());
      }
      if (!Get.isRegistered<AnalyticsController>()) {
        Get.put(AnalyticsController());
      }
      if (!Get.isRegistered<BudgetController>()) {
        Get.put(BudgetController());
      }
      if (!Get.isRegistered<GoalsController>()) {
        Get.put(GoalsController());
      }
      if (!Get.isRegistered<LoanController>()) {
        Get.put(LoanController());
      }
      if (!Get.isRegistered<ChallengesController>()) {
        Get.put(ChallengesController());
      }
      if (!Get.isRegistered<LentMoneyController>()) {
        Get.put(LentMoneyController());
      }
      if (!Get.isRegistered<RecurringPaymentController>()) {
        Get.put(RecurringPaymentController());
      }
      final email = user.email;
      if (!_didInitialBackup && email != null) {
        _didInitialBackup = true;
        unawaited(LocalBackupService.backupUserTransactions(email));
      }
    } else {
      if (Get.isRegistered<TransactionController>()) {
        Get.delete<TransactionController>(force: true);
      }
      if (Get.isRegistered<ProfileController>()) {
        Get.delete<ProfileController>(force: true);
      }
      if (Get.isRegistered<AnalyticsController>()) {
        Get.delete<AnalyticsController>(force: true);
      }
      if (Get.isRegistered<BudgetController>()) {
        Get.delete<BudgetController>(force: true);
      }
      if (Get.isRegistered<GoalsController>()) {
        Get.delete<GoalsController>(force: true);
      }
      if (Get.isRegistered<LoanController>()) {
        Get.delete<LoanController>(force: true);
      }
      if (Get.isRegistered<ChallengesController>()) {
        Get.delete<ChallengesController>(force: true);
      }
      if (Get.isRegistered<LentMoneyController>()) {
        Get.delete<LentMoneyController>(force: true);
      }
      if (Get.isRegistered<RecurringPaymentController>()) {
        Get.delete<RecurringPaymentController>(force: true);
      }
      SmsService.resetCache();
      LocalCacheService.clearAll();
      _didInitialBackup = false;
      if (user != null && !user.emailVerified && !isOAuthUser) {
        FirebaseAuth.instance.signOut();
      }
    }
  }

  Future<bool> _checkOnboardingStatus(String email) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();
      if (doc.exists && doc.data()?['is_onboarded'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_onboarded', true);
        return true;
      }
    } catch (e) {
      debugPrint("Onboarding check failed: $e");
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_onboarded') ?? false;
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
        final isOAuth = user?.providerData.any(
              (p) => p.providerId == 'google.com' || p.providerId == 'apple.com',
            ) ??
            false;

        final onboardingEmail = user?.email;
        if (user != null && onboardingEmail != null && (user.emailVerified || isOAuth)) {
          return FutureBuilder<bool>(
            future: _checkOnboardingStatus(onboardingEmail),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final isOnboarded = snapshot.data ?? false;

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
