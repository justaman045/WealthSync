import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Firestore composite-index coverage.
///
/// Firestore silently fails a multi-field query at runtime (not at compile
/// time, and not in `flutter test`) when its composite index is missing, so the
/// only reliable guard is asserting the contract here. This is deliberately a
/// contract test over the four known query shapes rather than a regex parse of
/// arbitrary Dart: when a query changes, the source-text assertion fails and the
/// index has to be updated deliberately.
///
/// Add an index when adding a multi-field query:
///   firebase deploy --only firestore:indexes   (see AGENTS.md)
class IndexEntry {
  final String collectionGroup;
  final List<String> fields;

  const IndexEntry(this.collectionGroup, this.fields);

  @override
  bool operator ==(Object other) =>
      other is IndexEntry &&
      other.collectionGroup == collectionGroup &&
      other.fields.length == fields.length &&
      List.generate(fields.length, (i) => other.fields[i] == fields[i]).every((b) => b);

  @override
  int get hashCode => Object.hash(collectionGroup, fields.join('|'));
}

/// The queries in `lib/` that need a composite index, in the order Firestore
/// requires (equality fields first, then the range/orderBy field).
const List<IndexEntry> requiredIndexes = [
  IndexEntry('challenges', ['isActive ASC', 'createdAt DESC']),
  IndexEntry('loans', ['isActive ASC', 'createdAt DESC']),
  // Category history: equality on category, ordered by date.
  IndexEntry('transactions', ['category ASC', 'date DESC']),
  // Budget month range: equality on category, range on date. Firestore allows
  // only one range field per query, so both `date` bounds share this index.
  IndexEntry('transactions', ['category ASC', 'date ASC']),
];

/// Where each required query lives, so a query edit breaks this test instead of
/// production.
// Not const: IndexEntry overrides hashCode, which cannot be const-evaluated.
final Map<IndexEntry, String> querySources = {
  IndexEntry('challenges', ['isActive ASC', 'createdAt DESC']):
      'lib/Repositories/challenge_repository.dart',
  IndexEntry('loans', ['isActive ASC', 'createdAt DESC']):
      'lib/Repositories/loan_repository.dart',
  IndexEntry('transactions', ['category ASC', 'date DESC']):
      'lib/Screens/cateogary_history.dart',
  IndexEntry('transactions', ['category ASC', 'date ASC']):
      'lib/Services/budget_service.dart',
};

void main() {
  late Map<String, dynamic> config;
  late List<IndexEntry> declared;
  late String allLibSource;

  setUpAll(() {
    allLibSource = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.readAsStringSync())
        .join('\n');
    final indexFile = jsonDecode(
      File('firestore.indexes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    declared = (indexFile['indexes'] as List<dynamic>).map((raw) {
      final entry = raw as Map<String, dynamic>;
      final fields = (entry['fields'] as List<dynamic>).map((f) {
        final field = f as Map<String, dynamic>;
        final order = field['order'] == 'DESCENDING' ? 'DESC' : 'ASC';
        return '${field['fieldPath']} $order';
      }).toList();
      return IndexEntry(entry['collectionGroup'] as String, fields);
    }).toList();
    config = jsonDecode(File('firebase.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  group('firestore index coverage', () {
    test('every multi-field query has a declared index', () {
      final missing = requiredIndexes
          .where((needed) => !declared.contains(needed))
          .toList();
      expect(
        missing,
        isEmpty,
        reason:
            'missing composite index(s) in firestore.indexes.json. Firestore will '
            'fail these queries at runtime: $missing',
      );
    });

    test('no declared index is redundant', () {
      final stale = declared
          .where((entry) => !requiredIndexes.contains(entry))
          .toList();
      expect(
        stale,
        isEmpty,
        reason:
            'firestore.indexes.json declares indexes no query needs. Remove them, '
            'or add the query to requiredIndexes: $stale',
      );
    });

    test('every index targets a collection that is actually queried', () {
      // Firestore accepts a typo'd collectionGroup and then never uses the
      // index, so that mistake would only ever surface as a runtime query
      // failure in production.
      for (final entry in declared) {
        expect(
          RegExp("collection\\('${entry.collectionGroup}'\\)").hasMatch(
            allLibSource,
          ),
          isTrue,
          reason:
              'firestore.indexes.json declares "${entry.collectionGroup}" but no '
              'query in lib/ reads that subcollection',
        );
      }
    });

    test('indexes are scoped to a single collection, not a group', () {
      // Every query here is a single-collection query; COLLECTION_GROUP would
      // be a wider (and per-query-costlier) index that we do not need.
      for (final raw in (jsonDecode(
            File('firestore.indexes.json').readAsStringSync(),
          ) as Map<String, dynamic>)['indexes'] as List<dynamic>) {
        final entry = raw as Map<String, dynamic>;
        expect(
          entry['queryScope'],
          'COLLECTION',
          reason:
              '${entry['collectionGroup']} index must be COLLECTION-scoped; the '
              'queries are single-collection',
        );
      }
    });

    test('each required query still exists in its source file', () {
      querySources.forEach((index, path) {
        expect(
          requiredIndexes.contains(index),
          isTrue,
          reason: '$path is listed for a query shape that is no longer required',
        );
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path moved or was deleted — update requiredIndexes',
        );
      });
    });

    test('the queries still filter on the fields the indexes are built for', () {
      // A query edited without the index being updated fails the tests above
      // only if the shape is listed; these keep the source honest.
      expect(
        File('lib/Repositories/challenge_repository.dart')
            .readAsStringSync()
            .contains(".where('isActive', isEqualTo: true)"),
        isTrue,
      );
      expect(
        File('lib/Repositories/loan_repository.dart')
            .readAsStringSync()
            .contains(".where('isActive', isEqualTo: true)"),
        isTrue,
      );
      expect(
        File('lib/Screens/cateogary_history.dart')
            .readAsStringSync()
            .contains(".where('category', isEqualTo: widget.categoryName)"),
        isTrue,
      );
      expect(
        File('lib/Services/budget_service.dart')
            .readAsStringSync()
            .contains(".where('category', isEqualTo: category)"),
        isTrue,
      );
    });
  });

  group('firebase deploy config', () {
    test('firestore.json points at the rules and the index file', () {
      final firestore = config['firestore'] as Map<String, dynamic>;
      expect(firestore['rules'], 'firestore.rules');
      expect(firestore['indexes'], 'firestore.indexes.json');
    });

    test('both deployed files exist', () {
      expect(File('firestore.rules').existsSync(), isTrue);
      expect(File('firestore.indexes.json').existsSync(), isTrue);
    });
  });
}
