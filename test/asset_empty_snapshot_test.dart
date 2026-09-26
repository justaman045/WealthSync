import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/wealth_service.dart';

// ignore: subtype_of_sealed_class
class _FakeDoc implements QueryDocumentSnapshot<Object?> {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMeta implements SnapshotMetadata {
  _FakeMeta(this.isFromCache);

  @override
  final bool isFromCache;

  @override
  bool get hasPendingWrites => false;
}

class _FakeQuerySnapshot implements QuerySnapshot<Object?> {
  _FakeQuerySnapshot({required this.isFromCache, this.docCount = 0});

  final bool isFromCache;
  final int docCount;

  @override
  SnapshotMetadata get metadata => _FakeMeta(isFromCache);

  @override
  List<QueryDocumentSnapshot<Object?>> get docs =>
      List<QueryDocumentSnapshot<Object?>>.generate(docCount, (_) => _FakeDoc());

  @override
  int get size => docCount;

  @override
  List<DocumentChange<Object?>> get docChanges => const <DocumentChange<Object?>>[];
}

void main() {
  group('WealthService.isServerConfirmedEmpty', () {
    test('a cached empty snapshot must never sync a zero total', () {
      expect(
        WealthService.isServerConfirmedEmpty(_FakeQuerySnapshot(isFromCache: true)),
        isFalse,
      );
    });

    test('a server-confirmed empty snapshot does sync', () {
      expect(
        WealthService.isServerConfirmedEmpty(_FakeQuerySnapshot(isFromCache: false)),
        isTrue,
      );
    });

    test('a cached snapshot holding docs is not an empty sync', () {
      expect(
        WealthService.isServerConfirmedEmpty(
          _FakeQuerySnapshot(isFromCache: true, docCount: 3),
        ),
        isFalse,
      );
    });

    test('a server snapshot holding docs is not an empty sync', () {
      expect(
        WealthService.isServerConfirmedEmpty(
          _FakeQuerySnapshot(isFromCache: false, docCount: 1),
        ),
        isFalse,
      );
    });
  });
}
