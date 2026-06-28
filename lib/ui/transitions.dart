import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// Shared page transitions. Falls back to an instant route when motion is
/// reduced so navigation never blocks reading.
Route<T> sharedAxisRoute<T>(BuildContext context, Widget page,
    {SharedAxisTransitionType type = SharedAxisTransitionType.horizontal}) {
  final reduced = Motion.isReduced(context);
  return PageRouteBuilder<T>(
    transitionDuration: Duration(milliseconds: reduced ? 0 : 420),
    reverseTransitionDuration: Duration(milliseconds: reduced ? 0 : 420),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, secondary, child) {
      if (reduced) return child;
      return SharedAxisTransition(
        animation: anim,
        secondaryAnimation: secondary,
        transitionType: type,
        child: child,
      );
    },
  );
}

Route<T> fadeThroughRoute<T>(BuildContext context, Widget page) {
  final reduced = Motion.isReduced(context);
  return PageRouteBuilder<T>(
    transitionDuration: Duration(milliseconds: reduced ? 0 : 420),
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, secondary, child) {
      if (reduced) return child;
      return FadeThroughTransition(
        animation: anim,
        secondaryAnimation: secondary,
        child: child,
      );
    },
  );
}
