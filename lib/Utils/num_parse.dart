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

/// Parses a persisted numeric field into an int.
///
/// A Firestore field written by another client can come back as a `double`
/// (`(x as int?)` throws on that — it only tolerates null) or a `String`.
/// Anything unparseable reads as 0.
int safeToInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw) ?? 0;
  return 0;
}
