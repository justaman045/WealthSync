import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:money_control/Components/colors.dart';
import 'package:money_control/Controllers/challenges_controller.dart';
import 'package:money_control/Controllers/currency_controller.dart';
import 'package:money_control/Controllers/transaction_controller.dart';
import 'package:money_control/Models/challenge_model.dart';
import 'package:money_control/data/challenge_presets.dart';
import 'dart:math';

class SavingsChallengesScreen extends StatefulWidget {
  const SavingsChallengesScreen({super.key});

  @override
  State<SavingsChallengesScreen> createState() => _SavingsChallengesScreenState();
}

class _SavingsChallengesScreenState extends State<SavingsChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late ConfettiController _confetti;
  final Set<String> _completingIds = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _tab.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark ? AppColors.darkGradient : AppColors.lightGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Savings Challenges"),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            controller: _tab,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.white60,
            tabs: const [Tab(text: "Active"), Tab(text: "Library")],
          ),
        ),
        floatingActionButton: TabBuilder(
          controller: _tab,
          builder: (index) => index == 0
              ? FloatingActionButton.extended(
                  onPressed: _showCustomChallengeSheet,
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Custom", style: TextStyle(color: Colors.white)),
                )
              : const SizedBox.shrink(),
        ),
        body: Stack(
          children: [
            TabBarView(
              controller: _tab,
              children: [_buildActiveTab(), _buildLibraryTab()],
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [Colors.green, Colors.blue, Colors.pink, Colors.orange],
                createParticlePath: _drawStar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    return Obx(() {
      final ctrl = ChallengesController.to;
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final active = ctrl.challenges.where((c) => !c.isCompleted).toList();
      if (active.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_outlined, size: 64.sp, color: Colors.white24),
              SizedBox(height: 16.h),
              Text(
                "Start your first challenge 🎯",
                style: TextStyle(fontSize: 16.sp, color: Colors.white60),
              ),
              SizedBox(height: 8.h),
              Text(
                "Browse the Library tab or tap + Custom",
                style: TextStyle(fontSize: 13.sp, color: Colors.white38),
              ),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: active.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (_, i) => _buildChallengeCard(active[i]),
      );
    });
  }

  Widget _buildChallengeCard(SavingsChallengeModel c) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (!Get.isRegistered<TransactionController>()) Get.put(TransactionController());
    final txCtrl = Get.find<TransactionController>();
    final sym = CurrencyController.to.currencySymbol.value;
    final progress = ChallengesController.to.computeProgress(
      c,
      txCtrl.transactions,
      uid,
    );

    double percent = 0;
    String progressLabel = '';
    String targetLabel = '';

    if (c.trackingType == 'no_spend_category') {
      final spent = progress;
      percent = c.targetAmount == 0
          ? (spent == 0 ? 1.0 : 0.0)
          : (1 - (spent / c.targetAmount)).clamp(0.0, 1.0);
      progressLabel = "$sym${spent.toStringAsFixed(0)} spent";
      targetLabel = "Goal: ${sym}0 on ${c.trackedCategory}";
    } else {
      percent = c.targetAmount > 0 ? (progress / c.targetAmount).clamp(0.0, 1.0) : 0;
      progressLabel = "$sym${progress.toStringAsFixed(0)} saved";
      targetLabel = "Target: $sym${c.targetAmount.toStringAsFixed(0)}";
    }

    final isNearComplete = percent >= 0.9 && !c.isCompleted;
    if (percent >= 1.0 && !c.isCompleted && !_completingIds.contains(c.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completingIds.add(c.id);
        _confetti.play();
        ChallengesController.to.markComplete(c);
      });
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isNearComplete
              ? Colors.amber.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              if (c.daysLeft == 0 && !c.isCompleted)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text("Expired", style: TextStyle(fontSize: 11.sp, color: Colors.red)),
                )
              else
                Text(
                  "${c.daysLeft}d left",
                  style: TextStyle(fontSize: 12.sp, color: Colors.white60),
                ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => ChallengesController.to.deleteChallenge(c.id),
                child: Icon(Icons.close, size: 18.sp, color: Colors.white38),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(6.r),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8.h,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                c.trackingType == 'no_spend_category'
                    ? (percent > 0 ? Colors.red : Colors.green)
                    : AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(progressLabel, style: TextStyle(fontSize: 12.sp, color: Colors.white70)),
              Text(
                "${(percent * 100).toStringAsFixed(0)}%",
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: percent >= 1.0 ? Colors.greenAccent : AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(targetLabel, style: TextStyle(fontSize: 11.sp, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      itemCount: challengePresets.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (_, i) => _buildPresetCard(challengePresets[i]),
    );
  }

  Widget _buildPresetCard(ChallengePreset preset) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Text(preset.emoji, style: TextStyle(fontSize: 30.sp)),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.name,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: theme.textTheme.bodyLarge?.color),
                ),
                SizedBox(height: 4.h),
                Text(
                  preset.description,
                  style: TextStyle(fontSize: 12.sp, color: Colors.white60),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          GestureDetector(
            onTap: () => _startPreset(preset),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                "Start",
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startPreset(ChallengePreset preset) {
    // Presets that require custom target/end: show a mini sheet
    if (preset.targetAmount == 0 || preset.durationDays == 0) {
      _showStartPresetSheet(preset);
      return;
    }
    final now = DateTime.now();
    final challenge = SavingsChallengeModel(
      id: '',
      name: preset.name,
      description: preset.description,
      targetAmount: preset.targetAmount,
      startDate: now,
      endDate: now.add(Duration(days: preset.durationDays)),
      type: 'preset',
      presetId: preset.id,
      trackingType: preset.trackingType,
      trackedCategory: preset.trackedCategory,
    );
    ChallengesController.to.addChallenge(challenge).then((ok) {
      if (ok) {
        _tab.animateTo(0);
        Get.snackbar("Challenge Started!", "${preset.name} is now active.",
            backgroundColor: AppColors.primary.withValues(alpha: 0.9), colorText: Colors.white);
      }
    });
  }

  void _showStartPresetSheet(ChallengePreset preset) {
    final targetCtrl = TextEditingController(
      text: preset.targetAmount > 0 ? preset.targetAmount.toStringAsFixed(0) : '',
    );
    DateTime endDate = DateTime.now().add(
      Duration(days: preset.durationDays > 0 ? preset.durationDays : 90),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => _challengeSheet(
          title: "Start ${preset.name}",
          targetCtrl: targetCtrl,
          endDate: endDate,
          onEndDatePick: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: endDate,
              firstDate: DateTime.now().add(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (picked != null) setS(() => endDate = picked);
          },
          onSubmit: () {
            final target = double.tryParse(targetCtrl.text) ?? preset.targetAmount;
            final now = DateTime.now();
            final challenge = SavingsChallengeModel(
              id: '',
              name: preset.name,
              description: preset.description,
              targetAmount: target,
              startDate: now,
              endDate: endDate,
              type: 'preset',
              presetId: preset.id,
              trackingType: preset.trackingType,
              trackedCategory: preset.trackedCategory,
            );
            ChallengesController.to.addChallenge(challenge).then((ok) {
              if (ok) {
                Get.back();
                _tab.animateTo(0);
              }
            });
          },
        ),
      ),
    ).whenComplete(() => targetCtrl.dispose());
  }

  void _showCustomChallengeSheet() {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => _challengeSheet(
          title: "Custom Challenge",
          targetCtrl: targetCtrl,
          endDate: endDate,
          nameCtrl: nameCtrl,
          onEndDatePick: () async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: endDate,
              firstDate: DateTime.now().add(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (picked != null) setS(() => endDate = picked);
          },
          onSubmit: () {
            if (nameCtrl.text.trim().isEmpty) return;
            final target = double.tryParse(targetCtrl.text) ?? 0;
            final now = DateTime.now();
            final challenge = SavingsChallengeModel(
              id: '',
              name: nameCtrl.text.trim(),
              description: "Custom challenge",
              targetAmount: target,
              startDate: now,
              endDate: endDate,
            );
            ChallengesController.to.addChallenge(challenge).then((ok) {
              if (ok) Get.back();
            });
          },
        ),
      ),
    ).whenComplete(() {
      nameCtrl.dispose();
      targetCtrl.dispose();
    });
  }

  Widget _challengeSheet({
    required String title,
    required TextEditingController targetCtrl,
    required DateTime endDate,
    required VoidCallback onEndDatePick,
    required VoidCallback onSubmit,
    TextEditingController? nameCtrl,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
            SizedBox(height: 20.h),
            if (nameCtrl != null) ...[
              _inputField("Challenge Name", nameCtrl, theme, isDark),
              SizedBox(height: 14.h),
            ],
            _inputField("Target Amount (${CurrencyController.to.currencySymbol.value})", targetCtrl, theme, isDark, isNumber: true),
            SizedBox(height: 14.h),
            GestureDetector(
              onTap: onEndDatePick,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 18.sp, color: AppColors.primary),
                    SizedBox(width: 10.w),
                    Text(
                      "End: ${DateFormat('dd MMM yyyy').format(endDate)}",
                      style: TextStyle(fontSize: 14.sp, color: theme.textTheme.bodyLarge?.color),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                ),
                onPressed: onSubmit,
                child: Text("Start Challenge", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String hint, TextEditingController ctrl, ThemeData theme, bool isDark, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 15.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
      ),
    );
  }

  Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step), halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfDegreesPerStep), halfWidth + internalRadius * sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }
}

// Helper: rebuild FAB when tab changes
class TabBuilder extends StatefulWidget {
  final TabController controller;
  final Widget Function(int index) builder;

  const TabBuilder({super.key, required this.controller, required this.builder});

  @override
  State<TabBuilder> createState() => _TabBuilderState();
}

class _TabBuilderState extends State<TabBuilder> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChange);
  }

  void _onTabChange() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(widget.controller.index);
}
