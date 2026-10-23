import 'package:money_control/l10n/app_localizations.dart';
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
import 'package:money_control/Services/performance_controller.dart';
import 'package:money_control/Models/challenge_model.dart';
import 'package:money_control/data/challenge_presets.dart';
import 'dart:math';
import 'package:money_control/Utils/responsive.dart';
import 'package:money_control/Components/empty_state.dart';

class SavingsChallengesScreen extends StatefulWidget {
  const SavingsChallengesScreen({super.key});

  @override
  State<SavingsChallengesScreen> createState() =>
      _SavingsChallengesScreenState();
}

class _SavingsChallengesScreenState extends State<SavingsChallengesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late ConfettiController _confetti;
  late final ChallengesController _ctrl;
  late final TransactionController _txCtrl;
  final Set<String> _completingIds = {};

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    if (!Get.isRegistered<ChallengesController>()) {
      Get.put(ChallengesController());
    }
    _ctrl = Get.find<ChallengesController>();
    if (!Get.isRegistered<TransactionController>()) {
      Get.put(TransactionController());
    }
    _txCtrl = Get.find<TransactionController>();
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
          title: Text(AppLocalizations.of(context)!.savingsChallenges),
          bottom: TabBar(
            controller: _tab,
            tabs: [
              Tab(text: AppLocalizations.of(context)!.activeTab),
              Tab(text: AppLocalizations.of(context)!.libraryTab),
            ],
          ),
        ),
        floatingActionButton: TabBuilder(
          controller: _tab,
          builder: (index) => index == 0
              ? FloatingActionButton.extended(
                  onPressed: _showCustomChallengeSheet,
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context)!.custom),
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
              child: PerformanceController.to.liteMode.value
                  ? const SizedBox.shrink()
                  : ConfettiWidget(
                      confettiController: _confetti,
                      blastDirectionality: BlastDirectionality.explosive,
                      shouldLoop: false,
                      colors: const [
                        AppColors.success,
                        AppColors.primary,
                        AppColors.accent,
                        AppColors.warning,
                      ],
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
      final ctrl = _ctrl;
      if (ctrl.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      final active = ctrl.challenges.where((c) => !c.isCompleted).toList();
      if (active.isEmpty) {
        return Center(
          child: EmptyStateWidget(
            icon: Icons.emoji_events_outlined,
            title: AppLocalizations.of(context)!.startFirstChallenge,
            subtitle: AppLocalizations.of(
              context,
            )!.browseLibraryTabTapCustom,
          ),
        );
      }
      return ListView.separated(
        padding: EdgeInsets.all(AppSpace.s16.w),
        itemCount: active.length,
        separatorBuilder: (_, __) => SizedBox(height: AppSpace.s12.h),
        itemBuilder: (_, i) => _buildChallengeCard(active[i]),
      );
    });
  }

  Widget _buildChallengeCard(SavingsChallengeModel c) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final txCtrl = _txCtrl;
    final l10n = AppLocalizations.of(context)!;
    final sym = CurrencyController.to.currencySymbol.value;
    final progress = _ctrl.computeProgress(c, txCtrl.transactions, uid);

    double percent = 0;
    String progressLabel = '';
    String targetLabel = '';

    if (c.trackingType == 'no_spend_category') {
      final spent = progress;
      percent = c.targetAmount == 0
          ? (spent == 0 ? 1.0 : 0.0)
          : (1 - (spent / c.targetAmount)).clamp(0.0, 1.0);
      progressLabel = l10n.challengeSpent("$sym${spent.toStringAsFixed(0)}");
      targetLabel = l10n.challengeZeroSpendGoal(
        "${sym}0",
        c.trackedCategory ?? '',
      );
    } else {
      percent = c.targetAmount > 0
          ? (progress / c.targetAmount).clamp(0.0, 1.0)
          : 0;
      progressLabel = l10n.challengeSaved(
        "$sym${progress.toStringAsFixed(0)}",
      );
      targetLabel = l10n.challengeTarget(
        "$sym${c.targetAmount.toStringAsFixed(0)}",
      );
    }

    // Auto-complete: savings challenges reach 100% of target, or no-spend challenges
    // only complete after the period ends with zero spending.
    final bool shouldAutoComplete;
    if (c.trackingType == 'no_spend_category') {
      shouldAutoComplete =
          c.isExpired && progress == 0 && !_completingIds.contains(c.id);
    } else {
      shouldAutoComplete =
          percent >= 1.0 && !c.isCompleted && !_completingIds.contains(c.id);
    }
    if (shouldAutoComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _completingIds.add(c.id);
        _confetti.play();
        _ctrl.markComplete(c);
      });
    }

    final isNearComplete = (c.trackingType == 'no_spend_category')
        ? (c.isExpired && progress == 0 && !c.isCompleted)
        : (percent >= 0.9 && !c.isCompleted);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Container(
      padding: EdgeInsets.all(AppSpace.s16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.lightSurfaceCard,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(
          color: isNearComplete
              ? AppColors.warning.withValues(alpha: 0.5)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        boxShadow: AppElevation.raised(isDark: isDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.name, style: AppType.titleMedium(textColor)),
              ),
              if (c.daysLeft == 0 && !c.isCompleted)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpace.s8.w,
                    vertical: AppSpace.s2.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.xs.r),
                  ),
                  child: Text(
                    l10n.expired,
                    style: AppType.labelSmall(AppColors.error),
                  ),
                )
              else
                Text(
                  l10n.challengeDaysLeftShort(c.daysLeft),
                  style: AppType.bodySmall(secondaryColor),
                ),
              SizedBox(width: AppSpace.s4.w),
              // Was an 18 pt icon in a GestureDetector: a destructive action on
              // a ~20 dp target, with nothing announced to a screen reader.
              IconButton(
                onPressed: () => _ctrl.deleteChallenge(c.id),
                tooltip: l10n.delete,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close, size: 18.sp, color: tertiaryColor),
              ),
            ],
          ),
          SizedBox(height: AppSpace.s8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs.r),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8.h,
              backgroundColor: isDark
                  ? AppColors.darkSurface
                  : AppColors.lightActionSurface,
              valueColor: AlwaysStoppedAnimation(
                c.trackingType == 'no_spend_category'
                    ? (percent > 0 ? AppColors.error : AppColors.success)
                    : AppColors.primary,
              ),
            ),
          ),
          SizedBox(height: AppSpace.s8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(progressLabel, style: AppType.bodySmall(secondaryColor)),
              Text(
                "${(percent * 100).toStringAsFixed(0)}%",
                style: AppType.labelMedium(
                  percent >= 1.0 ? AppColors.success : AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpace.s4.h),
          Text(targetLabel, style: AppType.labelSmall(tertiaryColor)),
        ],
      ),
    );
  }

  Widget _buildLibraryTab() {
    return Obx(() {
      final activePresetIds = _ctrl.challenges
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Opacity(
      opacity: isInProgress ? 0.4 : 1.0,
      child: Container(
        padding: EdgeInsets.all(AppSpace.s16.w),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceCard
              : AppColors.lightSurfaceCard,
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: AppElevation.raised(isDark: isDark),
        ),
        child: Row(
          children: [
            Text(preset.emoji, style: AppType.headlineSmall(textColor)),
            SizedBox(width: AppSpace.s12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(preset.name, style: AppType.titleSmall(textColor)),
                  SizedBox(height: AppSpace.s4.h),
                  Text(
                    preset.description,
                    style: AppType.bodySmall(secondaryColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: AppSpace.s12.w),
            if (isInProgress)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpace.s12.w,
                  vertical: AppSpace.s8.h,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightActionSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                ),
                child: Text(
                  l10n.progress,
                  style: AppType.labelMedium(
                    isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                  ),
                ),
              )
            else
              // A primary→secondary gradient on a GestureDetector: two accent
              // colours for one button, and no ripple or button semantics.
              FilledButton(
                onPressed: () => _startPreset(preset),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpace.s16.w,
                    vertical: AppSpace.s8.h,
                  ),
                  textStyle: AppType.labelMedium(
                    Theme.of(context).colorScheme.onPrimary,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l10n.start),
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
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
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
      constraints: BoxConstraints(maxWidth: Responsive.sheetMaxWidth(context)),
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
      path.lineTo(
        halfWidth + externalRadius * cos(step),
        halfWidth + externalRadius * sin(step),
      );
      path.lineTo(
        halfWidth + internalRadius * cos(step + halfDegreesPerStep),
        halfWidth + internalRadius * sin(step + halfDegreesPerStep),
      );
    }
    path.close();
    return path;
  }
}

class _DurationState {
  DateTime endDate;
  int selectedDays;
  final TextEditingController daysCtrl;

  _DurationState({
    required this.endDate,
    required this.selectedDays,
    required this.daysCtrl,
  });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final showTarget = targetCtrl != null;
    final quickOptions = const [7, 14, 30, 60, 90];
    final currentDays = showDays ? durationState.selectedDays : 0;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final fieldFill =
        isDark ? AppColors.darkSurfaceCard : AppColors.lightActionSurface;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: EdgeInsets.all(AppSpace.s24.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl.r),
          ),
        ),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.contentMaxWidth(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppType.titleLarge(textColor)),
                  SizedBox(height: AppSpace.s20.h),
                  if (nameCtrl != null) ...[
                    TextField(
                      controller: nameCtrl,
                      style: AppType.titleMedium(textColor),
                      decoration: InputDecoration(
                        hintText: l10n.challengeNameHint,
                      ),
                    ),
                    SizedBox(height: AppSpace.s12.h),
                  ],
                  if (showTarget) ...[
                    TextField(
                      controller: targetCtrl,
                      keyboardType: TextInputType.number,
                      style: AppType.titleMedium(textColor),
                      decoration: InputDecoration(
                        hintText: l10n.challengeTargetHint(
                          CurrencyController.to.currencySymbol.value,
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpace.s12.h),
                  ],
                  if (showDays) ...[
                    Text(
                      l10n.durationDays,
                      style: AppType.bodySmall(
                        isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                    SizedBox(height: AppSpace.s8.h),
                    // Hand-painted pills became chips: the chip theme owns
                    // selection colour, border and semantics.
                    Wrap(
                      spacing: AppSpace.s8.w,
                      runSpacing: AppSpace.s8.h,
                      children: quickOptions.map((d) {
                        final isSelected = d == currentDays;
                        return ChoiceChip(
                          label: Text(l10n.challengeDaysOption(d)),
                          selected: isSelected,
                          onSelected: (_) => onDaysChanged?.call(d),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: AppSpace.s12.h),
                    TextField(
                      controller: durationState.daysCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final days = int.tryParse(v) ?? 0;
                        if (days > 0) onDaysChanged?.call(days);
                      },
                      style: AppType.titleMedium(textColor),
                      decoration: InputDecoration(
                        hintText: l10n.challengeCustomDaysHint,
                      ),
                    ),
                    SizedBox(height: AppSpace.s12.h),
                  ],
                  InkWell(
                    onTap: onEndDatePick,
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpace.s16.w,
                        vertical: AppSpace.s12.h,
                      ),
                      decoration: BoxDecoration(
                        color: fieldFill,
                        borderRadius: BorderRadius.circular(AppRadius.sm.r),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 18.sp,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: AppSpace.s8.w),
                          Expanded(
                            child: Text(
                              l10n.challengeEndsOn(
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(durationState.endDate),
                              ),
                              style: AppType.bodyLarge(textColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpace.s24.h),
                  SizedBox(
                    width: double.infinity,
                    height: 52.h,
                    child: FilledButton(
                      onPressed: onSubmit,
                      child: Text(l10n.startChallenge),
                    ),
                  ),
                  SizedBox(height: AppSpace.s8.h),
                ],
              ),
            ),
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
  late final ChallengesController _ctrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _daysCtrl;
  late _DurationState _durationState;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ChallengesController>()) {
      Get.put(ChallengesController());
    }
    _ctrl = Get.find<ChallengesController>();
    _daysCtrl = TextEditingController(
      text: widget.preset.durationDays > 0
          ? widget.preset.durationDays.toString()
          : '30',
    );
    final showTarget = widget.preset.trackingType != 'no_spend_category';
    _targetCtrl = TextEditingController(
      text: showTarget && widget.preset.targetAmount > 0
          ? widget.preset.targetAmount.toStringAsFixed(0)
          : '',
    );
    final initialDays =
        int.tryParse(_daysCtrl.text) ??
        (widget.preset.durationDays > 0 ? widget.preset.durationDays : 30);
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
      _durationState.endDate = DateTime.now().add(
        Duration(days: _durationState.selectedDays),
      );
    });
  }

  Future<void> _onSubmit() async {
    if (!mounted || _submitting) return;
    final showTarget = widget.preset.trackingType != 'no_spend_category';
    final target = showTarget
        ? (double.tryParse(_targetCtrl.text) ??
              widget.preset.targetAmount.toDouble())
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
    final ok = await _ctrl.addChallenge(challenge);
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
      title: AppLocalizations.of(context)!.challengeStartTitle(
        widget.preset.name,
      ),
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
  late final ChallengesController _ctrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;
  late final TextEditingController _daysCtrl;
  late _DurationState _durationState;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<ChallengesController>()) {
      Get.put(ChallengesController());
    }
    _ctrl = Get.find<ChallengesController>();

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
      _durationState.endDate = DateTime.now().add(
        Duration(days: _durationState.selectedDays),
      );
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
      description: AppLocalizations.of(context)!.challengeCustomDescription,
      targetAmount: target,
      startDate: now,
      endDate: _durationState.endDate,
    );
    setState(() => _submitting = true);
    final ok = await _ctrl.addChallenge(challenge);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ChallengeSheetContent(
      title: AppLocalizations.of(context)!.challengeCustomTitle,
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

  const TabBuilder({
    super.key,
    required this.controller,
    required this.builder,
  });

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
