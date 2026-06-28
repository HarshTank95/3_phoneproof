import 'package:flutter/material.dart';

import '../../core/models/report.dart';
import '../../ui/glass_card.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';
import '../../ui/transitions.dart';
import 'claim_screen.dart';

/// First screen: pick Buyer vs Seller. Sets the tone and copy.
class ModeScreen extends StatelessWidget {
  const ModeScreen({super.key});

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
                  'A forensic scanner for second-hand phones. Reads the real age, '
                  'battery wear and specs that fakes and lying sellers can’t spoof.',
                  style: TextStyle(color: AppColors.textDim, fontSize: 15, height: 1.4),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Column(
                    children: [
                      _ModeTile(
                        mode: ScanMode.buyer,
                        icon: Icons.search_rounded,
                        title: 'I’m buying',
                        subtitle:
                            'Run a full scan, get a Trust Score and red flags before you pay.',
                      ),
                      const SizedBox(height: 16),
                      _ModeTile(
                        mode: ScanMode.seller,
                        icon: Icons.workspace_premium_rounded,
                        title: 'I’m selling',
                        subtitle:
                            'Prove your phone is genuine and healthy. Generate a Verified Certificate.',
                      ),
                    ],
                  ),
                ),
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

class _ModeTile extends StatelessWidget {
  final ScanMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  const _ModeTile(
      {required this.mode, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressScale(
        onTap: () => Navigator.of(context)
            .push(sharedAxisRoute(context, ClaimScreen(mode: mode))),
        child: GlassCard(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.accent, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textDim, fontSize: 13, height: 1.3)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textDim),
            ],
          ),
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
