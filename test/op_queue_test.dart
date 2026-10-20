import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_control/Utils/op_queue.dart';

void main() {
  group('OpQueue', () {
    test('runs ops one at a time, in order', () async {
      final queue = OpQueue();
      final log = <String>[];
      final gate = Completer<void>();

      // First op blocks on `gate`; the second must not start until it finishes.
      final first = queue.add(() async {
        log.add('a-start');
        await gate.future;
        log.add('a-end');
      });
      final second = queue.add(() async {
        log.add('b');
      });

      // Give the event loop a chance; only the first op should have started.
      await Future<void>.delayed(Duration.zero);
      expect(log, ['a-start']);

      gate.complete();
      await Future.wait([first, second]);
      expect(log, ['a-start', 'a-end', 'b']);
    });

    test('the returned future completes only after ITS op ran', () async {
      final queue = OpQueue();
      final gate = Completer<void>();
      var ran = false;

      // Occupy the queue so the next op is queued, not started.
      final blocker = queue.add(() => gate.future);
      final queued = queue.add(() async {
        ran = true;
      });

      // The queued op's future must NOT be complete yet — this is the exact
      // regression: the old queue resolved it immediately while still pending.
      var queuedDone = false;
      unawaited(queued.then((_) => queuedDone = true));
      await Future<void>.delayed(Duration.zero);
      expect(ran, isFalse);
      expect(queuedDone, isFalse);

      gate.complete();
      await blocker;
      await queued;
      expect(ran, isTrue);
      expect(queuedDone, isTrue);
    });

    test('propagates the op error to its own future only', () async {
      final queue = OpQueue();
      final failing = queue.add(() async => throw StateError('boom'));
      await expectLater(failing, throwsStateError);
      // Queue still usable afterwards.
      var ok = false;
      await queue.add(() async => ok = true);
      expect(ok, isTrue);
    });

    test('isBusy reflects running and queued work', () async {
      final queue = OpQueue();
      expect(queue.isBusy, isFalse);
      final gate = Completer<void>();
      final a = queue.add(() => gate.future);
      expect(queue.isBusy, isTrue);
      gate.complete();
      await a;
      await Future<void>.delayed(Duration.zero);
      expect(queue.isBusy, isFalse);
    });
  });
}
