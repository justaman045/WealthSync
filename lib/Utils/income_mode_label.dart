import 'package:money_control/Utils/wealth_math.dart';
import 'package:money_control/l10n/app_localizations.dart';

/// Localized display name for an [IncomeMode].
///
/// The mode is data; the label is copy, so it lives here next to the ARB
/// entries it reads instead of being baked into the settings service as English.
String incomeModeLabel(AppLocalizations l10n, IncomeMode mode) {
  switch (mode) {
    case IncomeMode.manual:
      return l10n.incomeModeManual;
    case IncomeMode.autoBlend:
      return l10n.incomeModeBlend;
    case IncomeMode.autoSalaryWindow:
      return l10n.incomeModeSalaryWindow;
  }
}
