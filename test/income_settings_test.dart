import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/income_settings.dart';
import 'package:money_control/Utils/wealth_math.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Income settings drive the AI daily limit, so they are persisted per device.
/// The chooser that writes them must also be offered once (never again after
/// the user has answered), and both entry points must use the same sheet — the
/// settings screen used to show a bare radio list that explained nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await IncomeSettings.reset();
  });

  group('IncomeSettings persistence', () {
    test('defaults to the blend mode and an unseen chooser', () async {
      await IncomeSettings.load();
      expect(IncomeSettings.mode.value, IncomeMode.autoBlend);
      expect(IncomeSettings.manualMonthly.value, 0.0);
      expect(IncomeSettings.confirmed.value, isFalse);
    });

    test('setMode survives a reload', () async {
      await IncomeSettings.setMode(IncomeMode.autoSalaryWindow);
      await IncomeSettings.load();
      expect(IncomeSettings.mode.value, IncomeMode.autoSalaryWindow);
    });

    test('setManual ignores non-positive values', () async {
      await IncomeSettings.setManual(-500);
      expect(IncomeSettings.manualMonthly.value, 0.0);
      await IncomeSettings.setManual(double.nan);
      expect(IncomeSettings.manualMonthly.value, 0.0);
      await IncomeSettings.setManual(42000);
      await IncomeSettings.load();
      expect(IncomeSettings.manualMonthly.value, 42000);
    });

    test('markConfirmed is persisted so the sheet opens only once', () async {
      await IncomeSettings.markConfirmed();
      expect(IncomeSettings.confirmed.value, isTrue);

      // Simulate a cold start: the in-memory defaults reset first.
      IncomeSettings.confirmed.value = false;
      await IncomeSettings.load();
      expect(IncomeSettings.confirmed.value, isTrue);
    });

    test('reset clears the mode, the amount and the confirmation', () async {
      await IncomeSettings.setMode(IncomeMode.manual);
      await IncomeSettings.setManual(30000);
      await IncomeSettings.markConfirmed();

      await IncomeSettings.reset();

      expect(IncomeSettings.mode.value, IncomeMode.autoBlend);
      expect(IncomeSettings.manualMonthly.value, 0.0);
      expect(IncomeSettings.confirmed.value, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(IncomeSettings.modeKey), isNull);
      expect(prefs.getBool(IncomeSettings.confirmedKey), isNull);
    });
  });

  group('the chooser is shared and shown once', () {
    test('AI Insights opens it only while unconfirmed', () {
      final source = File('lib/Screens/analysis.dart').readAsStringSync();
      expect(source, contains('IncomeSettings.confirmed.value'));
      expect(source, contains('showIncomeModeSheet(context)'));
    });

    test('Settings uses the same sheet, not its own radio list', () {
      final source =
          File('lib/Screens/Settings/general_settings.dart').readAsStringSync();
      expect(source, contains('showIncomeModeSheet(context)'));
      expect(
        source,
        isNot(contains('RadioListTile<IncomeMode>')),
        reason: 'a second income-mode UI drifts from the explainer sheet',
      );
    });

    test('every mode has an explanation key', () {
      final arb = File('lib/l10n/app_en.arb').readAsStringSync();
      expect(arb, contains('"incomeModeManualHint"'));
      expect(arb, contains('"incomeModeBlendHint"'));
      expect(arb, contains('"incomeModeSalaryWindowHint"'));
    });
  });
}
