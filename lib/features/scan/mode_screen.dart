import 'package:flutter/material.dart';

import '../../core/models/report.dart';
import '../../ui/glass_card.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';
import '../../ui/transitions.dart';
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
                const SizedBox(height: 28),
                Expanded(
                  child: Center(
                    child: GlassCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('What the scan reveals',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          SizedBox(height: 16),
                          _Point(Icons.battery_full_rounded, 'Battery truth',
                              'Real health, wear and live condition.'),
                          SizedBox(height: 14),
                          _Point(Icons.memory_rounded, 'Anti-spoof specs',
                              'Storage, RAM, display, sensors and CPU — measured, not trusted.'),
                          SizedBox(height: 14),
                          _Point(Icons.verified_user_rounded, 'Authenticity',
                              'Emulator / root heuristics and a genuine-device check.'),
                          SizedBox(height: 14),
                          _Point(Icons.workspace_premium_rounded, 'Trust Certificate',
                              'A Trust Score and a shareable, tamper-evident report.'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => _startScan(context),
                  icon: const Icon(Icons.radar_rounded),
                  label: const Text('Scan this phone'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
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
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Point(this.icon, this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.textDim, fontSize: 12.5, height: 1.3)),
            ],
          ),
        ),
      ],
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
