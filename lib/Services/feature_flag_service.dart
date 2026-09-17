import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:money_control/Config/feature_flags.dart';
import 'package:money_control/Controllers/subscription_controller.dart';

/// Reads the global `app_config/feature_flags` doc and surfaces each feature's
/// status reactively. Defaults to [FeatureStatus.enabled] whenever the doc,
/// key or value is missing so a stale or corrupt config never locks users out.
///
/// Mirrors PaymentConfigService: snapshots on native, a 60s poll on web (the
/// Firestore JS SDK WatchChangeAggregator ca9/b815 bug forbids a transient
/// .get() before persistent .snapshots() listeners exist).
class FeatureFlagService extends GetxController {
  static FeatureFlagService get to => Get.find();

  static const String _docId = 'feature_flags';

  final RxMap<String, String> _status = <String, String>{}.obs;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  Timer? _webPollTimer;

  /// Test/adapter hook; when non-null it wins over the real admin check, so
  /// widget tests can exercise the admin UI without Firebase.
  @visibleForTesting
  bool? adminOverride;

  /// True when the signed-in user is an admin (never self-grantable — rules
  /// gate `users/{email}.isAdmin` writes). Fails open to false when the
  /// controller isn't registered (e.g. in tests).
  bool get userIsAdmin =>
      adminOverride ??
      (Get.isRegistered<SubscriptionController>() &&
          SubscriptionController.to.isAdmin.value);

  /// Current override map, for tests and optimistic local updates.
  @visibleForTesting
  Map<String, String> get rawStatuses => Map.unmodifiable(_status);

  /// Live status map. Intent is mutable state that still drives workers and
  /// Obx/ever listeners outside of GetBuilder subtrees.
  RxMap<String, String> get statusMap => _status;

  @override
  void onInit() {
    super.onInit();
    if (!kIsWeb) startRealtime();
    // On web, Firestore is NOT accessed during Phase 1 to avoid triggering
    // the JS SDK WatchChangeAggregator ca9/b815 assertion bug.
    // Call startPolling() after login instead.
  }

  /// Opens the Firestore snapshot stream (native). Split out so tests can
  /// subclass the service without ever touching Firebase.
  @protected
  void startRealtime() {
    _sub = FirebaseFirestore.instance
        .collection('app_config')
        .doc(_docId)
        .snapshots(includeMetadataChanges: true)
        .listen(_applySnapshot, onError: (e) {
      debugPrint('FeatureFlagService: using defaults ($e)');
    });
  }

  /// Start periodic polling for feature flags. Called after login on web.
  void startPolling() {
    if (!kIsWeb) return;
    _fetchOnce();
    _webPollTimer?.cancel();
    _webPollTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _fetchOnce(),
    );
  }

  Future<void> _fetchOnce() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_config')
          .doc(_docId)
          .get();
      _applySnapshot(snap);
    } catch (e) {
      debugPrint('FeatureFlagService: using defaults ($e)');
    }
  }

  void _applySnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    _applyData(snap.exists ? snap.data() : null);
  }

  /// Applies a raw Firestore document to the status map. A missing document
  /// resets everything to defaults; invalid values are dropped per key.
  @visibleForTesting
  void applyRaw(Map<String, dynamic>? data) => _applyData(data);

  void _applyData(Map<String, dynamic>? data) {
    final next = <String, String>{};
    data?.forEach((key, value) {
      final status = value?.toString() ?? '';
      if (_isValidStatus(status)) next[key] = status;
    });
    // Skip when nothing changed: metadata-only snapshot flips
    // (includeMetadataChanges: true) and identical 60s web polls otherwise
    // rewrite bg_feature_flags prefs and rebuild every GetBuilder subscriber.
    if (mapEquals(next, _status)) return;
    _status.value = next;
    // One-line diag so an admin reporting "feature still visible" can see what
    // the service actually has without guessing (map is sorted for stable log).
    final entries = next.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    debugPrint('FeatureFlagService: flags=${entries.map((e) => '${e.key}:${e.value}').join(', ')}');
    // Notify GetBuilder listeners (screens that rebuild whole subtrees). The
    // RxMap stream keeps Obx/GetX call sites reactive; update() keeps
    // GetBuilder call sites in sync.
    update();
  }

  static bool _isValidStatus(String status) =>
      status == FeatureStatus.enabled ||
      status == FeatureStatus.comingSoon ||
      status == FeatureStatus.hidden;

  @override
  void onClose() {
    _sub?.cancel();
    _webPollTimer?.cancel();
    super.onClose();
  }

  String statusOf(String key) => _status[key] ?? FeatureStatus.enabled;

  bool isEnabled(String key) => statusOf(key) == FeatureStatus.enabled;
  bool isComingSoon(String key) => statusOf(key) == FeatureStatus.comingSoon;
  bool isHidden(String key) => statusOf(key) == FeatureStatus.hidden;

  /// Pure visibility rule: Hidden is gone for everyone; Coming Soon shows to
  /// admins only (customers see the placeholder). Anything else is visible.
  static bool visibleFor({required String status, required bool isAdmin}) {
    switch (status) {
      case FeatureStatus.hidden:
        return false;
      case FeatureStatus.comingSoon:
        return isAdmin;
      default:
        return true;
    }
  }

  /// Whether the signed-in user may use the feature right now.
  bool visibleToMe(String key) =>
      visibleFor(status: statusOf(key), isAdmin: userIsAdmin);

  /// Admin write: set one feature's status on the global doc. Rules gate this
  /// to admins server-side; the in-app admin screen requires isAdmin too.
  Future<void> setStatus(String key, String status) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !_isValidStatus(status)) {
      debugPrint('FeatureFlagService: cannot save, not authenticated or invalid');
      return;
    }
    await FirebaseFirestore.instance
        .collection('app_config')
        .doc(_docId)
        .set({key: status}, SetOptions(merge: true));
    // Reflect optimistically so the admin UI updates without waiting for the
    // snapshot round trip (idempotent — the stream applies the same value).
    _applyData({..._status, key: status});
  }
}