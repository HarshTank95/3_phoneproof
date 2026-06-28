import 'package:flutter/material.dart';

import '../core/models/test_result.dart';
import 'glass_card.dart';
import 'theme.dart';

/// Grouped, expandable glassmorphism result card. Each row shows an
/// icon + label + colour status chip (colour-blind safe), a measured detail,
/// and a one-line plain-language meaning.
class ResultCard extends StatefulWidget {
  final CheckGroup group;
  final bool initiallyExpanded;
  const ResultCard({super.key, required this.group, this.initiallyExpanded = false});

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  late bool _expanded = widget.initiallyExpanded;

  ({int pass, int fail, int other}) get _tally {
    int pass = 0, fail = 0, other = 0;
    for (final c in widget.group.checks) {
      if (c.status == CheckStatus.pass) {
        pass++;
      } else if (c.status == CheckStatus.fail) {
        fail++;
      } else {
        other++;
      }
    }
    return (pass: pass, fail: fail, other: other);
  }

  @override
  Widget build(BuildContext context) {
    final t = _tally;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.group.icon, color: AppColors.accent, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.group.title,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (t.pass > 0) '${t.pass} pass',
                            if (t.fail > 0) '${t.fail} fail',
                            if (t.other > 0) '${t.other} other',
                          ].join(' · '),
                          style: const TextStyle(color: AppColors.textDim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (t.fail > 0)
                    StatusChip(icon: CheckStatus.fail.icon, label: '${t.fail}', color: AppColors.risk)
                  else
                    StatusChip(icon: CheckStatus.pass.icon, label: 'OK', color: AppColors.good),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Column(
                children: [
                  const Divider(color: AppColors.hairline, height: 1),
                  ...widget.group.checks.map((c) => _Row(check: c)),
                ],
              ),
            ),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final CheckResult check;
  const _Row({required this.check});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showDetail(context, check),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(check.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                const SizedBox(width: 8),
                StatusChip(icon: check.status.icon, label: check.status.label, color: check.status.color),
                const SizedBox(width: 6),
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textDim),
              ],
            ),
            if (check.detail.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(check.detail, style: const TextStyle(color: AppColors.text, fontSize: 13)),
            ],
            if (check.meaning.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(check.meaning,
                  style: const TextStyle(color: AppColors.textDim, fontSize: 11.5, height: 1.3)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet explaining a single check — what it is, the measured value,
/// and (for rows a device can't expose) exactly why it's unavailable and how
/// to unlock it. PhoneProof never guesses a value, so this makes the honesty
/// legible instead of looking broken.
void _showDetail(BuildContext context, CheckResult check) {
  final hint = _unlockHint(check);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(14),
      child: GlassCard(
        tint: AppColors.surfaceHigh,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.hairline, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(check.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
                StatusChip(
                    icon: check.status.icon, label: check.status.label, color: check.status.color),
              ],
            ),
            if (check.detail.isNotEmpty) ...[
              const SizedBox(height: 14),
              _sheetLabel('Reading'),
              Text(check.detail, style: const TextStyle(fontSize: 15, color: AppColors.text)),
            ],
            if (check.meaning.isNotEmpty) ...[
              const SizedBox(height: 14),
              _sheetLabel('What this means'),
              Text(check.meaning,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textDim, height: 1.4)),
            ],
            if (hint != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lock_open_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(hint,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.text, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _sheetLabel(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(t.toUpperCase(),
          style: const TextStyle(
              color: AppColors.textDim, fontSize: 10.5, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
    );

/// Why a value isn't shown, and how to unlock it. Returned only when relevant.
String? _unlockHint(CheckResult c) {
  if (c.status != CheckStatus.unavailable && c.status != CheckStatus.skipped) return null;
  switch (c.id) {
    case 'soh':
      return 'State of Health lives in the battery’s fuel-gauge chip. Android only exposes it on '
          '“Box-Ready” Android 15+ devices, or via Shizuku on Android 14. Many phones (including '
          'this one) don’t report it — so PhoneProof leaves it blank rather than guess.';
    case 'cycles':
      return 'Charge-cycle count is a public API on Android 14+, but the manufacturer has to fill '
          'it in. This device leaves it empty, so it can’t be read.';
    case 'realmah':
      return 'Real full-charge capacity is read from /sys (charge_full), which needs Shizuku or '
          'root access. Without it, rely on State of Health instead.';
    case 'mfgdate':
      return 'Battery manufacturing & first-use dates are only exposed on Android 15 “Box-Ready” '
          'devices, or via Shizuku on Android 14.';
    case 'integrity':
      return 'The certified-genuine check sends a hardware-backed token to a free serverless '
          'verifier. Configure that backend to enable it — until then it stays “Not checked”.';
    default:
      return 'This value isn’t exposed by your device or the current permissions. PhoneProof never '
          'shows a guessed value — that honesty is the whole point.';
  }
}
