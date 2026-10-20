// Generates a self-contained HTML test report from `dart test` protocol JSON
// files produced by `flutter test --file-reporter json:<path>` (unit/widget
// tests and integration tests), embedding failure screenshots as base64.
//
// Usage:
//   dart run tool/generate_test_report.dart \
//     --unit=build/report/unit.json \
//     --integration=parts/a.json,parts/b.json \
//     --screenshots=build/report/screenshots \
//     --out=build/report/report.html
//
// --integration accepts a comma-separated list of JSON reporter files (one per
// `flutter test` invocation); each file is parsed independently so test IDs
// that restart across runs never collide.
//
// All arguments are optional; missing inputs produce a report with a "no data"
// note and exit code 0 (so CI artifacts are still uploaded on red runs).

import 'dart:convert';
import 'dart:io';

class _TestResult {
  _TestResult(this.name, this.suite);
  final String name;
  final String suite;
  String status = 'pending'; // success | failure | skipped
  int timeMs = 0;
  String? error;
  String? stackTrace;
}

Future<List<_TestResult>> _parseResults(String path, {String? suiteLabel}) async {
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('WARNING: results file not found: $path');
    return [];
  }

  final tests = <int, _TestResult>{};
  var suiteCounter = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.trim().isEmpty) continue;
    Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      continue;
    }
    if (decoded is! Map) continue;
    final map = decoded;
    final type = map['type'];
    if (type == 'testStart') {
      final testObj = map['test'];
      if (testObj is! Map) continue;
      final id = testObj['id'];
      if (id is! int) continue;
      final hidden = testObj['hidden'] == true;
      if (hidden) continue;
      final name = testObj['name'];
      // Integration test JSON urls resolve to framework files (widget_tester.dart,
      // integration_test.dart) rather than the *_test.dart file that was run, so
      // the caller passes the part-file base name as the suite label.
      final suite = (suiteLabel != null && suiteLabel.isNotEmpty)
          ? suiteLabel
          : (testObj['url'] is String && (testObj['url'] as String).isNotEmpty)
              ? (testObj['url'] as String).split('/').last
              : 'suite-${suiteCounter++}';
      tests[id] = _TestResult(name is String ? name : 'test $id', suite);
    } else if (type == 'testDone') {
      final id = map['testID'];
      if (id is! int || !tests.containsKey(id)) continue;
      if (map['hidden'] == true) {
        tests.remove(id);
        continue;
      }
      final test = tests[id]!;
      final result = map['result'];
      if (result is String) {
        test.status = result == 'success'
            ? 'success'
            : result == 'skipped'
                ? 'skipped'
                : 'failure';
      }
      final time = map['time'];
      if (time is int) test.timeMs = time;
    } else if (type == 'error') {
      final id = map['testID'];
      if (id is! int || !tests.containsKey(id)) continue;
      final test = tests[id]!;
      final error = map['error'];
      final stack = map['stackTrace'];
      if (error is String && test.error == null) test.error = error;
      if (stack is String && test.stackTrace == null) test.stackTrace = stack;
    }
  }
  final list = tests.values.toList();
  list.sort((a, b) => a.suite.compareTo(b.suite));
  return list;
}

/// Total base64 budget for embedded screenshots. Screenshots are inlined into
/// the HTML so the artifact is self-contained, but base64 inflates by ~33% and
/// a full suite produces one `result_*.png` per test — embedding all of them
/// unbounded produced multi-tens-of-MB reports. Past this budget the remaining
/// screenshots are listed but not inlined.
const int _maxEmbeddedBytes = 40 * 1024 * 1024;

List<Map<String, String>> _loadScreenshots(String dirPath) {
  final dir = Directory(dirPath);
  if (!dir.existsSync()) return [];
  final out = <Map<String, String>>[];
  var embeddedBytes = 0;
  var skipped = 0;
  for (final entry in dir.listSync(followLinks: false)) {
    if (entry is! File || !entry.path.endsWith('.png')) continue;
    try {
      final bytes = entry.readAsBytesSync();
      if (bytes.isEmpty) continue;
      // base64 grows bytes by ~4/3; budget on the encoded size.
      final projected = embeddedBytes + ((bytes.length * 4) ~/ 3);
      if (projected > _maxEmbeddedBytes) {
        skipped++;
        continue;
      }
      final base64 = base64Encode(bytes);
      embeddedBytes += base64.length;
      out.add({'name': entry.uri.pathSegments.last, 'data': base64});
    } catch (_) {}
  }
  if (skipped > 0) {
    stderr.writeln(
      'Note: $skipped screenshot(s) omitted from the HTML — the '
      '${_maxEmbeddedBytes ~/ (1024 * 1024)}MB embed budget was reached. '
      'They are still present on disk.',
    );
  }
  out.sort((a, b) => a['name']!.compareTo(b['name']!));
  return out;
}

String _sanitize(String value) {
  final cleaned =
      value.replaceAll(RegExp(r'[^\w]'), '_').replaceAll(RegExp(r'_+'), '_');
  return cleaned.length > 60 ? cleaned.substring(0, 60) : cleaned;
}

String _fmtDuration(int ms) {
  if (ms <= 0) return '';
  final s = (ms / 1000).round();
  if (s < 60) return '${s}s';
  return '${s ~/ 60}m ${s % 60}s';
}

String _escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

Future<void> main(List<String> args) async {
  String argValue(String flag) {
    final prefix = '$flag=';
    for (final a in args) {
      if (a.startsWith(prefix)) return a.substring(prefix.length);
    }
    return '';
  }

  final unitPath = argValue('--unit');
  final integrationPath = argValue('--integration');
  final screenshotsDir = argValue('--screenshots');
  final outPath = argValue('--out');

  final unitResults = unitPath.isEmpty ? <_TestResult>[] : await _parseResults(unitPath);
  final integrationResults = <_TestResult>[];
  if (integrationPath.isNotEmpty) {
    for (final p in integrationPath.split(',')) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      // Part files are named <basename>.json under build/report/parts (set by
      // tool/run_integration_tests.sh). Derive the suite label from that name
      // so INTERRUPTED matching works: integration JSON urls point at framework
      // files, not the *_test.dart that actually ran.
      final base = trimmed.split('/').last;
      final label = base.endsWith('.json')
          ? '${base.substring(0, base.length - 5)}.dart'
          : '';
      integrationResults.addAll(await _parseResults(trimmed, suiteLabel: label));
    }
  }

  // Files in integration_test/ that produced no JSON reporter output (the
  // emulator died, or the suite was skipped) are rendered as INTERRUPTED rows
  // so the report reflects the full suite instead of silently dropping files.
  final expectedSuites = <String>[];
  final integrationTestDir = Directory('integration_test');
  if (integrationTestDir.existsSync()) {
    for (final entry in integrationTestDir.listSync(followLinks: false)) {
      if (entry is File && entry.path.endsWith('_test.dart')) {
        expectedSuites.add(entry.uri.pathSegments.last);
      }
    }
    expectedSuites.sort();
  }
  final presentSuites = integrationResults.map((r) => r.suite).toSet();
  final providedParts = integrationPath.isEmpty
      ? <String>[]
      : integrationPath
          .split(',')
          .map((p) => p.trim().split('/').last)
          .where((p) => p.isNotEmpty)
          .toSet();
  for (final suite in expectedSuites) {
    if (presentSuites.contains(suite)) continue;
    final reason = providedParts.contains(suite.replaceFirst('.dart', '.json'))
        ? 'The runner reported no tests for this file.'
        : 'Not executed — the emulator died or the suite was skipped.';
    integrationResults.add(_TestResult('not executed', suite)
      ..status = 'pending'
      ..error = reason);
  }
  final screenshots = screenshotsDir.isEmpty
      ? <Map<String, String>>[]
      : _loadScreenshots(screenshotsDir);

  final screenshotsByName = <String, String>{};
  for (final s in screenshots) {
    screenshotsByName[s['name']!] = s['data']!;
  }

  int count(List<_TestResult> results, String status) =>
      results.where((r) => r.status == status).length;

  final allResults = [...unitResults, ...integrationResults];
  final passed = count(allResults, 'success');
  final failed = count(allResults, 'failure');
  final skipped = count(allResults, 'skipped');
  final total = allResults.length;

  String renderRow(_TestResult test, {bool isIntegration = false}) {
    // A FAIL with no error and no stack trace is a host-side connection loss
    // (the emulator/adb died mid-test), not a Dart assertion — label it so it
    // is not mistaken for a test bug.
    final hostLost = test.status == 'failure' &&
        test.error == null &&
        test.stackTrace == null;
    final badge = switch (test.status) {
      'success' => '<span class="badge pass">PASS</span>',
      'skipped' => '<span class="badge skip">SKIP</span>',
      'pending' => '<span class="badge int">INTERRUPTED</span>',
      _ => hostLost
          ? '<span class="badge lost">HOST LOST</span>'
          : '<span class="badge fail">FAIL</span>',
    };
    final shotPrefix = test.status == 'failure' ? 'failure_' : 'result_';
    final shotName = '$shotPrefix${_sanitize(test.name)}.png';
    // Per-file fallback keyed on the part-file base name (suite URL minus its
    // `.dart` extension), e.g. failure_analytics_insights_test.png.
    final suiteBase = _sanitize(test.suite.replaceFirst(RegExp(r'\.dart$'), ''));
    var shotData = screenshotsByName[shotName];
    if (shotData == null && test.status == 'failure') {
      shotData = screenshotsByName['failure_$suiteBase.png'];
    }
    final lostHint = hostLost
        ? '<p class="empty">No error reported — the emulator/adb connection '
            'was lost, not a test assertion.</p>'
        : '';
    final errorBlock = (test.error == null && test.stackTrace == null)
        ? ''
        : '<details><summary>Error details</summary>'
            '<pre>${_escapeHtml(test.error ?? '')}\n'
            '${_escapeHtml(test.stackTrace ?? '')}</pre></details>';
    final shotBlock = shotData == null
        ? (test.status == 'failure' ? '<p class="empty">no screenshot</p>' : '')
        : '<details open><summary>'
            '${test.status == 'failure' ? 'Failure' : 'Result'} screenshot</summary>'
            '<img alt="$shotPrefix screenshot" '
            'src="data:image/png;base64,$shotData"></details>';
    return '<tr class="${test.status}">'
        '<td>$badge</td>'
        '<td class="suite">${_escapeHtml(test.suite)}</td>'
        '<td>${_escapeHtml(test.name)}</td>'
        '<td class="dur">${_fmtDuration(test.timeMs)}</td>'
        '<td>$lostHint$errorBlock$shotBlock</td>'
        '</tr>';
  }

  final buffer = StringBuffer()
    ..writeln('<!DOCTYPE html>')
    ..writeln('<html lang="en"><head><meta charset="utf-8">')
    ..writeln('<meta name="viewport" content="width=device-width, initial-scale=1">')
    ..writeln('<title>WealthSync Test Report</title>')
    ..writeln('<style>'
        'body{font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;'
        'margin:24px;color:#1f2937;background:#f9fafb}'
        'h1{font-size:22px}h2{font-size:18px;margin-top:28px}'
        '.summary{display:inline-block;padding:10px 16px;border-radius:8px;'
        'background:#fff;box-shadow:0 1px 3px rgba(0,0,0,.1)}'
        '.summary b{font-size:20px}.summary .g{color:#16a34a}'
        '.summary .r{color:#dc2626}.summary .y{color:#d97706}'
        'table{border-collapse:collapse;width:100%;background:#fff;'
        'box-shadow:0 1px 3px rgba(0,0,0,.1);border-radius:8px;overflow:hidden}'
        'th,td{padding:8px 10px;border-bottom:1px solid #e5e7eb;text-align:left;'
        'vertical-align:top}th{background:#f3f4f6;font-size:12px;text-transform:uppercase}'
        'tr.failure td{background:#fef2f2}tr.success td{background:#f0fdf4}'
        'tr.skipped td{background:#fefce8}'
        '.badge{display:inline-block;padding:2px 8px;border-radius:9999px;'
        'color:#fff;font-size:12px;font-weight:600}'
        '.badge.pass{background:#16a34a}.badge.fail{background:#dc2626}'
        '.badge.skip{background:#d97706}.badge.int{background:#7c3aed}'
        '.badge.lost{background:#7f1d1d}'
        '.suite{font-family:ui-monospace,Menlo,monospace;font-size:12px;color:#6b7280}'
        '.dur{white-space:nowrap;color:#6b7280}'
        'details{margin-top:4px}summary{cursor:pointer;font-size:13px;'
        'color:#2563eb;font-weight:500}'
        'pre{white-space:pre-wrap;background:#111827;color:#f9fafb;padding:10px;'
        'border-radius:6px;font-size:12px;max-height:320px;overflow:auto}'
        'img{max-width:100%;border-radius:6px;border:1px solid #e5e7eb;margin-top:6px}'
        '.empty{color:#6b7280;font-style:italic}'
        '</style></head><body>')
    ..writeln('<h1>WealthSync Test Report</h1>')
    ..writeln('<div class="summary">'
        '<b>$total</b> tests &mdash; '
        '<b class="g">$passed passed</b> &middot; '
        '<b class="r">$failed failed</b> &middot; '
        '<b class="y">$skipped skipped</b>'
        '</div>');

  if (integrationResults.isEmpty) {
    buffer.writeln('<p class="empty">No integration test results (missing '
        '--integration input).</p>');
  } else {
    buffer
      ..writeln('<h2>Integration Tests'
          ' (${count(integrationResults, 'success')}/'
          '${integrationResults.length} passed, '
          '${screenshots.length} screenshot(s))</h2>')
      ..writeln('<table><tr><th>Result</th><th>File</th><th>Test</th>'
          '<th>Time</th><th>Details</th></tr>');
    for (final t in integrationResults) {
      buffer.writeln(renderRow(t, isIntegration: true));
    }
    buffer.writeln('</table>');
  }

  if (unitResults.isEmpty) {
    buffer.writeln('<p class="empty">No unit/widget test results (missing '
        '--unit input).</p>');
  } else {
    buffer
      ..writeln('<h2>Unit &amp; Widget Tests'
          ' (${count(unitResults, 'success')}/${unitResults.length} passed)</h2>')
      ..writeln('<table><tr><th>Result</th><th>File</th><th>Test</th>'
          '<th>Time</th><th>Details</th></tr>');
    for (final t in unitResults) {
      buffer.writeln(renderRow(t));
    }
    buffer.writeln('</table>');
  }

  buffer
    ..writeln('<p class="empty">Generated by tool/generate_test_report.dart '
        'on ${DateTime.now().toIso8601String()}.</p>')
    ..writeln('</body></html>');

  final out = File(outPath.isEmpty ? 'build/report/report.html' : outPath);
  out.parent.createSync(recursive: true);
  await out.writeAsString(buffer.toString());
  stdout.writeln('Report written to ${out.path} '
      '(${allResults.length} tests, ${screenshots.length} screenshots)');
}
