import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Phone silhouette with a sweeping scan-line. Drives off an external
/// AnimationController so the screen can pause it when backgrounded.
class ScanVisual extends StatelessWidget {
  final Animation<double> sweep; // 0..1 looping
  final bool active;
  final double size;

  const ScanVisual({
    super.key,
    required this.sweep,
    this.active = true,
    this.size = 220,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size * 1.7,
        child: AnimatedBuilder(
          animation: sweep,
          builder: (context, _) => CustomPaint(
            painter: _PhoneScanPainter(active ? sweep.value : -1),
          ),
        ),
      ),
    );
  }
}

class _PhoneScanPainter extends CustomPainter {
  final double t; // 0..1 sweep position; -1 = idle
  _PhoneScanPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.12, h * 0.02, w * 0.76, h * 0.96),
      Radius.circular(w * 0.12),
    );

    // Phone body
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.accent.withValues(alpha: 0.55),
    );
    canvas.drawRRect(
      bodyRect,
      Paint()..color = AppColors.accent.withValues(alpha: 0.04),
    );

    // Inner screen
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.18, h * 0.08, w * 0.64, h * 0.84),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(
      screenRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    // Camera notch
    canvas.drawCircle(Offset(w * 0.5, h * 0.05), w * 0.018,
        Paint()..color = AppColors.accent.withValues(alpha: 0.5));

    if (t < 0) return;

    // Scan line + glow band
    final y = h * 0.06 + (h * 0.88) * t;
    canvas.save();
    canvas.clipRRect(bodyRect);

    final band = Rect.fromLTWH(0, y - 30, w, 60);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.accent.withValues(alpha: 0.0),
            AppColors.accent.withValues(alpha: 0.22),
            AppColors.accent.withValues(alpha: 0.0),
          ],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(w * 0.14, y),
      Offset(w * 0.86, y),
      Paint()
        ..strokeWidth = 2
        ..color = AppColors.accent,
    );

    // Sparkle ticks along the line
    final rnd = math.Random((t * 50).floor());
    for (int i = 0; i < 6; i++) {
      final x = w * 0.18 + rnd.nextDouble() * w * 0.64;
      canvas.drawCircle(Offset(x, y), 1.6, Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PhoneScanPainter old) => old.t != t;
}
