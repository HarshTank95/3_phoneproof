import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/battery_truth.dart';
import '../../core/native_bridge.dart';
import '../../ui/glass_card.dart';
import '../../ui/theme.dart';
import 'battery_truth_service.dart';

/// Guided coulomb-counting capacity measurement (the AccuBattery method).
///
/// While the phone charges, the fuel-gauge's charge counter (µAh) reports the
/// charge actually flowing into the cell. Capacity ≈ Δcounter / Δlevel%.
/// Everything shown is measured on this device during this session — when the
/// device doesn't expose a coulomb counter, the test honestly says so.
class CapacityTestScreen extends StatefulWidget {
  const CapacityTestScreen({super.key});

  @override
  State<CapacityTestScreen> createState() => _CapacityTestScreenState();
}

enum _Phase {
  probing, // first read
  unsupported, // no coulomb counter on this device
  waitingPlug, // not charging yet
  calibrating, // charging, waiting for the first level tick (edge-align)
  measuring, // between level edges
  done, // finished with a usable estimate
  insufficient, // ended without enough charge window
}

class _Edge {
  final int level; // %
  final int uah; // charge counter at the moment level ticked to [level]
  final DateTime at;
  const _Edge(this.level, this.uah, this.at);
}

class _CapacityTestScreenState extends State<CapacityTestScreen> {
  Timer? _timer;
  _Phase _phase = _Phase.probing;
  BatteryTruth? _last;

  _Edge? _startEdge;
  _Edge? _lastEdge;
  int? _prevLevel;
  DateTime? _sessionStart;

  // Result (frozen at finish so later samples don't mutate it).
  double? _resultMah;
  int? _resultDeltaPct;

  final _designCtrl = TextEditingController();
  int? _userDesignMah;

  @override
  void initState() {
    super.initState();
    NativeBridge.keepScreenOn(true);
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _designCtrl.dispose();
    NativeBridge.keepScreenOn(false);
    super.dispose();
  }

  /// µAh, normalising devices that report the counter in mAh.
  int? _counterUah(BatteryTruth b) {
    final c = b.chargeCounterUah;
    if (c == null || c <= 0) return null;
    return c < 20000 ? c * 1000 : c;
  }

  bool _isCharging(BatteryTruth b) =>
      b.statusRaw == 2 || (b.statusRaw == 5 && (b.pluggedRaw ?? 0) > 0);

  Future<void> _tick() async {
    final b = await BatteryTruthService.read();
    if (!mounted) return;

    setState(() {
      _last = b;
      final uah = _counterUah(b);
      final level = b.levelPercent ?? b.capacityPercent;

      switch (_phase) {
        case _Phase.probing:
          if (uah == null || level == null) {
            _phase = _Phase.unsupported;
          } else {
            _phase = _isCharging(b) ? _Phase.calibrating : _Phase.waitingPlug;
            _prevLevel = level;
          }
          break;

        case _Phase.waitingPlug:
          if (_isCharging(b)) {
            _phase = _Phase.calibrating;
            _prevLevel = level;
          }
          break;

        case _Phase.calibrating:
          if (!_isCharging(b)) {
            _phase = _Phase.waitingPlug;
            break;
          }
          // Start counting from the first level TICK so the whole window is
          // edge-aligned (integer % granularity would otherwise skew it).
          if (level != null && uah != null && _prevLevel != null && level > _prevLevel!) {
            _startEdge = _Edge(level, uah, DateTime.now());
            _lastEdge = _startEdge;
            _sessionStart = DateTime.now();
            _phase = _Phase.measuring;
          }
          _prevLevel = level ?? _prevLevel;
          break;

        case _Phase.measuring:
          if (level != null && uah != null && _lastEdge != null && level > _lastEdge!.level) {
            _lastEdge = _Edge(level, uah, DateTime.now());
          }
          if (!_isCharging(b)) {
            _finish(auto: true);
          } else if (level != null && level >= 100) {
            _finish(auto: true);
          }
          break;

        case _Phase.unsupported:
        case _Phase.done:
        case _Phase.insufficient:
          break;
      }
    });
  }

  int get _deltaPct =>
      (_startEdge != null && _lastEdge != null) ? _lastEdge!.level - _startEdge!.level : 0;

  double? get _liveEstimateMah {
    if (_startEdge == null || _lastEdge == null) return null;
    final dLevel = _lastEdge!.level - _startEdge!.level;
    final dUah = _lastEdge!.uah - _startEdge!.uah;
    if (dLevel < 1 || dUah <= 0) return null;
    return (dUah / 1000.0) / (dLevel / 100.0);
  }

  void _finish({bool auto = false}) {
    final est = _liveEstimateMah;
    if (est != null && _deltaPct >= 8) {
      _resultMah = est;
      _resultDeltaPct = _deltaPct;
      _phase = _Phase.done;
    } else {
      _phase = _Phase.insufficient;
    }
    NativeBridge.keepScreenOn(false);
    if (!auto) setState(() {});
  }

  String _confidence(int deltaPct) {
    if (deltaPct >= 40) return 'High confidence';
    if (deltaPct >= 20) return 'Good confidence';
    return 'Rough estimate';
  }

  double? get _liveWatts {
    final b = _last;
    if (b == null || b.currentNowUa == null || b.voltageMilliV == null) return null;
    final w = (b.currentNowUa!.abs() / 1e6) * (b.voltageMilliV! / 1000.0);
    return (w > 0.05 && w < 250) ? w : null;
  }

  int? get _designMah {
    final sysfs = _last?.designCapacityMah;
    if (sysfs != null && sysfs > 100) return sysfs;
    return _userDesignMah;
  }

  bool get _designIsUserEntered =>
      (_last?.designCapacityMah == null || _last!.designCapacityMah! <= 100) &&
      _userDesignMah != null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Battery Capacity Test')),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              ..._body(),
              const SizedBox(height: 16),
              _methodCard(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body() {
    switch (_phase) {
      case _Phase.probing:
        return [_stateCard(Icons.hourglass_top_rounded, 'Checking the fuel gauge…', '')];
      case _Phase.unsupported:
        return [
          _stateCard(
            Icons.block_rounded,
            'Not measurable on this device',
            'This phone doesn’t expose its coulomb counter (charge counter), so a '
                'measured capacity isn’t possible. PhoneProof never guesses a value.',
          )
        ];
      case _Phase.waitingPlug:
        return [
          _stateCard(
            Icons.power_rounded,
            'Plug in a charger to begin',
            'The test measures the charge flowing into the battery while it charges. '
                'A wall charger works best. Keep the app open.',
          ),
          if (_last != null) ...[const SizedBox(height: 14), _liveGrid()],
        ];
      case _Phase.calibrating:
        return [
          _stateCard(
            Icons.tune_rounded,
            'Charging — waiting for the first 1% step',
            'Measurement starts exactly when the battery level ticks up, so the '
                'window is precise. This usually takes a minute or two.',
          ),
          const SizedBox(height: 14),
          _liveGrid(),
        ];
      case _Phase.measuring:
        return [_measuringCard(), const SizedBox(height: 14), _liveGrid()];
      case _Phase.done:
        return [_resultCard()];
      case _Phase.insufficient:
        return [
          _stateCard(
            Icons.info_outline_rounded,
            'Not enough data yet',
            'The session ended before an 8% charge window was captured, so no honest '
                'estimate is possible. Plug back in to try again — the longer the '
                'charge window, the more accurate the result.',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => setState(() {
              _startEdge = null;
              _lastEdge = null;
              _phase = _Phase.waitingPlug;
              NativeBridge.keepScreenOn(true);
            }),
            icon: const Icon(Icons.replay_rounded),
            label: const Text('Try again'),
          ),
        ];
    }
  }

  Widget _measuringCard() {
    final est = _liveEstimateMah;
    final d = _deltaPct;
    final elapsed = _sessionStart == null
        ? ''
        : '${DateTime.now().difference(_sessionStart!).inMinutes} min';
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const _PulseDot(),
            const SizedBox(width: 8),
            Text('Measuring… $elapsed',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_startEdge?.level ?? '–'}% → ${_lastEdge?.level ?? '–'}%',
                style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 18),
          Center(
            child: Column(children: [
              Text(
                est == null ? '…' : '${est.round()}',
                style: const TextStyle(
                    fontSize: 54, fontWeight: FontWeight.w300, color: AppColors.text, height: 1),
              ),
              const Text('mAh · running estimate', style: TextStyle(color: AppColors.textDim)),
              const SizedBox(height: 6),
              if (d >= 1)
                Text(
                  d >= 8 ? _confidence(d) : 'Keep charging — ${8 - d}% more for a first estimate',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: d >= 20 ? AppColors.good : AppColors.caution,
                      fontWeight: FontWeight.w600),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          Text(
            'Charge counted: ${_startEdge != null && _lastEdge != null ? ((_lastEdge!.uah - _startEdge!.uah) / 1000).round() : 0} mAh over $d% of battery',
            style: const TextStyle(color: AppColors.textDim, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: d >= 8 ? () => _finish() : null,
              icon: const Icon(Icons.flag_rounded),
              label: Text(d >= 8 ? 'Finish test' : 'Finish (needs ≥8% window)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard() {
    final mah = _resultMah!;
    final d = _resultDeltaPct!;
    final design = _designMah;
    final sohPct = design != null ? (mah * 100 / design).round() : null;
    return GlassCard(
      tint: AppColors.surfaceHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.battery_charging_full_rounded, color: AppColors.good),
            const SizedBox(width: 8),
            Text('Measured capacity', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            StatusChip(
                icon: Icons.science_rounded, label: _confidence(d), color: d >= 20 ? AppColors.good : AppColors.caution),
          ]),
          const SizedBox(height: 18),
          Center(
            child: Column(children: [
              Text('${mah.round()}',
                  style: const TextStyle(
                      fontSize: 60, fontWeight: FontWeight.w300, color: AppColors.text, height: 1)),
              const Text('mAh', style: TextStyle(color: AppColors.textDim)),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Measured over a $d% charge window using the fuel-gauge coulomb counter.',
              style: const TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 14),
          if (sohPct != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (sohPct >= 80 ? AppColors.good : AppColors.caution).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Icon(sohPct >= 80 ? Icons.favorite_rounded : Icons.monitor_heart_rounded,
                    size: 18, color: sohPct >= 80 ? AppColors.good : AppColors.caution),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '≈ $sohPct% of the $design mAh design capacity'
                    '${_designIsUserEntered ? ' (design value entered by you)' : ' (design from the device)'}',
                    style: const TextStyle(fontSize: 13.5, height: 1.35),
                  ),
                ),
              ]),
            ),
          ] else ...[
            const Text('To estimate health %, enter this model’s design capacity (from its spec sheet):',
                style: TextStyle(color: AppColors.textDim, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _designCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'e.g. 4500',
                    suffixText: 'mAh',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () {
                  final v = int.tryParse(_designCtrl.text.trim());
                  if (v != null && v >= 500 && v <= 20000) {
                    setState(() => _userDesignMah = v);
                  }
                },
                child: const Text('Apply'),
              ),
            ]),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => setState(() {
                _startEdge = null;
                _lastEdge = null;
                _resultMah = null;
                _resultDeltaPct = null;
                _phase = _Phase.waitingPlug;
                NativeBridge.keepScreenOn(true);
              }),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Measure again'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _liveGrid() {
    final b = _last!;
    final w = _liveWatts;
    final rows = <(String, String)>[
      ('Battery level', b.levelPercent != null ? '${b.levelPercent}%' : '—'),
      ('State', '${b.chargingStateLabel}${b.plugLabel != null ? ' · ${b.plugLabel}' : ''}'),
      if (w != null) ('Charging power (live)', '${w.toStringAsFixed(1)} W'),
      if (b.temperatureC != null) ('Temperature', '${b.temperatureC!.toStringAsFixed(1)} °C'),
      if (b.voltageMilliV != null) ('Voltage', '${b.voltageMilliV} mV'),
    ];
    return GlassCard(
      child: Column(
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Text(r.$1, style: const TextStyle(color: AppColors.textDim, fontSize: 13)),
                    const Spacer(),
                    Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  ]),
                ))
            .toList(),
      ),
    );
  }

  Widget _stateCard(IconData icon, String title, String body) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          ]),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(color: AppColors.textDim, fontSize: 13, height: 1.4)),
          ],
        ],
      ),
    );
  }

  Widget _methodCard() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('HOW THIS WORKS',
              style: TextStyle(
                  color: AppColors.textDim, fontSize: 10.5, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
          SizedBox(height: 8),
          Text(
            'Your battery’s fuel-gauge chip counts the charge flowing into the cell '
            '(a coulomb counter). While charging, PhoneProof reads that counter at each '
            '1% step and computes: capacity = charge added ÷ % gained.\n\n'
            'It is a real measurement of THIS battery — not a spec-sheet number. Accuracy '
            'grows with the charge window (8% = rough, 20% = good, 40%+ = high). Gauge '
            'quality varies by phone, so treat the result as a strong estimate.',
            style: TextStyle(color: AppColors.textDim, fontSize: 12.5, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: AppColors.good, shape: BoxShape.circle),
      ),
    );
  }
}
