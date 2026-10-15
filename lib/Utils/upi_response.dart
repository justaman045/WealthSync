/// Result of a UPI `pay` MethodChannel call, parsed from the native
/// response query-string (`"Status=SUCCESS&txnId=…"`).
///
/// The native contract (`MainActivity.onActivityResult`) is:
/// - `RESULT_OK`            → `"Status=SUCCESS"` (may carry no txn id)
/// - `RESULT_CANCELED`      → `""`             (user backed out)
/// - anything else          → `"Status=FAILED&responseCode=…"`
///
/// This lives here (rather than inline in a screen) so the status mapping is a
/// pure function that can be unit-tested: the subscription screen previously
/// required a non-empty txn id for SUCCESS and only matched `FAILURE` (not
/// `FAILED`), so both successes and failures were reported silently.
enum UpiPaymentOutcome { success, pending, failed, cancelled }

class UpiPaymentResult {
  final UpiPaymentOutcome outcome;
  final String txnId;
  final String approvalRef;
  final String status;

  const UpiPaymentResult({
    required this.outcome,
    this.txnId = '',
    this.approvalRef = '',
    this.status = '',
  });

  bool get isSuccess => outcome == UpiPaymentOutcome.success;
  bool get isPending => outcome == UpiPaymentOutcome.pending;
  bool get isFailed => outcome == UpiPaymentOutcome.failed;
  bool get isCancelled => outcome == UpiPaymentOutcome.cancelled;
}

/// Parses the native `pay` response into a [UpiPaymentResult].
///
/// An empty/blank response means the user cancelled and must be silent, not an
/// error. `SUCCESS` is honored even when the app returned no transaction id.
UpiPaymentResult parseUpiPaymentResponse(String? response) {
  final raw = (response ?? '').trim();
  if (raw.isEmpty) {
    return const UpiPaymentResult(outcome: UpiPaymentOutcome.cancelled);
  }

  // Response is a query-string, e.g. "Status=SUCCESS&txnId=XXX&txnRef=YYY".
  final params = <String, String>{};
  for (final kv in raw.split('&')) {
    final i = kv.indexOf('=');
    if (i <= 0) continue;
    params[kv.substring(0, i).toLowerCase()] = kv.substring(i + 1);
  }

  final status = (params['status'] ?? '').toUpperCase();
  final txnId = params['txnid'] ?? params['txnref'] ?? '';
  final approvalRef = params['approvalrefno'] ?? '';

  if (status == 'SUCCESS') {
    return UpiPaymentResult(
      outcome: UpiPaymentOutcome.success,
      txnId: txnId,
      approvalRef: approvalRef,
      status: status,
    );
  }
  if (status == 'SUBMITTED') {
    return UpiPaymentResult(
      outcome: UpiPaymentOutcome.pending,
      txnId: txnId,
      approvalRef: approvalRef,
      status: status,
    );
  }
  return UpiPaymentResult(
    outcome: UpiPaymentOutcome.failed,
    txnId: txnId,
    approvalRef: approvalRef,
    status: status,
  );
}
