import 'package:flutter/material.dart';

/// Horizontal enter animation for a tab page that the shell keeps alive.
///
/// The previous implementation built an [AnimatedSlide] with the offset derived
/// from the *current* activation state. A page materialized for the first time
/// while active was therefore born at `offset: Offset.zero`: there was no
/// transition to animate, so a tab's first visit never slid in (only a return
/// visit did). This widget animates on every activation, first or repeat.
///
/// The parent owns lifecycle (kept-alive list, `Offstage`, pointer/semantics
/// guards); this widget only owns the slide. [duration] is supplied by the
/// caller so lite mode can disable the animation without this widget depending
/// on GetX.
class KeptPageTransition extends StatefulWidget {
  const KeptPageTransition({
    super.key,
    required this.active,
    required this.index,
    required this.activeIndex,
    required this.duration,
    this.initialDirection = 1,
    required this.child,
  });

  /// Whether this page is the visible tab.
  final bool active;

  /// Position of this page in the shell's kept-page list.
  final int index;

  /// Position of the page that is currently visible.
  final int activeIndex;

  /// Zero disables the animation (lite mode, or the very first app frame).
  final Duration duration;

  /// Direction used when this page is born already active: `1` enters from the
  /// right, `-1` from the left. Repeat activations derive it from the previous
  /// [activeIndex] instead.
  final double initialDirection;

  final Widget child;

  @override
  State<KeptPageTransition> createState() => _KeptPageTransitionState();
}

class _KeptPageTransitionState extends State<KeptPageTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Where the page starts from for the animation currently in flight.
  late double _begin = widget.initialDirection;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    if (!widget.active) {
      // Hidden pages sit at rest; activation starts the animation.
      _controller.value = 1;
    } else if (widget.duration == Duration.zero) {
      _controller.value = 1;
    } else {
      // Born active (a first visit). Play in after the first frame, otherwise
      // the very first build paints the page already in place.
      _controller.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward(from: 0);
      });
    }
  }

  @override
  void didUpdateWidget(covariant KeptPageTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (!oldWidget.active && widget.active) {
      // oldWidget.activeIndex is the tab we are coming from, so it is the only
      // correct source for the direction.
      _begin = widget.index < oldWidget.activeIndex ? -1 : 1;
      if (widget.duration == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    } else if (oldWidget.active && !widget.active) {
      // Offstage immediately; park at rest so the next activation starts from
      // the edge rather than from wherever this animation stopped.
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(_begin, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      ),
      child: widget.child,
    );
  }
}
