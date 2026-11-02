import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/bills_sheet.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Utils/bills_math.dart';
import 'package:money_control/Utils/wealth_math.dart';
import 'package:money_control/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

MonthlyBill _bill({
  String category = 'Rent',
  double auto = 15000,
  double override = 0,
  double recurring = 0,
  double spent = 0,
  DailyLimitRole role = DailyLimitRole.fixed,
  DateTime? due,
  bool liability = false,
}) => MonthlyBill(
  category: category,
  autoAmount: auto,
  overrideAmount: override,
  recurringDue: recurring,
  spentThisMonth: spent,
  role: role,
  dueDate: due,
  isLiability: liability,
);

Widget _host() => ScreenUtilInit(
  designSize: const Size(390, 844),
  builder: (_, __) => GetMaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => showBillsSheet(
              context,
              bills: MonthlyBills(
                categories: [
                  _bill(),
                  _bill(
                    category: 'Credit Card',
                    auto: 0,
                    recurring: 4000,
                    role: DailyLimitRole.variable,
                    due: DateTime(2026, 11, 20),
                    liability: true,
                  ),
                ],
                outstanding: 42000,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host());
  await tester.pumpAndSettle();
  await tester.tap(find.text('open'));
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
    Get.put<CurrencyController>(CurrencyController());
  });

  testWidgets('lists the month bills with totals and outstanding debt', (
    tester,
  ) async {
    await _pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.billsTitle), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Credit Card'), findsOneWidget);
    // Liability rows carry the badge and the outstanding total is in the header.
    expect(find.text(l10n.billsLiability), findsOneWidget);
    expect(
      find.text(
        l10n.billsOutstanding('${CurrencyController.to.currencySymbol.value}42000'),
      ),
      findsOneWidget,
    );
    expect(find.text(l10n.billsManual), findsNothing);
    // A recurring due date is shown instead of the auto average line.
    expect(
      find.text(l10n.billsDueOn('Nov 20')),
      findsOneWidget,
    );
  });

  testWidgets('tapping a row opens the amount editor with Auto available', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Rent'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.billsMonthlyAmount), findsOneWidget);
    expect(find.text(l10n.billsUseAuto), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text(l10n.billsUseAuto));
    await tester.pumpAndSettle();
    // Dialog closed, sheet still there, controller untouched (none registered).
    expect(find.text(l10n.billsMonthlyAmount), findsNothing);
    expect(find.text(l10n.billsTitle), findsOneWidget);
  });
}
