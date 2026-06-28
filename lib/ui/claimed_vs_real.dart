import 'package:flutter/material.dart';

import '../core/models/report.dart';
import 'glass_card.dart';
import 'motion.dart';
import 'theme.dart';

/// The "Claimed vs Real" split reveal — the emotional climax when the seller's
/// claim conflicts with hardware truth. Animates in unless reduced motion.
class ClaimedVsReal extends StatelessWidget {
  final List<ClaimMismatch> mismatches;
  const ClaimedVsReal({super.key, required this.mismatches});

  @override
  Widget build(BuildContext context) {
    if (mismatches.isEmpty) return const SizedBox.shrink();
    final reduced = Motion.isReduced(context);
    return GlassCard(
      tint: AppColors.risk.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.report_problem_rounded, color: AppColors.risk),
            const SizedBox(width: 8),
            Text('Claimed vs Real',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.risk)),
          ]),
          const SizedBox(height: 12),
          ...mismatches.asMap().entries.map((e) {
            final mm = e.value;
            final row = _MismatchRow(mm: mm);
            if (reduced) return row;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 450 + e.key * 150),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => Opacity(
                opacity: v,
                child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
              ),
              child: row,
            );
          }),
        ],
      ),
    );
  }
}

class _MismatchRow extends StatelessWidget {
  final ClaimMismatch mm;
  const _MismatchRow({required this.mm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(mm.label.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.textDim, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _side('CLAIMED', mm.claimed, AppColors.textDim, Icons.sell_outlined)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded, color: AppColors.risk, size: 18),
              ),
              Expanded(child: _side('REAL', mm.real, AppColors.risk, Icons.science_outlined)),
            ],
          ),
          const SizedBox(height: 6),
          Text(mm.note, style: const TextStyle(color: AppColors.text, fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  Widget _side(String tag, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(tag, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
