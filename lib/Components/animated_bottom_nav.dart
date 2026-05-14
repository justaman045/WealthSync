import 'package:flutter/material.dart';
import 'package:money_control/Components/bottom_nav_bar.dart';

class AnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueNotifier<bool> isVisible;
  final Key? navBarKey;

  const AnimatedBottomNav({
    super.key,
    required this.currentIndex,
    required this.isVisible,
    this.navBarKey,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isVisible,
      builder: (context, visible, child) {
        return AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          offset: visible ? Offset.zero : const Offset(0, 1),
          child: child,
        );
      },
      child: BottomNavBar(key: navBarKey, currentIndex: currentIndex),
    );
  }
}
