import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/models/report.dart';
import 'motion.dart';
import 'theme.dart';

/// Radial Trust Score gauge that counts up from 0 and colour-tweens to the
/// verdict. Honours reduced motion (jumps straight to the final value).
class TrustGauge extends StatelessWidget {
  final int score;
  final Verdict verdict;
  final double size;

  const TrustGauge({
    super.key,
    required this.score,
    required this.verdict,
    this.size = 240,
  });

  Color get _verdictColor {
    switch (verdict) {
      case Verdict.genuine:
        return AppColors.good;
      case Verdict.caution:
        return AppColors.caution;
      case Verdict.highRisk:
        return AppColors.risk;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.isReduced(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduced ? score.toDouble() : 0, end: score.toDouble()),
      duration: Duration(milliseconds: reduced ? 0 : 1600),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final c = Color.lerp(AppColors.unknown, _verdictColor, (value / 100).clamp(0, 1))!;
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _GaugePainter(value / 100, c),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.round().toString(),
                    style: TextStyle(
                      fontSize: size * 0.34,
                      fontWeight: FontWeight.w300,
                      height: 1,
                      color: c,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('TRUST SCORE',
                      style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 3,
                          color: AppColors.textDim,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress; // 0..1
  final Color color;
  _GaugePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 14;
    const startAngle = math.pi * 0.75;
    const sweep = math.pi * 1.5;

    // Soft verdict-tinted glow behind the dial — makes the score read as a hero.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.28 * (0.4 + 0.6 * progress)),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.05))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(center, radius * 0.92, glow);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.07);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, track);

    // Tick marks
    final tick = Paint()..color = Colors.white.withValues(alpha: 0.12)..strokeWidth = 2;
    for (int i = 0; i <= 10; i++) {
      final a = startAngle + sweep * (i / 10);
      final o1 = center + Offset(math.cos(a), math.sin(a)) * (radius - 16);
      final o2 = center + Offset(math.cos(a), math.sin(a)) * (radius - 24);
      canvas.drawLine(o1, o2, tick);
    }

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        colors: [color.withValues(alpha: 0.5), color],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius), startAngle, sweep * progress, false, arc);

    // Glow dot at the end of progress.
    if (progress > 0) {
      final a = startAngle + sweep * progress;
      final dot = center + Offset(math.cos(a), math.sin(a)) * radius;
      canvas.drawCircle(dot, 7, Paint()..color = color);
      canvas.drawCircle(dot, 14, Paint()..color = color.withValues(alpha: 0.25));
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}
