import 'dart:async';

/// A minimal FIFO that runs one async operation at a time.
///
/// The point is the *completion contract*: the future returned by [add]
/// completes only once **that** operation has actually run (and with its
/// error, if any). An earlier implementation of the offline write queue pushed
/// the op onto a list and returned an already-completed future when another op
/// was in flight, so `await queue.add(write)` resolved before the write reached
/// disk — and callers that then told the user "Saved locally" could lose the
/// data if the app was killed in the window.
///
/// Extracted as a pure class (no I/O, no plugins) so this contract is pinned by
/// a unit test rather than only exercised on a device.
class OpQueue {
  final List<Future<void> Function()> _pending = [];
  bool _running = false;

  /// Enqueue [op]. The returned future completes when [op] finishes: normally
  /// with `null`, or with [op]'s error if it throws.
  Future<void> add(Future<void> Function() op) {
    final completer = Completer<void>();

    Future<void> wrapped() async {
      try {
        await op();
        if (!completer.isCompleted) completer.complete();
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      }
    }

    if (_running) {
      _pending.add(wrapped);
      return completer.future;
    }
    _running = true;
    unawaited(_run(wrapped));
    return completer.future;
  }

  /// True while an op is executing or queued. Test/debug aid.
  bool get isBusy => _running || _pending.isNotEmpty;

  Future<void> _run(Future<void> Function() op) async {
    await op();
    _running = false;
    if (_pending.isNotEmpty) {
      final next = _pending.removeAt(0);
      _running = true;
      // Drain in the background. `next` carries its own completer, so awaiting
      // it here would deadlock the caller that owns a LATER op's future.
      unawaited(_run(next));
    }
  }
}
