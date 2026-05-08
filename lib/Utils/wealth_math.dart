/// Linearly interpolates between the two bracketing entries in [milestones].
/// [age] is clamped to the table's min/max range.
double milestone(int age, Map<int, double> milestones) {
  final keys = milestones.keys.toList()..sort();
  if (age <= keys.first) return milestones[keys.first]!;
  if (age >= keys.last) return milestones[keys.last]!;
  int lo = keys.first, hi = keys.last;
  for (final k in keys) {
    if (k <= age) lo = k;
    if (k >= age && k < hi) hi = k;
  }
  if (lo == hi) return milestones[lo]!;
  final t = (age - lo) / (hi - lo);
  return milestones[lo]! + t * (milestones[hi]! - milestones[lo]!);
}

/// Compact number formatting: 1.2Cr, 5L, 10K, or raw.
String compact(double v) {
  if (v >= 10000000) return "${(v / 10000000).toStringAsFixed(1)}Cr";
  if (v >= 100000) return "${(v / 100000).toStringAsFixed(1)}L";
  if (v >= 1000) return "${(v / 1000).toStringAsFixed(0)}K";
  return v.toStringAsFixed(0);
}

// ── Age-milestone tables ────────────────────────────────────────────────
// Values are multiples of annual expense at each age bracket.
// Source: Fidelity lifecycle model adapted for India, SEBI/AMFI guidelines.
// Linear interpolation is used between brackets.

const sipM = {22: 0.0, 25: 0.5, 30: 2.0, 35: 5.0, 40: 10.0, 50: 20.0, 60: 35.0};
const stocksM = {22: 0.0, 25: 0.3, 30: 1.0, 35: 3.0, 40: 6.0, 50: 12.0, 60: 20.0};
const etfM = {22: 0.0, 25: 0.2, 30: 0.8, 35: 2.0, 40: 4.0, 50: 8.0, 60: 12.0};
const foreignM = {22: 0.0, 25: 0.0, 30: 0.5, 35: 1.0, 40: 2.0, 50: 4.0, 60: 6.0};
const startupM = {22: 0.0, 25: 0.1, 30: 0.3, 35: 0.5, 40: 0.5, 50: 0.5, 60: 0.5};
const pfM = {22: 0.5, 25: 0.8, 30: 1.5, 35: 3.0, 40: 6.0, 50: 12.0, 60: 18.0};
const ppfM = {22: 0.3, 25: 0.5, 30: 1.5, 35: 3.0, 40: 6.0, 50: 10.0, 60: 15.0};
const vpfM = {22: 0.0, 25: 0.0, 30: 0.5, 35: 1.0, 40: 2.0, 50: 4.0, 60: 7.0};
const npsM = {22: 0.0, 25: 0.0, 30: 0.5, 35: 1.5, 40: 3.0, 50: 7.0, 60: 12.0};
const bondsM = {22: 0.0, 25: 0.0, 30: 0.5, 35: 1.0, 40: 2.0, 50: 5.0, 60: 10.0};
const goldM = {22: 0.2, 25: 0.3, 30: 0.5, 35: 0.7, 40: 1.0, 50: 1.2, 60: 1.5};
const sgbM = {22: 0.0, 25: 0.1, 30: 0.3, 35: 0.5, 40: 0.7, 50: 1.0, 60: 1.2};
const cryptoM = {22: 0.0, 25: 0.1, 30: 0.2, 35: 0.2, 40: 0.2, 50: 0.1, 60: 0.0};
const reitM = {22: 0.0, 25: 0.0, 30: 0.3, 35: 0.7, 40: 1.5, 50: 3.0, 60: 4.0};
const p2pM = {22: 0.0, 25: 0.1, 30: 0.3, 35: 0.5, 40: 0.7, 50: 1.0, 60: 1.0};
const insuranceM = {22: 5.0, 25: 8.0, 30: 10.0, 35: 10.0, 40: 10.0, 50: 8.0, 60: 5.0};
