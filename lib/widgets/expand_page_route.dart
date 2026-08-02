import 'dart:ui';

import 'package:flutter/material.dart';

class ExpandPageRoute<T> extends PageRouteBuilder<T> {
  ExpandPageRoute({
    required this.rect,
    required this.page,
    super.settings,
    Duration duration = const Duration(milliseconds: 400),
  }) : super(
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          opaque: false,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return _ExpandTransition(
              animation: animation,
              rect: rect,
              child: child,
            );
          },
        );

  final Rect rect;
  final Widget page;
}

class _ExpandTransition extends StatelessWidget {
  const _ExpandTransition({
    required this.animation,
    required this.rect,
    required this.child,
  });

  final Animation<double> animation;
  final Rect rect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) {
        final screen = MediaQuery.sizeOf(context);
        final t = curved.value;

        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.55 * t),
            ),
            Positioned(
              left: lerpDouble(rect.left, 0, t)!,
              top: lerpDouble(rect.top, 0, t)!,
              width: lerpDouble(rect.width, screen.width, t)!,
              height: lerpDouble(rect.height, screen.height, t)!,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(lerpDouble(16, 0, t)!),
                child: child,
              ),
            ),
          ],
        );
      },
      child: child,
    );
  }
}
