import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Components/kept_page_transition.dart';

/// The shell used to skip the enter animation for a tab's *first* visit: the
/// page was materialized already active, so its `AnimatedSlide` was born at
/// `offset: Offset.zero` and had nothing to animate away from. Only returning
/// to an existing page slid.
void main() {
  Widget host({
    required bool active,
    required int index,
    required int activeIndex,
    Duration duration = const Duration(milliseconds: 320),
    double initialDirection = 1,
  }) {
    return MaterialApp(
      home: KeptPageTransition(
        active: active,
        index: index,
        activeIndex: activeIndex,
        duration: duration,
        initialDirection: initialDirection,
        child: const ColoredBox(
          key: ValueKey('page'),
          color: Colors.blue,
          child: SizedBox.expand(),
        ),
      ),
    );
  }

  Offset offsetOf(WidgetTester tester) {
    // MaterialApp/Scaffold bring their own SlideTransitions; take the nearest
    // ancestor of the page we passed in.
    final transition = tester.widget<SlideTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('page')),
            matching: find.byType(SlideTransition),
          )
          .first,
    );
    return transition.position.value;
  }

  testWidgets('a page born active starts off-screen and slides in',
      (tester) async {
    await tester.pumpWidget(host(active: true, index: 1, activeIndex: 1));
    // The post-frame callback has not advanced the controller past 0 yet.
    expect(offsetOf(tester), isNot(Offset.zero));

    await tester.pumpAndSettle();
    expect(offsetOf(tester), Offset.zero);
  });

  testWidgets('a page activated later slides in too', (tester) async {
    await tester.pumpWidget(host(active: false, index: 1, activeIndex: 0));
    expect(offsetOf(tester), Offset.zero, reason: 'hidden pages sit at rest');

    await tester.pumpWidget(host(active: true, index: 1, activeIndex: 1));
    await tester.pump();
    expect(offsetOf(tester), isNot(Offset.zero));

    await tester.pumpAndSettle();
    expect(offsetOf(tester), Offset.zero);
  });

  testWidgets('the direction follows the tab we came from', (tester) async {
    // Coming from a higher index means entering from the left.
    await tester.pumpWidget(host(
      active: false,
      index: 0,
      activeIndex: 1,
      initialDirection: -1,
    ));
    await tester.pumpWidget(host(
      active: true,
      index: 0,
      activeIndex: 0,
      initialDirection: -1,
    ));
    await tester.pump();
    expect(offsetOf(tester).dx, lessThan(0));

    await tester.pumpAndSettle();
    expect(offsetOf(tester), Offset.zero);
  });

  testWidgets('lite mode never animates', (tester) async {
    await tester.pumpWidget(host(
      active: true,
      index: 1,
      activeIndex: 1,
      duration: Duration.zero,
    ));
    expect(offsetOf(tester), Offset.zero);
    await tester.pumpAndSettle();
    expect(offsetOf(tester), Offset.zero);
  });
}
