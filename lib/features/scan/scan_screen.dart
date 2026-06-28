import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../core/models/report.dart';
import '../../ui/glass_card.dart';
import '../../ui/motion.dart';
import '../../ui/scan_line.dart';
import '../../ui/theme.dart';
import '../../ui/transitions.dart';
import '../functional/functional_view.dart';
import 'scan_controller.dart';

/// The cinematic auto-scan: a phone silhouette with a sweeping scan-line and a
/// live module checklist that ticks off as each module completes.
class ScanScreen extends StatefulWidget {
  final ScanMode mode;
  final Claim claim;
  final String? imei;
  const ScanScreen({super.key, required this.mode, required this.claim, this.imei});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final ScanController _ctrl;
  late final AnimationController _sweep;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ctrl = ScanController(mode: widget.mode)
      ..claim = widget.claim
      ..imei = widget.imei
      ..reduceMotion = Motion.reduceMotion.value
      ..onModuleComplete = () => Motion.tick(context);
    _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))
      ..repeat();
    _run();
  }

  Future<void> _run() async {
    await _ctrl.runAutomatic();
    if (!mounted) return;
    setState(() => _done = true);
    _sweep.stop();
    await Motion.success(context);
    // Advance to interactive hardware tests, carrying the controller.
    if (!mounted) return;
    // Drop the haptic callback: it captured this (about-to-be-disposed) screen's
    // context, and FunctionalView fires onModuleComplete on its own later.
    _ctrl.onModuleComplete = null;
    Navigator.of(context).pushReplacement(
      fadeThroughRoute(context, FunctionalView(controller: _ctrl)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause the sweep when backgrounded to stay at 60fps and save power.
    if (state == AppLifecycleState.resumed) {
      if (!_done && !_sweep.isAnimating) _sweep.repeat();
    } else {
      if (_sweep.isAnimating) _sweep.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sweep.dispose();
    // NOTE: do not dispose _ctrl here — ownership passes to FunctionalView,
    // which still needs it to record results and build the report.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(_done ? 'Scan complete' : 'Scanning device',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(_done ? 'Compiling results…' : 'Reading hardware that fakes can’t spoof…',
                    style: const TextStyle(color: AppColors.textDim)),
                Expanded(
                  child: Center(
                    child: ScanVisual(sweep: _sweep, active: !_done, size: 210),
                  ),
                ),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) => GlassCard(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    child: _ModuleChecklist(modules: _ctrl.modules),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleChecklist extends StatelessWidget {
  final List<ScanModule> modules;
  const _ModuleChecklist({required this.modules});

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: Column(
        children: AnimationConfiguration.toStaggeredList(
          duration: const Duration(milliseconds: 350),
          childAnimationBuilder: (w) =>
              SlideAnimation(verticalOffset: 16, child: FadeInAnimation(child: w)),
          children: modules.map((m) => _ModuleRow(module: m)).toList(),
        ),
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  final ScanModule module;
  const _ModuleRow({required this.module});

  @override
  Widget build(BuildContext context) {
    final running = module.status == ModuleStatus.running;
    final done = module.status == ModuleStatus.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: done
                ? const Icon(Icons.check_circle_rounded, color: AppColors.good, size: 24)
                : running
                    ? const CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent)
                    : Icon(Icons.circle_outlined,
                        color: AppColors.textDim.withValues(alpha: 0.4), size: 22),
          ),
          const SizedBox(width: 14),
          Icon(module.icon,
              size: 18,
              color: done
                  ? AppColors.text
                  : running
                      ? AppColors.accent
                      : AppColors.textDim),
          const SizedBox(width: 10),
          Expanded(
            child: Text(module.label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: (done || running) ? AppColors.text : AppColors.textDim,
                )),
          ),
          if (module.detail.isNotEmpty)
            Text(module.detail,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12)),
        ],
      ),
    );
  }
}
