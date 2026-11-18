import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:money_control/Controllers/goals_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Services/emergency_fund_settings.dart';
import 'package:money_control/Services/income_settings.dart';
import 'package:money_control/Utils/wealth_math.dart';

/// Emergency fund: a savings goal whose target is 6 × monthly income.
///
/// The goal is created automatically (after user confirmation) when the
/// account's total balance falls short of 6× income. Progress is measured
/// against `TransactionController.totalBalance` — "money in account".
///
/// When active, the earmarked amount (`min(balance, target)`) is treated as
/// additional savings reserved, reducing the disposable budget in
/// [computeDailyLimit]. When the balance reaches the target, the goal stays
/// as a buffer (never archived).
class EmergencyFundService extends GetxController {
  static EmergencyFundService get to => Get.find();

  final _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  /// Target = 6 × expected monthly income. Returns 0 when no income is
  /// available (no manual income set and no transaction income detected).
  double getTargetAmount({
    required List<dynamic> allTx,
  }) {
    final uid = _uid;
    if (uid == null) return 0.0;

    final result = computeExpectedIncome(
      allTx: allTx,
      uid: uid,
      mode: IncomeSettings.mode.value,
      manualMonthly: IncomeSettings.manualMonthly.value,
    );
    if (result.expectedIncome <= 0) return 0.0;
    return result.expectedIncome * 6.0;
  }

  /// Whether the emergency fund should be offered right now:
  /// enabled in settings, income available, balance below target, and no
  /// existing emergency fund goal.
  Future<bool> isEligible({required List<dynamic> allTx}) async {
    if (!EmergencyFundSettings.enabled.value) return false;

    final target = getTargetAmount(allTx: allTx);
    if (target <= 0) return false;

    final ctrl = Get.find<TransactionController>();
    final balance = ctrl.totalBalance;
    if (balance >= target) return false;

    final goalsCtrl = GoalsController.to;
    if (goalsCtrl.emergencyFundGoal != null) return false;

    return true;
  }

  /// Live: true when the user should be prompted to create the emergency fund
  /// goal. Set by [checkEligibility].
  final RxBool offered = false.obs;

  /// Runs the eligibility check and updates [offered]. Called after sign-in.
  Future<void> checkEligibility() async {
    // Ensure we read the user's saved income settings (not defaults) before
    // computing eligibility. load() may not have completed yet on first sign-in.
    await IncomeSettings.load();

    final uid = _uid;
    if (uid == null) {
      offered.value = false;
      return;
    }
    final txCtrl = Get.find<TransactionController>();
    final allTx = txCtrl.transactions;
    final eligible = await isEligible(allTx: allTx);
    offered.value = eligible;
  }

  /// Creates the emergency fund goal with target = 6 × income. Returns false
  /// if a goal already exists or income is unavailable.
  Future<bool> createGoal({required List<dynamic> allTx}) async {
    final existing = GoalsController.to.emergencyFundGoal;
    if (existing != null) return false;

    final target = getTargetAmount(allTx: allTx);
    if (target <= 0) return false;

    final ok = await GoalsController.to.addGoal(
      name: 'Emergency Fund',
      targetAmount: target,
      description:
          'Six months of income as a safety net. Money here is reserved and '
          'not counted toward your daily spendable limit.',
      emoji: '🛡️',
      isEmergencyFund: true,
    );
    if (ok) {
      // Seed currentAmount with whatever balance already exists.
      await _seedProgress(target);
    }
    return ok;
  }

  /// Seeds [currentAmount] with min(totalBalance, target) so progress reflects
  /// money already in the account.
  Future<void> _seedProgress(double target) async {
    final balance = Get.find<TransactionController>().totalBalance;
    final seed = balance.clamp(0.0, target);
    if (seed > 0) {
      final goal = GoalsController.to.emergencyFundGoal;
      if (goal != null) {
        await GoalsController.to.updateProgress(
          goal.id,
          seed,
        );
      }
    }
  }

  /// Syncs the emergency fund goal's [currentAmount] to the current balance
  /// (capped at target). Call whenever the balance changes.
  Future<void> syncProgress() async {
    final goal = GoalsController.to.emergencyFundGoal;
    if (goal == null) return;

    final balance = Get.find<TransactionController>().totalBalance;
    final current = balance.clamp(0.0, goal.targetAmount);
    if ((current - goal.currentAmount).abs() < 0.01) return;

    await GoalsController.to.setProgress(goal.id, current);
  }

  /// The amount earmarked for the emergency fund: `min(balance, target)`.
  /// Subtract this from disposable budget when computing the daily limit so
  /// emergency savings are not counted as spendable.
  double getEarmarkedAmount({required double target}) {
    if (target <= 0) return 0.0;
    final balance = Get.find<TransactionController>().totalBalance;
    return balance.clamp(0.0, target);
  }

  /// Whether an emergency fund goal exists (reached or not).
  bool get hasGoal => GoalsController.to.emergencyFundGoal != null;

  /// Whether the emergency fund target has been met (balance >= target).
  bool get isReached {
    final goal = GoalsController.to.emergencyFundGoal;
    if (goal == null) return false;
    return Get.find<TransactionController>().totalBalance >= goal.targetAmount;
  }

  @override
  void onInit() {
    super.onInit();
    EmergencyFundSettings.load();
    // IncomeSettings.load() is only called from the settings and analysis
    // screens; load it here too so the emergency fund reads the user's saved
    // mode/manual income instead of the defaults (autoBlend + 0).
    IncomeSettings.load();
    // Sync the existing goal's target right away: load() may change
    // manualMonthly/mode before the ever watchers below are registered, in
    // which case they would never fire for the initial value.
    _syncTargetOnIncomeChange();
    ever(Get.find<TransactionController>().transactions, (_) => checkEligibility());
    ever(IncomeSettings.mode, (_) => _syncTargetOnIncomeChange());
    ever(IncomeSettings.manualMonthly, (_) => _syncTargetOnIncomeChange());
  }

  /// Updates the existing emergency fund goal's target to 6 × current expected
  /// income. No-op when there is no goal, income is unavailable, or the target
  /// hasn't meaningfully changed.
  Future<void> _syncTargetOnIncomeChange() async {
    // Ensure we read the user's saved income settings (not defaults) before
    // computing the target. load() may not have completed yet when this is
    // called from onInit or an ever watcher.
    await IncomeSettings.load();

    final goal = GoalsController.to.emergencyFundGoal;
    if (goal == null) return;

    final txCtrl = Get.find<TransactionController>();
    final allTx = txCtrl.transactions;
    final target = getTargetAmount(allTx: allTx);
    if (target <= 0) return;

    if ((target - goal.targetAmount).abs() < 0.01) return;

    await GoalsController.to.updateGoal(
      id: goal.id,
      name: goal.name,
      targetAmount: target,
      description: goal.description,
      targetDate: goal.targetDate,
      emoji: goal.emoji,
    );

    // Re-seed progress so the capped balance reflects the new target.
    await _seedProgress(target);
  }
}
