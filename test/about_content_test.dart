import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Config/app_info.dart';
import 'package:money_control/Screens/terms_and_policy.dart';

/// The About screen is the app's own description of itself: a stale claim or a
/// dropped credit there is a store-listing problem, and every claim is a
/// promise. These checks keep the copy in one place and keep the legal tiles
/// pointing at the section the user actually tapped.
void main() {
  group('AppInfo', () {
    test('every feature has a title and an explanation', () {
      expect(AppInfo.features, isNotEmpty);
      for (final feature in AppInfo.features) {
        expect(feature.title.trim(), isNotEmpty);
        expect(feature.description.trim(), isNotEmpty);
        expect(
          feature.description.length,
          greaterThan(feature.title.length),
          reason: '"${feature.title}" needs a real description',
        );
      }
    });

    test('feature titles are unique', () {
      final titles = AppInfo.features.map((f) => f.title).toList();
      expect(titles.toSet().length, titles.length);
    });

    test('the app does not claim a feature it does not ship', () {
      final titles = AppInfo.features.map((f) => f.title).toList();
      // Spot-check the headline capabilities so removing one from the app also
      // forces this list to change.
      expect(titles, contains('Dashboard'));
      expect(titles, contains('Wealth portfolio'));
      expect(titles, contains('Offline first'));
      expect(titles, contains('SMS import (Pro)'));
    });

    test('dependency credits are present and unique', () {
      expect(AppInfo.acknowledgements, isNotEmpty);
      expect(AppInfo.acknowledgements.toSet().length,
          AppInfo.acknowledgements.length);
      expect(
        AppInfo.acknowledgements.join(' '),
        contains('Flutter'),
      );
      expect(
        AppInfo.acknowledgements.join(' '),
        contains('Firebase'),
      );
    });

    test('the privacy policy url is https', () {
      expect(AppInfo.privacyPolicyUrl, startsWith('https://'));
    });
  });

  group('Legal deep links', () {
    test('every anchor has a distinct section', () {
      expect(LegalSection.values, hasLength(3));
      expect(
        LegalSection.values.map((s) => s.name),
        containsAll(<String>['terms', 'privacy', 'data']),
      );
    });

    test('the settings screen deep-links each legal tile', () {
      final source =
          File('lib/Screens/Settings/data_support_settings.dart')
              .readAsStringSync();
      expect(source, contains('LegalSection.terms'));
      expect(source, contains('LegalSection.privacy'));
      // A bare `LegalTrustPage()` here means the tile dropped its anchor and
      // lands on the Terms again.
      expect(source, isNot(contains('const LegalTrustPage()')));
    });

    test('the About screen deep-links all three sections', () {
      final source =
          File('lib/Screens/about_application.dart').readAsStringSync();
      for (final section in LegalSection.values) {
        expect(
          source,
          contains('LegalSection.${section.name}'),
          reason: 'About screen has no tile for ${section.name}',
        );
      }
      // The copy belongs to AppInfo, not to the widget.
      expect(source, isNot(contains('"Empower your financial journey')));
    });
  });
}
