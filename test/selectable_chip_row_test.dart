import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Components/selectable_chip_row.dart';

/// The recurring-payment sheet used raw dropdowns for frequency and category.
/// Frequency has three values, and a closed dropdown hides both the options and
/// the current choice. The shared chip row replaces them; these tests pin the
/// behaviour the sheet depends on.
void main() {
  Widget host({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          body: SelectableChipRow<String>(
            options: options,
            selected: selected,
            labelOf: (v) => v,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('renders one chip per option', (tester) async {
    await tester.pumpWidget(host(
      options: const ['Monthly', 'Weekly', 'Yearly'],
      selected: 'Monthly',
      onSelected: (_) {},
    ));
    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text('Weekly'), findsOneWidget);
    expect(find.text('Yearly'), findsOneWidget);
  });

  testWidgets('a tap reports the chosen option', (tester) async {
    String? chosen;
    await tester.pumpWidget(host(
      options: const ['Monthly', 'Weekly', 'Yearly'],
      selected: 'Monthly',
      onSelected: (v) => chosen = v,
    ));
    await tester.tap(find.text('Yearly'));
    expect(chosen, 'Yearly');
  });

  testWidgets('search appears only for long lists', (tester) async {
    await tester.pumpWidget(host(
      options: const ['Monthly', 'Weekly', 'Yearly'],
      selected: 'Monthly',
      onSelected: (_) {},
    ));
    expect(find.byType(TextField), findsNothing);

    await tester.pumpWidget(host(
      options: List.generate(12, (i) => 'Category $i'),
      selected: 'Category 0',
      onSelected: (_) {},
    ));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('search filters the visible chips', (tester) async {
    await tester.pumpWidget(host(
      options: List.generate(12, (i) => 'Category $i'),
      selected: 'Category 0',
      onSelected: (_) {},
    ));
    await tester.enterText(find.byType(TextField), 'Category 7');
    await tester.pump();
    // The search field itself also renders the query, so assert on the chips
    // that should have disappeared instead of an exact match count.
    expect(find.text('Category 1'), findsNothing);
    expect(find.text('Category 2'), findsNothing);
    expect(find.text('Category 7'), findsWidgets);
  });
}
