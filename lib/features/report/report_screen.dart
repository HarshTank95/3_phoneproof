import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/models/report.dart';
import '../../core/models/test_result.dart';
import '../../ui/glass_card.dart';
import '../../ui/result_card.dart';
import '../../ui/theme.dart';
import 'share.dart';

/// Full results: top reasons, grouped expandable cards, and the shareable
/// Trust Certificate with QR + Report ID.
class ReportScreen extends StatelessWidget {
  final Report report;
  const ReportScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Full report')),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _CertificateCard(report: report),
              const SizedBox(height: 18),
              _Reasons(report: report),
              const SizedBox(height: 18),
              Text('Detailed results', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              ...report.groups.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ResultCard(
                      group: g,
                      initiallyExpanded: g.checks.any((c) => c.status == CheckStatus.fail),
                    ),
                  )),
              const SizedBox(height: 8),
              const _Disclaimer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reasons extends StatelessWidget {
  final Report report;
  const _Reasons({required this.report});

  @override
  Widget build(BuildContext context) {
    final reasons = report.reasons.where((r) => r.delta != 0).take(6).toList();
    if (reasons.isEmpty) {
      return GlassCard(
        child: Row(children: const [
          Icon(Icons.thumb_up_alt_rounded, color: AppColors.good),
          SizedBox(width: 10),
          Expanded(child: Text('No red flags found in the checks that ran.')),
        ]),
      );
    }
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why this score', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...reasons.map((r) {
            final color = switch (r.severity) {
              ReasonSeverity.critical => AppColors.risk,
              ReasonSeverity.major => AppColors.caution,
              ReasonSeverity.minor => AppColors.textDim,
              ReasonSeverity.positive => AppColors.good,
            };
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 8, color: color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.text, style: const TextStyle(fontSize: 13.5, height: 1.3))),
                  const SizedBox(width: 8),
                  Text(r.delta > 0 ? '+${r.delta}' : '${r.delta}',
                      style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CertificateCard extends StatefulWidget {
  final Report report;
  const _CertificateCard({required this.report});

  @override
  State<_CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends State<_CertificateCard> {
  final GlobalKey _captureKey = GlobalKey();
  bool _sharing = false;

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

  Future<void> _shareImage() async {
    try {
      setState(() => _sharing = true);
      final boundary =
          _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes != null) {
        await ShareService.shareImage(bytes.buffer.asUint8List(), widget.report);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    return Column(
      children: [
        RepaintBoundary(
          key: _captureKey,
          child: GlassCard(
            tint: AppColors.surfaceHigh,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_moon_rounded, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Trust Certificate',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _verdictColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(r.verdict.label,
                          style: TextStyle(color: _verdictColor, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${r.trustScore}',
                            style: TextStyle(
                                fontSize: 56,
                                height: 1,
                                fontWeight: FontWeight.w300,
                                color: _verdictColor)),
                        const Text('/ 100 Trust Score', style: TextStyle(color: AppColors.textDim)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: QrImageView(
                        data: r.payloadHash,
                        version: QrVersions.auto,
                        size: 92,
                        gapless: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _kv('Device', r.build.marketName),
                _kv('Android', '${r.build.release} (API ${r.build.sdkInt})'),
                if (r.battery.effectiveSoH != null)
                  _kv('Battery health', '${r.battery.effectiveSoH}%'),
                if (r.battery.cycleCount != null)
                  _kv('Charge cycles', '${r.battery.cycleCount}'),
                if (r.imei != null && r.imei!.isNotEmpty)
                  _kv('IMEI', '${r.imei} (unverifiable)'),
                _kv('Report ID', r.reportId),
                _kv('Issued', r.timestamp.toString().split('.').first),
                const SizedBox(height: 8),
                Text('SHA-256 · ${r.payloadHash.substring(0, 24)}…',
                    style: const TextStyle(color: AppColors.textDim, fontSize: 10)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => ShareService.sharePdf(r),
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: const Text('Share PDF'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sharing ? null : _shareImage,
                icon: _sharing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.image_rounded),
                label: const Text('Share image'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(k, style: const TextStyle(color: AppColors.textDim, fontSize: 13))),
          Expanded(
              child: Text(v,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Battery-truth fields come from the fuel-gauge chip and are resilient to software spoofing. '
      'Play Integrity is a strong signal, not absolute proof. IMEI can’t be verified by third-party '
      'apps on Android 10+. Values marked “Unavailable” simply aren’t exposed by this device — '
      'they are never guessed.',
      style: TextStyle(color: AppColors.textDim.withValues(alpha: 0.8), fontSize: 11, height: 1.4),
    );
  }
}
