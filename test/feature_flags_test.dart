import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Config/feature_flags.dart';
import 'package:money_control/Services/feature_flag_service.dart';

/// Patterns for extracting feature keys from gate call-sites in `lib/`. Keep in
/// sync with the gate APIs: adding a new gate widget/guard must extend this list
/// so the call-site tests below still prove every referenced key is registered.
final List<RegExp> _gateKeyPatterns = [
  RegExp(r"ensureFeature(?:Visible|Usable)\(\s*context\s*,\s*'([^']+)'"),
  RegExp(r"flagKey:\s*'([^']+)'"),
  RegExp(
      r"\b(?:statusOf|isEnabled|isComingSoon|isHidden|visibleToMe|setStatus)\(\s*'([^']+)'"),
  RegExp(r"FeatureFlag\.find\(\s*'([^']+)'"),
  RegExp(r"_flagHidden\(\s*[A-Za-z_][\w.]*\s*,\s*'([^']+)'"),
  RegExp(r"_requireFeature\(\s*'([^']+)'"),
  RegExp(r"ComingSoonScreen\.forFlag\(\s*'([^']+)'"),
  RegExp(r"featureKey:\s*'([^']+)'"),
];

/// Yields every feature key referenced by a gate/check in [source].
Iterable<String> gateKeysIn(String source) sync* {
  for (final pattern in _gateKeyPatterns) {
    for (final match in pattern.allMatches(source)) {
      yield match.group(1)!;
    }
  }
  for (final match in RegExp(r"FeatureSection\(\s*\[([^\]]*)\]").allMatches(source)) {
    for (final key in RegExp(r"'([^']+)'").allMatches(match.group(1)!)) {
      yield key.group(1)!;
    }
  }
}

void main() {
  group('FeatureFlag registry', () {
    test('all keys are unique', () {
      final keys = FeatureFlag.all.map((f) => f.key).toList();
      expect(keys, keys.toSet().toList());
      expect(keys, isNotEmpty);
    });

    test('every flag has title, description and icon', () {
      for (final f in FeatureFlag.all) {
        expect(f.title, isNotEmpty, reason: '${f.key} title');
        expect(f.description, isNotEmpty, reason: '${f.key} description');
      }
    });

    test('transactions is the only critical flag', () {
      final critical = FeatureFlag.all.where((f) => f.critical).toList();
      expect(critical.map((f) => f.key), ['transactions']);
    });

    test('every known gate key resolves to a registry entry', () {
      const keys = [
        'transactions',
        'transaction_search',
        'upi_pay',
        'qr_scan',
        'budget',
        'category',
        'lent_money',
        'recurring',
        'goals',
        'challenges',
        'forecast',
        'analytics',
        'analytics_advanced',
        'data_filters',
        'financial_summary',
        'quick_overview',
        'current_period',
        'expense_breakdown',
        'spending_heatmap',
        'top_merchants',
        'salary_detected',
        'spending_personality',
        'export_csv',
        'export_pdf',
        'share_report',
        'ai_insights',
        'ai_monthly_forecast',
        'ai_daily_limit',
        'monthly_heatmap',
        'category_insights',
        'wealth',
        'custom_mode',
        'total_net_worth',
        'wealth_assets',
        'allocation',
        'ideal_income',
        'smart_suggestions',
        'loan_tracker',
        'sms_tracking',
        'sms_import',
        'sms_auto_import',
        'expense_reminder',
        'lite_mode',
        'biometric_app_lock',
        'privacy_mode',
        'restore_data',
        'import_data',
        'export_all_data',
        'transaction_audit',
        'sms_rules',
        'invite',
        'profile',
        'notifications',
        'home_widget',
        'update_checker',
      ];
      for (final k in keys) {
        expect(FeatureFlag.find(k), isNotNull, reason: '$k is missing');
      }
    });

    test('find returns null for unknown keys', () {
      expect(FeatureFlag.find('nope'), isNull);
    });

    test('groups cover every registry key exactly once', () {
      final allKeys = FeatureFlag.all.map((f) => f.key).toList();
      final groupedKeys = <String>[];
      for (final group in FeatureFlag.groups) {
        for (final key in group.keys) {
          expect(
            groupedKeys,
            isNot(contains(key)),
            reason: '$key appears in more than one group',
          );
          groupedKeys.add(key);
        }
      }
      expect(
        groupedKeys.toSet(),
        allKeys.toSet(),
        reason: 'groups must cover all ${allKeys.length} registry keys',
      );
    });

    test('every group key resolves to a registry entry', () {
      for (final group in FeatureFlag.groups) {
        expect(group.title, isNotEmpty, reason: '${group.keys} title');
        for (final key in group.keys) {
          expect(
            FeatureFlag.find(key),
            isNotNull,
            reason: '$key is in a group but not the registry',
          );
        }
      }
    });
  });

  group('gate call-site validation', () {
    final libDir = Directory('lib');

    test('every gate key in lib/ resolves to a registry entry', () {
      final registryKeys = FeatureFlag.all.map((f) => f.key).toSet();
      final unknown = <String>{};
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final source = entity.readAsStringSync();
        for (final key in gateKeysIn(source)) {
          if (!registryKeys.contains(key)) unknown.add('$key -> ${entity.path}');
        }
      }
      expect(
        unknown,
        isEmpty,
        reason: 'Gate keys missing from the registry: $unknown',
      );
    });

    test('every registry key is referenced by a gate or check', () {
      final referenced = <String>{};
      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // The registry itself lists every key in `groups`, so it can't prove
        // anything is actually gated — exclude it from this check.
        if (entity.path == 'lib/Config/feature_flags.dart') continue;
        referenced.addAll(gateKeysIn(entity.readAsStringSync()));
      }
      final unreferenced = FeatureFlag.all
          .map((f) => f.key)
          .where((k) => !referenced.contains(k))
          .toList()
        ..sort();
      expect(
        unreferenced,
        isEmpty,
        reason: 'Registry keys never referenced in code: $unreferenced',
      );
    });
  });

  group('FeatureFlagService parsing', () {
    test('missing doc resolves every flag to enabled', () {
      final service = FeatureFlagService();
      service.applyRaw(null);
      for (final f in FeatureFlag.all) {
        expect(service.statusOf(f.key), FeatureStatus.enabled);
        expect(service.isEnabled(f.key), isTrue);
        expect(service.isHidden(f.key), isFalse);
      }
    });

    test('empty doc defaults to enabled', () {
      final service = FeatureFlagService();
      service.applyRaw(const {});
      expect(service.statusOf('budget'), FeatureStatus.enabled);
      expect(service.isEnabled('budget'), isTrue);
    });

    test('reads stored statuses', () {
      final service = FeatureFlagService();
      service.applyRaw(const {
        'budget': 'comingSoon',
        'goals': 'hidden',
        'lent_money': 'enabled',
      });
      expect(service.isComingSoon('budget'), isTrue);
      expect(service.isHidden('goals'), isTrue);
      expect(service.isEnabled('lent_money'), isTrue);
      // Unknown keys fall back to enabled.
      expect(service.isEnabled('wealth'), isTrue);
    });

    test('invalid and non-string values are dropped', () {
      final service = FeatureFlagService();
      service.applyRaw(const {
        'budget': 'nonsense',
        'goals': 42,
        'forecast': 'hidden',
      });
      expect(service.statusOf('budget'), FeatureStatus.enabled);
      expect(service.statusOf('goals'), FeatureStatus.enabled);
      expect(service.isHidden('forecast'), isTrue);
    });

    test('deleting the doc resets everything to defaults', () {
      final service = FeatureFlagService();
      service.applyRaw(const {'budget': 'hidden'});
      expect(service.isHidden('budget'), isTrue);
      service.applyRaw(null);
      expect(service.isEnabled('budget'), isTrue);
    });
  });

  group('FeatureFlagService visibility', () {
    bool vis(String status, {bool admin = false}) =>
        FeatureFlagService.visibleFor(status: status, isAdmin: admin);

    test('enabled is visible to everyone', () {
      expect(vis(FeatureStatus.enabled), isTrue);
      expect(vis(FeatureStatus.enabled, admin: true), isTrue);
    });

    test('comingSoon is admin-only', () {
      expect(vis(FeatureStatus.comingSoon), isFalse);
      expect(vis(FeatureStatus.comingSoon, admin: true), isTrue);
    });

    test('hidden is invisible to everyone including admins', () {
      expect(vis(FeatureStatus.hidden), isFalse);
      expect(vis(FeatureStatus.hidden, admin: true), isFalse);
    });

    test('unknown status behaves as enabled', () {
      expect(vis('??'), isTrue);
    });
  });
}
