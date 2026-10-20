import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:money_control/Components/coming_soon_widget.dart';
import 'package:money_control/Services/app_analytics.dart';
import 'package:money_control/Services/feature_flag_service.dart';

/// Records that a real user reached a feature an admin has switched off.
///
/// This is the demand signal for what to build next, and the only way to know
/// which of the feature flags are dead weight. Deliberately logged from the
/// *tap* guards rather than from `visibleToMe`, which also runs during
/// `build()` and would log a hit on every frame a gated surface renders.
void _trackGateHit(FeatureFlagService service, String flagKey) {
  AppAnalytics.log(AnalyticsEvent.featureGateHit, {
    'feature': flagKey,
    'status': service.statusOf(flagKey),
    'is_admin': service.userIsAdmin,
  });
}

/// Entry-point guard: call instead of `gotoPage(...)`.
///
/// Returns true when the feature is visible to the current user (so the caller
/// proceeds with the real navigation); otherwise pushes the ComingSoon
/// placeholder and returns false.
bool ensureFeatureVisible(BuildContext context, String flagKey) {
  final service = FeatureFlagService.to;
  if (service.visibleToMe(flagKey)) return true;
  _trackGateHit(service, flagKey);
  Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
    builder: (_) => ComingSoonScreen.forFlag(flagKey),
  ));
  return false;
}

/// Like [ensureFeatureVisible] but treats `hidden` as a hard no-op (no
/// ComingSoon placeholder) — for always-visible surfaces whose tap is gated
/// (e.g. the home greeting, which stays on screen when profile is hidden).
bool ensureFeatureUsable(BuildContext context, String flagKey) {
  if (FeatureFlagService.to.isHidden(flagKey)) {
    _trackGateHit(FeatureFlagService.to, flagKey);
    return false;
  }
  return ensureFeatureVisible(context, flagKey);
}

/// Reactive visibility gate for a feature BODY.
///
/// Replaces [child] with a ComingSoon placeholder when an admin has flipped the
/// feature to `comingSoon` (or `hidden`) for the current user; admins always
/// see the real content so they can develop and test a not-yet-launched
/// feature. Rebuilds whenever the admin changes the status, because it listens
/// to [FeatureFlagService] (GetBuilder + the service's update() broadcast).
class FeatureGate extends StatelessWidget {
  final String flagKey;
  final Widget child;

  const FeatureGate({super.key, required this.flagKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FeatureFlagService>(
      builder: (_) {
        final service = FeatureFlagService.to;
        return service.visibleToMe(flagKey)
            ? child
            : ComingSoonScreen.forFlag(flagKey);
      },
    );
  }
}

/// Reactive entry-surface visibility: renders [child] unless an admin has set
/// the feature to `hidden` (then the surface disappears entirely — "as if
/// never there" — for everyone, including admins). `comingSoon` / `enabled`
/// keep [child] visible; the tap-time [ensureFeatureVisible] guard still
/// handles the ComingSoon placeholder for non-admin customers.
class FeatureVisible extends StatelessWidget {
  final String flagKey;
  final Widget child;

  const FeatureVisible({super.key, required this.flagKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FeatureFlagService>(
      builder: (_) =>
          FeatureFlagService.to.isHidden(flagKey) ? const SizedBox.shrink() : child,
    );
  }
}

/// Reactive visibility for a SECTION of settings tiles: renders [child] (a
/// header + its tiles + trailing divider) unless EVERY [flagKeys] entry is
/// `hidden` — so a settings heading never dangles over an empty group. Matches
/// [FeatureVisible] granularity: `comingSoon` / `enabled` keep the section.
class FeatureSection extends StatelessWidget {
  final List<String> flagKeys;
  final Widget child;

  const FeatureSection({super.key, required this.flagKeys, required this.child});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FeatureFlagService>(
      builder: (_) {
        final service = FeatureFlagService.to;
        return flagKeys.every(service.isHidden)
            ? const SizedBox.shrink()
            : child;
      },
    );
  }
}

/// Sliver-safe variant of [FeatureVisible] for use inside a `CustomScrollView`
/// (e.g. Wealth Builder). A plain [FeatureVisible] returns a box
/// (`SizedBox.shrink`) which crashes a sliver slot; this always resolves to a
/// valid sliver — [SliverToBoxAdapter] with an empty box when `hidden`,
/// otherwise the wrapped [sliver]. Same semantics: `hidden` removes the sliver
/// for everyone including admins; `comingSoon` / `enabled` keep it.
class SliverFeatureVisible extends StatelessWidget {
  final String flagKey;
  final Widget sliver;

  const SliverFeatureVisible({
    super.key,
    required this.flagKey,
    required this.sliver,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<FeatureFlagService>(
      builder: (_) => FeatureFlagService.to.isHidden(flagKey)
          ? const SliverToBoxAdapter(child: SizedBox.shrink())
          : sliver,
    );
  }
}