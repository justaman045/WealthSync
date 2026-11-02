/// Pure rules for the admin `app_config/payment_settings` document.
///
/// The admin screen keeps a local copy of the form while the service keeps a
/// live snapshot (another admin on another device can flip the mode at any
/// time). Keeping the payload and the dirty-check pure means both are testable
/// without Firebase, and the service and the screen cannot drift apart about
/// what a save writes or when a save is a no-op.
library;

const paymentModes = <String>['google_play', 'upi'];

/// Normalizes a mode read from Firestore. An unknown or missing value falls
/// back to Play Billing, which is the same default the service applies.
String normalizePaymentMode(Object? raw) {
  final value = raw?.toString() ?? '';
  return paymentModes.contains(value) ? value : 'google_play';
}

/// UPI ids are compared and stored trimmed: a trailing space otherwise made the
/// form permanently "dirty" against an identical saved value.
String normalizeUpiId(Object? raw) => (raw?.toString() ?? '').trim();

/// True when the form differs from what is currently saved.
bool paymentConfigIsDirty({
  required String mode,
  required String upi,
  required String savedMode,
  required String savedUpi,
}) {
  return normalizePaymentMode(mode) != normalizePaymentMode(savedMode) ||
      normalizeUpiId(upi) != normalizeUpiId(savedUpi);
}

/// The document a save writes.
///
/// `updatedAt`/`updatedBy` exist so a support question ("who switched us to
/// UPI?") has an answer; they are merge-written next to the two config keys so
/// a concurrent write to an unrelated key is not clobbered.
Map<String, Object?> paymentConfigPayload({
  required String mode,
  required String upi,
  required String updatedBy,
  required Object updatedAt,
}) {
  return <String, Object?>{
    'paymentMode': normalizePaymentMode(mode),
    'upiId': normalizeUpiId(upi),
    'updatedAt': updatedAt,
    'updatedBy': updatedBy,
  };
}
