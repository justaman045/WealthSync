/// Parses a persisted numeric field into a finite double.
///
/// `double.tryParse` accepts "NaN" and "Infinity", and Firestore stores
/// whatever the client wrote. A single poisoned row therefore propagates
/// through every total that sums it, and `NaN` is a widget-level error rather
/// than a merely wrong number. Anything non-finite or unparseable reads as 0.
double safeToDouble(Object? raw) {
  final double parsed;
  if (raw is num) {
    parsed = raw.toDouble();
  } else if (raw is String) {
    parsed = double.tryParse(raw) ?? 0.0;
  } else {
    return 0.0;
  }
  return parsed.isFinite ? parsed : 0.0;
}

/// True when [value] is a usable, strictly positive, finite amount.
bool isValidAmount(num? value) =>
    value != null && value.isFinite && value > 0;
