import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Spark-plan guardrails.
///
/// WealthSync runs on Firebase's free (Spark) plan, which has no Cloud
/// Functions, no Cloud Storage bucket, and a daily read quota. A single
/// `getTransactionsStream()` added to a screen opens a second listener over the
/// whole collection and can exhaust that quota on its own. These are source
/// contracts, not behaviour tests: they fail the build when a forbidden import
/// or call is added, before it reaches a device.
void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  test('lib/ contains only files the scan can read', () {
    expect(libFiles, isNotEmpty);
  });

  test('no Cloud Functions or Cloud Storage usage (Spark plan)', () {
    // Storage cannot even be provisioned on Spark, and a Functions dependency
    // would fail at deploy time rather than at runtime.
    const forbidden = [
      'package:cloud_functions/',
      'package:firebase_storage/',
      'FirebaseFunctions',
      'httpsCallable(',
      'uploadBytes(',
      'getDownloadURL(',
    ];

    final offenders = <String>[];
    for (final file in libFiles) {
      final source = file.readAsStringSync();
      for (final token in forbidden) {
        if (source.contains(token)) {
          offenders.add('${file.path}: $token');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('no screen opens its own transaction listener', () {
    // TransactionController owns the single live listener. A screen that calls
    // the repository stream directly doubles the read cost and stalls the UI
    // until a second snapshot arrives.
    final screens = libFiles.where(
      (file) => file.path.startsWith('lib/Screens/'),
    );
    final offenders = <String>[];
    for (final file in screens) {
      if (file.readAsStringSync().contains('getTransactionsStream(')) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('Firestore offline persistence stays on', () {
    // The local cache is what keeps the app usable inside the free plan's read
    // budget: cached snapshots are not billed as server reads.
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('persistenceEnabled: true'));
  });
}
