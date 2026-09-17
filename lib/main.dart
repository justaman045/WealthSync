// lib/main.dart

import 'package:flutter/material.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:get/get.dart';
import 'dart:math';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:money_control/Platform/notification_platform.dart';
import 'package:money_control/Components/methods.dart';
import 'package:money_control/Utils/web_reload_stub.dart'
    if (dart.library.html) 'package:money_control/Utils/web_reload_web.dart';

import 'package:money_control/firebase_options.dart';
import 'package:money_control/Screens/main_shell.dart';
import 'package:money_control/Screens/budget.dart';
import 'package:money_control/Screens/subscription_screen.dart';
import 'package:money_control/Screens/splashscreen.dart';
import 'package:money_control/Screens/onboarding_screen.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Services/background_worker.dart';
import 'package:money_control/Services/local_backup_service.dart';
import 'package:money_control/Services/update_checker.dart';
import 'package:money_control/Services/biometric_service.dart';
import 'package:money_control/Services/notification_service.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Services/connectivity_controller.dart';
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
import 'package:money_control/Services/feature_flag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_control/Platform/widget_platform.dart';
import 'package:money_control/Screens/add_transaction.dart';
import 'package:money_control/Services/cache_service.dart';
import 'package:money_control/Services/sms_service.dart';
import 'package:money_control/Services/recurring_service.dart';

// ---- THEME CONTROLLER ----
class ThemeController extends GetxController {
  // Dark-first default until a stored preference loads from Firestore.
  Rx<ThemeMode> currentTheme = ThemeMode.dark.obs;

  ThemeMode get themeMode => currentTheme.value;
  StreamSubscription<DocumentSnapshot>? _themeSubscription;
  StreamSubscription<User?>? _authSub;

  @override
  void onInit() {
    super.onInit();
    // Re-bind the theme stream to the currently signed-in user on every auth
    // change (sign-out + sign-in as a different account must not keep the old
    // account's theme stream alive).
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      _listenToThemeChanges();
    });
  }

  @override
  void onClose() {
    _themeSubscription?.cancel();
    _authSub?.cancel();
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
    _themeSubscription?.cancel();
    _themeSubscription = null;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      if (kIsWeb) {
        _fetchThemeOnce(user.email!);
      } else {
        _themeSubscription = FirebaseFirestore.instance
            .collection("users")
            .doc(user.email)
            .snapshots()
            .listen((snapshot) {
              _applyThemeSnapshot(snapshot);
            }, onError: (e) => debugPrint('ThemeController stream error: $e'));
      }
    }
  }

  void _applyThemeSnapshot(DocumentSnapshot snapshot) {
    if (snapshot.exists) {
      final data = snapshot.data();
      if (data != null &&
          data is Map<String, dynamic> &&
          data.containsKey("darkMode")) {
        final isDark = data["darkMode"] == true;
        final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
        if (currentTheme.value != newMode) {
          currentTheme.value = newMode;
          Get.changeThemeMode(newMode);
        }
      }
    }
  }

  Future<void> _fetchThemeOnce(String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(email)
          .get();
      _applyThemeSnapshot(snapshot);
    } catch (e) {
      debugPrint('ThemeController get error: $e');
    }
  }
}

// Accessed via Get.find<ThemeController>() after mainCommon() registers it.
late final ThemeController themeController;
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
bool _b815ReloadScheduled = false;

// ---- MAIN ----
void main() {
  mainCommon();
}

Future<void> mainCommon({bool isTest = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCacheService.init();
  // Firebase must be initialized BEFORE any controller touches
  // FirebaseAuth.instance — ThemeController.onInit subscribes to
  // authStateChanges() immediately (previously the app crashed on cold start
  // with `[core/no-app] No Firebase App '[DEFAULT]' has been created`).
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Must be registered after ensureInitialized so GetX platform channels work.
  themeController = Get.put(ThemeController());
  TutorialController.isTestMode = isTest;
  Get.testMode = isTest;
  themeController.resubscribe();

  if (!isTest) {
    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      final errorStr = error.toString();
      debugPrint("🔴 Async Error: $error");
      debugPrint(stack.toString());

      // Firebase JS SDK b815: AsyncQueue is in a failed state after ca9 assertion.
      // No recovery possible without page reload. Detect and auto-reload once.
      if (kIsWeb && errorStr.contains('b815') && !_b815ReloadScheduled) {
        _b815ReloadScheduled = true;
        debugPrint(
          '⚠️ Firestore SDK corrupted (b815). Reloading page in 2s...',
        );
        Future.delayed(const Duration(seconds: 2), () {
          reloadPage();
        });
      }

      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      } catch (e) {
        debugPrint("⚠️ Failed to report to Crashlytics: $e");
      }
      return true;
    };
  }

  // Firestore offline persistence (no-op on web, IndexedDB is always-on)
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  }

  // Initialize Controllers (synchronous registrations only — the first frame
  // depends on these being resolvable).
  Get.put(PrivacyController());
  Get.put(CurrencyController());
  Get.put(AuthController());
  Get.put(SubscriptionController());
  Get.put(PaymentConfigService());
  Get.put(FeatureFlagService());

  // Force privacy blur off the instant an admin hides the feature — "as if
  // never there". Reads local Rx state only (no Firestore), so it is safe on
  // every platform including the web b815 constraints; every masking widget
  // already listens to isPrivacyMode, so one flip un-blurs them reactively.
  ever(FeatureFlagService.to.statusMap, (_) {
    // Mirror the live status map into SharedPreferences so the background
    // isolate (WorkManager) can honor `hidden` kill-switches even when its own
    // auth/network read fails (the isolate is fail-closed on this mirror).
    unawaited(BackgroundWorker.mirrorFeatureFlags(FeatureFlagService.to.statusMap));
    if (FeatureFlagService.to.isHidden('privacy_mode')) {
      Get.find<PrivacyController>().isPrivacyMode.value = false;
    }
    // Mirror for biometric lock: hiding the flag must force-flip the lock
    // state off (isAuthenticated → true + pref down) so `lockActive` is false
    // everywhere the instant the admin hides it.
    if (Get.isRegistered<BiometricService>() &&
        FeatureFlagService.to.isHidden('biometric_app_lock')) {
      final bio = Get.find<BiometricService>();
      bio.isAuthenticated.value = true;
      bio.isBiometricEnabled.value = false;
      unawaited(
        SharedPreferences.getInstance().then((prefs) {
          if (prefs.getBool('biometric_enabled') ?? false) {
            return prefs.setBool('biometric_enabled', false);
          }
          return Future.value();
        }),
      );
    }
  });
  Get.put(PerformanceController());
  Get.put(ConnectivityController());
  Get.put(IapService());
  final bioService = Get.put(BiometricService());

  // Heavy async startup (IAP product query over the network, home-widget
  // registration, WorkManager, notification permission) is deferred until
  // after the first frame so the splash paints immediately on low-end devices
  // and slow networks. Order inside the callback mirrors the original.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _deferredStartup(isTest);
  });

  // Check biometrics on launch
  await bioService.checkBiometricOnLaunch();

  // Init Notifications with callback
  await NotificationService.init(
    onDidReceiveNotificationResponse: (response) {
      // Biometric lock: a locked app must never let a notification deep-link
      // push content over the lock screen.
      if (bioService.lockActive && !bioService.isAuthenticated.value) {
        return;
      }
      switch (response.payload) {
        case 'budget':
          // Route budget alerts to the budget screen (respect the kill-switch;
          // a hidden budget flag must not open the UI).
          if (FeatureFlagService.to.isHidden('budget')) {
            Get.to(() => const MainShell());
          } else {
            Get.to(() => const CategoryBudgetScreen());
          }
        case 'subscription':
          Get.to(() => const SubscriptionScreen());
        default:
          Get.to(() => const MainShell());
      }
    },
  );

  runApp(RootApp(isTest: isTest));
}

/// Runs after the first frame so expensive one-time platform init does not
/// delay the initial render.
Future<void> _deferredStartup(bool isTest) async {
  await WidgetService.init();
  await Get.find<IapService>().init();
  await BackgroundWorker.init();

  if (!isTest && !kIsWeb) {
    await FlutterLocalNotificationsPlugin()
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  // On web, enableNetwork() stays deferred to after login (see b815 note in
  // _handleAuthChange). Native platforms keep the existing behavior.
  if (!kIsWeb) {
    FirebaseFirestore.instance
        .enableNetwork()
        .then((_) {
          syncPendingTransactions();
        })
        .catchError((e) {
          debugPrint('enableNetwork error: $e');
        });
  }
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
    // Kill-switch: a `hidden` home_widget flag makes widget taps dead — the
    // feature reads as if it never existed (no cold/warm-start navigation).
    if (FeatureFlagService.to.isHidden('home_widget')) return;
    // Biometric lock: only route widget taps when the app is unlocked, so a
    // locked device cannot push a payment screen over the lock screen.
    bool unlocked() =>
        !_bioService.lockActive || _bioService.isAuthenticated.value;
    // Cold start: app opened via widget tap
    HomeWidget.initiallyLaunchedFromHomeWidget()
        .then((uri) {
          if (uri?.host == 'add_transaction' && unlocked()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Get.to(() => const PaymentScreen(type: PaymentType.send));
            });
          }
        })
        .catchError((e) {
          debugPrint('HomeWidget error: $e');
        });
    // Warm start: app already running when widget tapped
    _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri?.host == 'add_transaction' && unlocked()) {
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
      if (_bioService.lockActive) {
        _bioService.isAuthenticated.value = false;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Trigger auth on resume
      if (_bioService.lockActive &&
          !_bioService.isAuthenticated.value) {
        _bioService.authenticate();
      }
      // Check subscription on resume (skip on web — Firestore 12.7.0 SDK bug
      // corrupts internal state when listeners re-open into a broken session)
      if (!kIsWeb) SubscriptionController.to.checkSubscriptionStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) {
        return GetMaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: "WealthSync",
          defaultTransition: Transition.fadeIn,
          transitionDuration: const Duration(milliseconds: 300),
          themeMode: themeController.themeMode,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (appContext, child) {
            final width = MediaQuery.of(appContext).size.width;
            if (width > 600) {
              final designWidth = max(390.0, width / 1.3);
              ScreenUtil.init(appContext, designSize: Size(designWidth, 844));
            }
            return child ?? const SizedBox.shrink();
          },
          home: Obx(() {
            if (_bioService.lockActive &&
                !_bioService.isAuthenticated.value) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 64.sp,
                          color: Colors.grey),
                      SizedBox(height: 16.h),
                      Text(
                        "App Locked",
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        "Authenticate to continue",
                        style: TextStyle(fontSize: 14.sp,
                            color: Colors.grey),
                      ),
                      SizedBox(height: 24.h),
                      FilledButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await _bioService.authenticate();
                          if (!ok) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "Authentication failed. Try again."),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.fingerprint),
                        label: const Text("Unlock"),
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

  /// UID of the session already handled by [_handleAuthChange]. Used to dedupe
  /// the synchronous current-user call from the stream's first emission
  /// (replaces the old `.skip(1)`).
  ///
  /// `.skip(1)` was racy on native: when a persisted session restores AFTER
  /// initState reads `currentUser == null`, the restored user becomes the first
  /// stream emission and gets dropped — Phase-2 controllers then never
  /// register, while home still renders via the StreamBuilder below (a silent
  /// failure). Dedupe-by-uid keeps the web flow's single-run guarantee without
  /// dropping a legitimate first emission.
  String? _handledUid;

  @override
  void initState() {
    super.initState();
    if (!widget.isTest) {
      unawaited(UpdateChecker.checkForUpdate());
    }
    _handleAuthChange(FirebaseAuth.instance.currentUser);
    _authSub = FirebaseAuth.instance
        .authStateChanges()
        .listen(_handleAuthChange);
  }

  void _handleAuthChange(User? user) async {
    // Skip re-processing the same session (initState call vs first stream
    // emission), but never drop a null→user transition — a null first
    // emission is also a no-op, so deduping it is harmless.
    final uid = user?.uid;
    if (uid == _handledUid) return;
    _handledUid = uid;
    // Anchor to the user this invocation was triggered for. The web branch
    // awaits several 500 ms delays; if the user signs out or switches accounts
    // mid-flight, a stale invocation must not register controllers afterwards.
    final anchorUid = user?.uid;
    bool authStale() {
      final current = FirebaseAuth.instance.currentUser;
      return current?.uid != anchorUid;
    }

    try {
      final isOAuthUser =
          user?.providerData.any(
            (p) => p.providerId == 'google.com' || p.providerId == 'apple.com',
          ) ??
          false;
      if (user != null && (user.emailVerified || isOAuthUser)) {
        // On web, initialize Firestore network here (after auth, before Phase 2)
        // so the first JS SDK operation is a persistent .snapshots() listener
        // from TransactionController, not a transient .get() — this avoids the
        // WatchChangeAggregator ca9/b815 assertion bug in Firebase JS SDK.
        if (kIsWeb) {
          try {
            await FirebaseFirestore.instance.enableNetwork();
          } catch (e) {
            debugPrint('enableNetwork error: $e');
          }
          if (authStale()) return;
        }
        if (!Get.isRegistered<TransactionController>()) {
          Get.put(TransactionController(), permanent: true);
        }
        // On web, resubscribe theme AFTER TransactionController so that
        // _fetchThemeOnce()'s transient .get() runs AFTER persistent .snapshots()
        // listeners are established — avoids the ca9/b815 watch aggregator bug.
        if (!kIsWeb) {
          Get.find<ThemeController>().resubscribe();
        } else {
          if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
          if (authStale()) return;
          Get.find<ThemeController>().resubscribe();
          syncPendingTransactions();
        }
        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
        if (authStale()) return;
        if (!Get.isRegistered<ProfileController>()) {
          Get.put(ProfileController(), permanent: true);
        }
        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
        if (authStale()) return;
        if (!Get.isRegistered<AnalyticsController>()) {
          Get.put(AnalyticsController(), permanent: true);
        }
        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
        if (authStale()) return;
        if (!Get.isRegistered<BudgetController>()) {
          Get.put(BudgetController(), permanent: true);
        }
        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
        if (authStale()) return;
        if (!Get.isRegistered<GoalsController>()) {
          Get.put(GoalsController(), permanent: true);
        }
        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
        if (authStale()) return;
        if (!Get.isRegistered<LoanController>()) {
          Get.put(LoanController(), permanent: true);
        }
        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
        if (authStale()) return;
        if (!Get.isRegistered<ChallengesController>()) {
          Get.put(ChallengesController(), permanent: true);
        }
        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
        if (authStale()) return;
        if (!Get.isRegistered<LentMoneyController>()) {
          Get.put(LentMoneyController(), permanent: true);
        }
        if (kIsWeb) await Future.delayed(const Duration(milliseconds: 500));
        if (authStale()) return;
        if (!Get.isRegistered<RecurringPaymentController>()) {
          Get.put(RecurringPaymentController(), permanent: true);
        }
        // Start PaymentConfigService polling AFTER all persistent .snapshots()
        // listeners are established. A transient .get() before persistent targets
        // can trigger the Firestore JS SDK WatchChangeAggregator ca9/b815 bug.
        if (kIsWeb && Get.isRegistered<PaymentConfigService>()) {
          PaymentConfigService.to.startPolling();
        }
        if (kIsWeb && Get.isRegistered<FeatureFlagService>()) {
          FeatureFlagService.to.startPolling();
        }
        final email = user.email;
        if (!_didInitialBackup && email != null) {
          _didInitialBackup = true;
          unawaited(LocalBackupService.backupUserTransactions(email));
        }
      } else {
        // Bail if a new user signed in while a stale logout/verification
        // invocation was in flight — never tear down the fresh session.
        if (authStale()) return;
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
        RecurringService.resetCache();
        // Reset biometric lock state on logout so the next sign-in on a shared
        // device starts unlocked and can set its own preference — a stale
        // device-wide pref must not lock the new session.
        if (Get.isRegistered<BiometricService>()) {
          final bio = Get.find<BiometricService>();
          bio.isAuthenticated.value = true;
          bio.isBiometricEnabled.value = false;
          unawaited(
            SharedPreferences.getInstance().then(
              (prefs) => prefs.setBool('biometric_enabled', false),
            ),
          );
        }
        LocalCacheService.clearAll();
        _didInitialBackup = false;
        if (user != null && !user.emailVerified && !isOAuthUser) {
          FirebaseAuth.instance.signOut();
        }
      }
    } catch (e) {
      debugPrint('Auth change handler error: $e');
    }
  }

  Future<bool> _checkOnboardingStatus(String email) async {
    final prefs = await SharedPreferences.getInstance();
    // On web, skip the Firestore .get() to avoid triggering the JS SDK
    // WatchChangeAggregator ca9/b815 assertion bug. Use SharedPreferences only.
    if (kIsWeb) {
      return prefs.getBool('is_onboarded') ?? false;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(email)
          .get();
      if (doc.exists && doc.data()?['is_onboarded'] == true) {
        await prefs.setBool('is_onboarded', true);
        return true;
      }
    } catch (e) {
      debugPrint("Onboarding check failed: $e");
    }
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
        final isOAuth =
            user?.providerData.any(
              (p) =>
                  p.providerId == 'google.com' || p.providerId == 'apple.com',
            ) ??
            false;

        final onboardingEmail = user?.email;
        if (user != null &&
            onboardingEmail != null &&
            (user.emailVerified || isOAuth)) {
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
                return const MainShell();
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
