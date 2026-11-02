import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:money_control/Screens/Admin/payment_settings_screen.dart';
import 'package:money_control/Services/payment_config_service.dart';
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The screen only reads the reactive fields and listens to them; nothing in
/// `build()` needs Firestore. Overriding `onInit` keeps the auth-gated
/// `app_config/payment_settings` listener out of a widget test.
class _FakePaymentConfig extends PaymentConfigService {
  @override
  // ignore: must_call_super
  void onInit() {
    // Deliberately no super.onInit(): no Firestore listener.
  }
}

Widget _app(Widget child) => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, __) => GetMaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

Future<void> _pumpScreen(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(child));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() {
    Get.reset();
    SharedPreferences.setMockInitialValues({});
    // GlassContainer reads PerformanceController inside its own Obx; mirror the
    // app's Phase-1 registration so it resolves.
    Get.put<PerformanceController>(PerformanceController());
    Get.put<PaymentConfigService>(_FakePaymentConfig());
  });

  // Regression: the body used to be wrapped in
  // `Obx(() => ValueListenableBuilder(...))`. Obx requires its own builder to
  // read an Rx synchronously; the reads happened inside the nested builder, so
  // GetX threw "improper use of a GetX" during build and the screen painted a
  // blank body — the white box admins reported.
  testWidgets('renders the payment form instead of a blank body', (tester) async {
    await _pumpScreen(tester, const PaymentSettingsScreen());

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.paymentSettings), findsOneWidget);
    expect(find.text(l10n.paymentMode), findsOneWidget);
    expect(find.text('Google Play Billing'), findsOneWidget);
    expect(find.text('Manual UPI'), findsOneWidget);
    expect(find.text(l10n.upiID), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(l10n.saveSettings), findsOneWidget);
  });

  testWidgets('typing a UPI id enables Save', (tester) async {
    Get.find<PaymentConfigService>().paymentMode.value = 'upi';
    Get.find<PaymentConfigService>().upiId.value = '';
    await _pumpScreen(tester, const PaymentSettingsScreen());

    final save = find.widgetWithText(ElevatedButton, l10n.saveSettings);
    expect(tester.widget<ElevatedButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'shop@upi');
    await tester.pump();
    expect(tester.widget<ElevatedButton>(save).onPressed, isNotNull);
  });
}
