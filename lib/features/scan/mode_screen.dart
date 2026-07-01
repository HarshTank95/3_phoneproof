import 'package:flutter/material.dart';

import '../../core/models/report.dart';
import '../../ui/glass_card.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';
import '../../ui/transitions.dart';
import '../battery_truth/capacity_test_screen.dart';
import 'scan_screen.dart';

/// Landing screen. One scan covers both buying and selling — pitch it once,
/// then drop straight into the scan.
class ModeScreen extends StatelessWidget {
  const ModeScreen({super.key});

  void _startScan(BuildContext context) {
    Navigator.of(context).push(
      sharedAxisRoute(context, ScanScreen(mode: ScanMode.buyer, claim: const Claim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          // Adaptive: identical fixed layout on normal screens; on short screens
          // or large accessibility font scales it scrolls instead of overflowing.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.accent, AppColors.accentDim]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_moon_rounded, color: Colors.black87),
                    ),
                    const SizedBox(width: 12),
                    Text('PhoneProof', style: Theme.of(context).textTheme.headlineMedium),
                    const Spacer(),
                    _ReduceMotionButton(),
                  ],
                ),
                const SizedBox(height: 28),
                Text('Is this phone\ngenuine?',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 44, height: 1.05)),
                const SizedBox(height: 12),
                const Text(
                  'A forensic scanner for second-hand phones. Whether you’re buying or '
                  'selling, one scan reads the real age, battery wear and specs that fakes '
                  'and lying sellers can’t spoof.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('What the scan reveals',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      SizedBox(height: 14),
                      Row(children: [
                        _Point(Icons.battery_full_rounded, 'Battery truth'),
                        SizedBox(width: 10),
                        _Point(Icons.memory_rounded, 'Anti-spoof specs'),
                      ]),
                      SizedBox(height: 10),
                      Row(children: [
                        _Point(Icons.verified_user_rounded, 'Authenticity'),
                        SizedBox(width: 10),
                        _Point(Icons.workspace_premium_rounded, 'Trust Certificate'),
                      ]),
                    ],
                  ),
                ),
                // Single stretch zone: pushes the actions to the bottom on tall
                // screens, collapses to nothing on short ones.
                const Spacer(),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _startScan(context),
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text('Scan this phone'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context)
                      .push(sharedAxisRoute(context, const CapacityTestScreen())),
                  icon: const Icon(Icons.battery_charging_full_rounded),
                  label: const Text('Battery capacity test'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.textDim),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Runs fully on-device. We never present an unavailable value as measured.',
                        style: TextStyle(color: AppColors.textDim, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  const _Point(this.icon, this.title);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(title,
                  maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, height: 1.15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReduceMotionButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: Motion.reduceMotion,
      builder: (context, reduced, _) => IconButton(
        tooltip: reduced ? 'Motion reduced' : 'Reduce motion',
        onPressed: () => Motion.reduceMotion.value = !reduced,
        icon: Icon(reduced ? Icons.motion_photos_off_rounded : Icons.motion_photos_on_rounded,
            color: AppColors.textDim),
      ),
    );
  }
}
