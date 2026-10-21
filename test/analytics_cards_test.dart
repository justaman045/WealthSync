import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/analytics/analytics_cards.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/l10n/app_localizations.dart';

/// The analytics cards used to be private methods on the screen, which meant
/// the only way to check them was to mount a screen bound to Firebase. They
/// are widgets now, so they can be checked on their own.
///
/// These tests pin the two things a refactor like this can silently break:
/// the copy that reaches the screen, and the button role of a tappable card
/// (a card that lost its `onTap` used to announce itself as a button that
/// did nothing).
void main() {
  setUp(() {
    Get.testMode = true;
    if (!Get.isRegistered<CurrencyController>()) {
      Get.put(CurrencyController());
    }
  });

  tearDown(() {
    Get.reset();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AnalyticsStatCard', () {
    testWidgets('shows the label and the amount with the currency symbol', (
      tester,
    ) async {
      await pump(
        tester,
        const AnalyticsStatCard(
          label: 'Income',
          amount: 1234,
          color: Colors.indigo,
          icon: Icons.arrow_upward,
          isDark: false,
        ),
      );

      expect(find.text('Income'), findsOneWidget);
      expect(find.text('₹1234'), findsOneWidget);
    });

    testWidgets('a tappable card is announced as a button', (tester) async {
      await pump(
        tester,
        AnalyticsStatCard(
          label: 'Income',
          amount: 10,
          color: Colors.indigo,
          icon: Icons.arrow_upward,
          isDark: false,
          onTap: () {},
        ),
      );

      final handle = tester.getSemantics(find.text('Income'));
      expect(handle, matchesSemantics(isButton: true, hasTapAction: true));
    });

    testWidgets('a card with nothing to tap is not announced as a button', (
      tester,
    ) async {
      await pump(
        tester,
        const AnalyticsStatCard(
          label: 'Income',
          amount: 10,
          color: Colors.indigo,
          icon: Icons.arrow_upward,
          isDark: false,
        ),
      );

      final handle = tester.getSemantics(find.text('Income'));
      expect(handle, matchesSemantics(isButton: false, hasTapAction: false));
    });
  });

  group('AnalyticsQuickOverviewCard', () {
    testWidgets('shows all three periods and the in/out labels', (
      tester,
    ) async {
      await pump(
        tester,
        const AnalyticsQuickOverviewCard(
          isDark: false,
          todayIncome: 100,
          todayExpense: 40,
          weekIncome: 300,
          weekExpense: 120,
          monthIncome: 900,
          monthExpense: 450,
        ),
      );

      expect(find.text('Quick Overview'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsOneWidget);
      // One "In" and one "Out" per period row.
      expect(find.text('In'), findsNWidgets(3));
      expect(find.text('Out'), findsNWidgets(3));
      expect(find.text('₹900'), findsOneWidget);
      expect(find.text('₹450'), findsOneWidget);
    });
  });

  group('AnalyticsEmptyCard', () {
    testWidgets('shows its message', (tester) async {
      await pump(
        tester,
        const AnalyticsEmptyCard(
          text: 'Not enough data for trend.',
          isDark: false,
        ),
      );

      expect(find.text('Not enough data for trend.'), findsOneWidget);
    });
  });

  group('AnalyticsHeatmapLegendItem', () {
    testWidgets('shows its label', (tester) async {
      await pump(
        tester,
        const AnalyticsHeatmapLegendItem(
          color: Colors.green,
          label: 'Low spend',
          textColor: Colors.black,
        ),
      );

      expect(find.text('Low spend'), findsOneWidget);
    });
  });

  group('AnalyticsPersonalityCard', () {
    testWidgets('shows the personality and the saving rate', (tester) async {
      await pump(
        tester,
        const AnalyticsPersonalityCard(
          personality: SpendingPersonality(
            label: 'Smart Saver',
            emoji: '💰',
            description: 'You save over 40% of your income.',
            color: Colors.green,
          ),
          income: 1000,
          expense: 500,
          isDark: false,
        ),
      );

      expect(find.text('Smart Saver'), findsOneWidget);
      expect(find.text('You save over 40% of your income.'), findsOneWidget);
      expect(find.text('50.0%'), findsOneWidget);
      // A positive rate has nothing to warn about.
      expect(find.textContaining('Spending exceeds income'), findsNothing);
    });

    testWidgets('a deficit is called out with the overspend', (tester) async {
      await pump(
        tester,
        const AnalyticsPersonalityCard(
          personality: SpendingPersonality(
            label: 'Balanced Spender',
            emoji: '⚖️',
            description: 'Your spending is well-distributed.',
            color: Colors.teal,
          ),
          income: 1000,
          expense: 1500,
          isDark: false,
        ),
      );

      expect(find.text('-50.0%'), findsOneWidget);
      expect(
        find.text('Spending exceeds income by 50.0%'),
        findsOneWidget,
      );
    });

    testWidgets('no income means no rate and no warning', (tester) async {
      await pump(
        tester,
        const AnalyticsPersonalityCard(
          personality: SpendingPersonality(
            label: 'Just Getting Started',
            emoji: '🌱',
            description: 'Add more transactions to unlock your personality.',
            color: Colors.lightGreen,
          ),
          income: 0,
          expense: 0,
          isDark: false,
        ),
      );

      expect(find.text('Just Getting Started'), findsOneWidget);
      expect(find.textContaining('Spending exceeds income'), findsNothing);
      expect(find.text('Saving Rate'), findsNothing);
    });
  });
}
