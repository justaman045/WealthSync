import 'package:flutter/material.dart';

class HoverEffect extends StatefulWidget {
  final Widget child;
  final double scale;
  final double elevation;
  final Duration duration;

  const HoverEffect({
    super.key,
    required this.child,
    this.scale = 1.03,
    this.elevation = 4.0,
    this.duration = const Duration(milliseconds: 180),
  });

  @override
  State<HoverEffect> createState() => _HoverEffectState();
}

class _HoverEffectState extends State<HoverEffect> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovering ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: widget.duration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: widget.elevation * 3,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
