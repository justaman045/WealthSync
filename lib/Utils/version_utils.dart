/// Compares two dotted version strings (e.g. `"2.0.161"`).
///
/// Returns `true` only when [remote] is strictly newer than [local].
///
/// Rules:
/// - A leading `v`/`V` (as in a git tag) and any `+build` / `-suffix`
///   qualifier are ignored, so `"v2.0.161"`, `"2.0.161+161"` and
///   `"2.0.161"` are all treated as `2.0.161`.
/// - Missing components are treated as `0` (`"2.1"` == `"2.1.0"`).
/// - Unparseable components fall back to `0` rather than throwing.
///
/// This is the single source of truth for update comparisons — the update
/// checker and the background worker previously had divergent copies (one
/// stripped only `-`, the other stripped `+` and `-`).
bool isNewerVersion(String remote, String local) {
  final r = _parse(remote);
  final l = _parse(local);
  for (var i = 0; i < 3; i++) {
    if (r[i] > l[i]) return true;
    if (r[i] < l[i]) return false;
  }
  return false;
}

List<int> _parse(String version) {
  final cleaned = version.trim().split(RegExp(r'[+\-]')).first.replaceFirst(
        RegExp(r'^[vV]'),
        '',
      );
  final parts = cleaned
      .split('.')
      .map((s) => int.tryParse(s.trim()) ?? 0)
      .toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts;
}
