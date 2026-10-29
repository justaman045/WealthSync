import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Services/user_service.dart';

void main() {
  group('isDeletionMarkerFor', () {
    test('matches the uid that wrote it', () {
      expect(UserService.isDeletionMarkerFor({'uid': 'u1'}, 'u1'), isTrue);
    });

    test('a marker from a previous account with the same email is stale', () {
      expect(UserService.isDeletionMarkerFor({'uid': 'u0'}, 'u1'), isFalse);
    });

    test('a malformed marker is never trusted', () {
      expect(UserService.isDeletionMarkerFor(null, 'u1'), isFalse);
      expect(UserService.isDeletionMarkerFor(const {}, 'u1'), isFalse);
      expect(UserService.isDeletionMarkerFor({'uid': null}, 'u1'), isFalse);
    });
  });

  group('deleteAccount ordering', () {
    test('the marker is written after the wipe and before the profile delete', () {
      final src = File('lib/Services/user_service.dart').readAsStringSync();
      // Find the marker written after wipe (line ~156)
      final markers = RegExp(r'_writeDeletionMarker\(email, user\.uid\)').allMatches(src).toList();
      expect(markers.length, greaterThanOrEqualTo(2));
      final marker = markers[1].start;
      final subCollectionLoop = src.indexOf('for (final sub in subcollections)');
      final profileDelete = src.indexOf(
        "collection('users').doc(email).delete()",
      );
      expect(subCollectionLoop, greaterThan(-1));
      expect(marker, greaterThan(subCollectionLoop));
      expect(marker, lessThan(profileDelete));
    });
  });
}
