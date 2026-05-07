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

    // Auto-complete: savings challenges reach 100% of target, or no-spend challenges
    // only complete after the period ends with zero spending.
    final bool shouldAutoComplete;
    if (c.trackingType == 'no_spend_category') {
      shouldAutoComplete = c.isExpired && progress == 0 && !_completingIds.contains(c.id);
    } else {
      shouldAutoComplete = percent >= 1.0 && !c.isCompleted && !_completingIds.contains(c.id);
    }
    if (shouldAutoComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completingIds.add(c.id);
        _confetti.play();
        ChallengesController.to.markComplete(c);
      });
    }

    final isNearComplete = (c.trackingType == 'no_spend_category')
        ? (c.isExpired && progress == 0 && !c.isCompleted)
        : (percent >= 0.9 && !c.isCompleted);

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
    return Obx(() {
      final activePresetIds = ChallengesController.to.challenges
          .where((c) => c.isActive && !c.isCompleted && c.presetId != null)
          .map((c) => c.presetId!)
          .toSet();

      return ListView.separated(
        padding: EdgeInsets.all(16.w),
        itemCount: challengePresets.length,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (_, i) {
          final preset = challengePresets[i];
          final isInProgress = activePresetIds.contains(preset.id);
          return _buildPresetCard(preset, isInProgress: isInProgress);
        },
      );
    });
  }

  Widget _buildPresetCard(ChallengePreset preset, {bool isInProgress = false}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Opacity(
      opacity: isInProgress ? 0.4 : 1.0,
      child: Container(
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
            isInProgress
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      "In Progress",
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: Colors.white38),
                    ),
                  )
                : GestureDetector(
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
      ),
    );
  }

  void _startPreset(ChallengePreset preset) {
    // Always show sheet so user can customize duration (and target for savings challenges)
    _showStartPresetSheet(preset);
  }

  void _showStartPresetSheet(ChallengePreset preset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PresetChallengeSheet(
        preset: preset,
        onComplete: () {
          if (mounted) _tab.animateTo(0);
        },
      ),
    );
  }

  void _showCustomChallengeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CustomChallengeSheet(),
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

class _DurationState {
  DateTime endDate;
  int selectedDays;
  final TextEditingController daysCtrl;

  _DurationState({required this.endDate, required this.selectedDays, required this.daysCtrl});
}

class _ChallengeSheetContent extends StatelessWidget {
  final String title;
  final TextEditingController? nameCtrl;
  final TextEditingController? targetCtrl;
  final _DurationState durationState;
  final bool showDays;
  final VoidCallback onEndDatePick;
  final Function(int)? onDaysChanged;
  final VoidCallback onSubmit;

  const _ChallengeSheetContent({
    required this.title,
    this.nameCtrl,
    this.targetCtrl,
    required this.durationState,
    required this.showDays,
    required this.onEndDatePick,
    this.onDaysChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final showTarget = targetCtrl != null;
    final quickOptions = const [7, 14, 30, 60, 90];
    final currentDays = showDays ? durationState.selectedDays : 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: EdgeInsets.all(24.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              SizedBox(height: 20.h),
              if (nameCtrl != null) ...[
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: "Challenge Name",
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: 14.h),
              ],
              if (showTarget) ...[
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: "Target Amount (${CurrencyController.to.currencySymbol.value})",
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: 14.h),
              ],
              if (showDays) ...[
                Text("Duration (days)", style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white60 : Colors.black54)),
                SizedBox(height: 8.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: quickOptions.map((d) {
                    final isSelected = d == currentDays;
                    return GestureDetector(
                      onTap: () => onDaysChanged?.call(d),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
                        ),
                        child: Text(
                          "$d days",
                          style: TextStyle(fontSize: 13.sp, fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal, color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black54)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 10.h),
                TextField(
                  controller: durationState.daysCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final days = int.tryParse(v) ?? 0;
                    if (days > 0) onDaysChanged?.call(days);
                  },
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 15.sp),
                  decoration: InputDecoration(
                    hintText: "Or enter custom days",
                    hintStyle: TextStyle(color: Colors.white38, fontSize: 14.sp),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14.r), borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: 14.h),
              ],
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
                        "Ends: ${DateFormat('dd MMM yyyy').format(durationState.endDate)}",
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
      ),
    );
  }
}

class _PresetChallengeSheet extends StatefulWidget {
  final ChallengePreset preset;
  final VoidCallback? onComplete;

  const _PresetChallengeSheet({required this.preset, this.onComplete});

  @override
  State<_PresetChallengeSheet> createState() => _PresetChallengeSheetState();
}

class _PresetChallengeSheetState extends State<_PresetChallengeSheet> {
  late final TextEditingController _targetCtrl;
  late final TextEditingController _daysCtrl;
  late _DurationState _durationState;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _daysCtrl = TextEditingController(
      text: widget.preset.durationDays > 0 ? widget.preset.durationDays.toString() : '30',
    );
    final showTarget = widget.preset.trackingType != 'no_spend_category';
    _targetCtrl = TextEditingController(
      text: showTarget && widget.preset.targetAmount > 0 ? widget.preset.targetAmount.toStringAsFixed(0) : '',
    );
    final initialDays = int.tryParse(_daysCtrl.text) ?? (widget.preset.durationDays > 0 ? widget.preset.durationDays : 30);
    _durationState = _DurationState(
      endDate: DateTime.now().add(Duration(days: initialDays)),
      selectedDays: initialDays,
      daysCtrl: _daysCtrl,
    );
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _onEndDatePick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _durationState.endDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (!mounted) return;
    if (picked != null) {
      final days = picked.difference(DateTime.now()).inDays.clamp(1, 730);
      setState(() {
        _durationState.endDate = picked;
        _durationState.selectedDays = days;
        _durationState.daysCtrl.text = days.toString();
      });
    }
  }

  void _onDaysChanged(int days) {
    if (!mounted) return;
    setState(() {
      _durationState.selectedDays = days.clamp(1, 730);
      _durationState.endDate = DateTime.now().add(Duration(days: _durationState.selectedDays));
    });
  }

  Future<void> _onSubmit() async {
    if (!mounted || _submitting) return;
    final showTarget = widget.preset.trackingType != 'no_spend_category';
    final target = showTarget
        ? (double.tryParse(_targetCtrl.text) ?? widget.preset.targetAmount.toDouble())
        : 0.0;
    final now = DateTime.now();
    final challenge = SavingsChallengeModel(
      id: '',
      name: widget.preset.name,
      description: widget.preset.description,
      targetAmount: target,
      startDate: now,
      endDate: _durationState.endDate,
      type: 'preset',
      presetId: widget.preset.id,
      trackingType: widget.preset.trackingType,
      trackedCategory: widget.preset.trackedCategory,
    );
    setState(() => _submitting = true);
    final ok = await ChallengesController.to.addChallenge(challenge);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      widget.onComplete?.call();
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showTarget = widget.preset.trackingType != 'no_spend_category';
    return _ChallengeSheetContent(
      title: "Start ${widget.preset.name}",
      targetCtrl: showTarget ? _targetCtrl : null,
      durationState: _durationState,
      showDays: true,
      onEndDatePick: _onEndDatePick,
      onDaysChanged: _onDaysChanged,
      onSubmit: _onSubmit,
    );
  }
}

class _CustomChallengeSheet extends StatefulWidget {
  const _CustomChallengeSheet();

  @override
  State<_CustomChallengeSheet> createState() => _CustomChallengeSheetState();
}

class _CustomChallengeSheetState extends State<_CustomChallengeSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _daysCtrl;
  late _DurationState _durationState;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _targetCtrl = TextEditingController();
    _daysCtrl = TextEditingController(text: '30');
    _durationState = _DurationState(
      endDate: DateTime.now().add(const Duration(days: 30)),
      selectedDays: 30,
      daysCtrl: _daysCtrl,
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _daysCtrl.dispose();
    super.dispose();
  }

  Future<void> _onEndDatePick() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _durationState.endDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (!mounted) return;
    if (picked != null) {
      final days = picked.difference(DateTime.now()).inDays.clamp(1, 730);
      setState(() {
        _durationState.endDate = picked;
        _durationState.selectedDays = days;
        _durationState.daysCtrl.text = days.toString();
      });
    }
  }

  void _onDaysChanged(int days) {
    if (!mounted) return;
    setState(() {
      _durationState.selectedDays = days.clamp(1, 730);
      _durationState.endDate = DateTime.now().add(Duration(days: _durationState.selectedDays));
    });
  }

  Future<void> _onSubmit() async {
    if (!mounted || _submitting) return;
    if (_nameCtrl.text.trim().isEmpty) return;
    final target = double.tryParse(_targetCtrl.text) ?? 0;
    final now = DateTime.now();
    final challenge = SavingsChallengeModel(
      id: '',
      name: _nameCtrl.text.trim(),
      description: "Custom challenge",
      targetAmount: target,
      startDate: now,
      endDate: _durationState.endDate,
    );
    setState(() => _submitting = true);
    final ok = await ChallengesController.to.addChallenge(challenge);
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
    else setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return _ChallengeSheetContent(
      title: "Custom Challenge",
      nameCtrl: _nameCtrl,
      targetCtrl: _targetCtrl,
      durationState: _durationState,
      showDays: true,
      onEndDatePick: _onEndDatePick,
      onDaysChanged: _onDaysChanged,
      onSubmit: _onSubmit,
    );
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
