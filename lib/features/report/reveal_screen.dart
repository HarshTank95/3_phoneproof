import 'package:flutter/material.dart';

import '../../core/models/report.dart';
import '../../ui/claimed_vs_real.dart';
import '../../ui/glass_card.dart';
import '../../ui/motion.dart';
import '../../ui/scan_gauge.dart';
import '../../ui/theme.dart';
import '../../ui/transitions.dart';
import 'report_screen.dart';

/// The reveal: the Trust Score gauge counts up and colour-tweens to the
/// verdict, with a one-line plain verdict and the Claimed-vs-Real climax.
class RevealScreen extends StatefulWidget {
  final Report report;
  const RevealScreen({super.key, required this.report});

  @override
  State<RevealScreen> createState() => _RevealScreenState();
}

class _RevealScreenState extends State<RevealScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => Motion.heavy(context));
  }

  Color get _verdictColor {
    switch (widget.report.verdict) {
      case Verdict.genuine:
        return AppColors.good;
      case Verdict.caution:
        return AppColors.caution;
      case Verdict.highRisk:
        return AppColors.risk;
    }
  }

  IconData get _verdictIcon {
    switch (widget.report.verdict) {
      case Verdict.genuine:
        return Icons.verified_rounded;
      case Verdict.caution:
        return Icons.warning_amber_rounded;
      case Verdict.highRisk:
        return Icons.dangerous_rounded;
    }
  }

  String get _verdictLine {
    switch (widget.report.verdict) {
      case Verdict.genuine:
        return 'This phone looks genuine and healthy.';
      case Verdict.caution:
        return 'Some flags worth a closer look before you buy.';
      case Verdict.highRisk:
        return 'Strong fraud signals — proceed with great caution.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              const SizedBox(height: 6),
              Center(
                child: Text(r.build.marketName,
                    textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 2),
              Center(
                child: Text(
                  'Android ${r.build.release}  ·  Forensic scan',
                  style: const TextStyle(color: AppColors.textDim, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 22),
              Center(child: TrustGauge(score: r.trustScore, verdict: r.verdict, size: 260)),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _verdictColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _verdictColor.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_verdictIcon, color: _verdictColor),
                      const SizedBox(width: 8),
                      Text(r.verdict.label,
                          style: TextStyle(color: _verdictColor, fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(_verdictLine,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 15)),
              ),
              const SizedBox(height: 24),
              ClaimedVsReal(mismatches: r.mismatches),
              if (r.mismatches.isNotEmpty) const SizedBox(height: 16),
              _TopReasons(report: r, color: _verdictColor),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(sharedAxisRoute(context, ReportScreen(report: r))),
                icon: const Icon(Icons.fact_check_rounded),
                label: const Text('See full report'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Scan another phone'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact "top reasons" payoff shown right on the reveal — the score is never
/// a black box. Staggers in unless reduced motion.
class _TopReasons extends StatelessWidget {
  final Report report;
  final Color color;
  const _TopReasons({required this.report, required this.color});

  @override
  Widget build(BuildContext context) {
    final deductions = report.reasons.where((r) => r.delta < 0).take(3).toList();
    final reduced = Motion.isReduced(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(deductions.isEmpty ? Icons.verified_rounded : Icons.troubleshoot_rounded,
                  size: 18, color: deductions.isEmpty ? AppColors.good : color),
              const SizedBox(width: 8),
              Text(deductions.isEmpty ? 'No red flags' : 'Top reasons',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (deductions.isNotEmpty)
                Text('${report.reasons.where((r) => r.delta < 0).length} total',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          if (deductions.isEmpty)
            const Text('Nothing tripped the fraud or health checks that ran.',
                style: TextStyle(color: AppColors.textDim, fontSize: 13))
          else
            ...deductions.asMap().entries.map((e) {
              final r = e.value;
              final rowColor = switch (r.severity) {
                ReasonSeverity.critical => AppColors.risk,
                ReasonSeverity.major => AppColors.caution,
                _ => AppColors.textDim,
              };
              final row = Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(color: rowColor, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(r.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13.5, height: 1.25))),
                    const SizedBox(width: 8),
                    Text('${r.delta}',
                        style: TextStyle(color: rowColor, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
              );
              if (reduced) return row;
              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 350 + e.key * 120),
                curve: Curves.easeOutCubic,
                builder: (context, v, child) =>
                    Opacity(opacity: v, child: Transform.translate(offset: Offset((1 - v) * 14, 0), child: child)),
                child: row,
              );
            }),
        ],
      ),
    );
  }
}
