import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Central motion controls. Honours the platform "reduce motion" setting plus
/// an in-app override so every animated surface can degrade to a static state.
class Motion {
  Motion._();

  /// In-app toggle. When true, all signature animations collapse to their end
  /// state and haptics are suppressed.
  static final ValueNotifier<bool> reduceMotion = ValueNotifier<bool>(false);

  /// True when either the OS or the user has asked to reduce motion.
  static bool isReduced(BuildContext context) {
    return reduceMotion.value || MediaQuery.maybeDisableAnimationsOf(context) == true;
  }

  static Future<void> tick(BuildContext context) async {
    if (isReduced(context)) return;
    await HapticFeedback.selectionClick();
  }

  static Future<void> success(BuildContext context) async {
    if (isReduced(context)) return;
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavy(BuildContext context) async {
    if (isReduced(context)) return;
    await HapticFeedback.heavyImpact();
  }
}

/// A small press-scale wrapper for tactile buttons / tappable cards.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const PressScale({super.key, required this.child, this.onTap, this.scale = 0.97});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.isReduced(context);
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: () {
        Motion.tick(context);
        widget.onTap?.call();
      },
      child: AnimatedScale(
        scale: (_down && !reduced) ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
