import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../ui/theme.dart';

/// Live sensor readout. Streams accelerometer / gyroscope / magnetometer and
/// auto-detects activity (the user moving the phone) so the step can pass
/// without a manual judgement.
class LiveSensorsTest extends StatefulWidget {
  final ValueChanged<bool> onActivity; // true once real movement is seen
  const LiveSensorsTest({super.key, required this.onActivity});

  @override
  State<LiveSensorsTest> createState() => _LiveSensorsTestState();
}

class _LiveSensorsTestState extends State<LiveSensorsTest> {
  final _subs = <StreamSubscription>[];
  AccelerometerEvent? _acc;
  GyroscopeEvent? _gyro;
  MagnetometerEvent? _mag;
  bool _activity = false;
  double _baseline = 0;

  @override
  void initState() {
    super.initState();
    _subs.add(accelerometerEventStream().listen((e) {
      final mag = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
      if (_baseline == 0) _baseline = mag;
      if (!_activity && (mag - _baseline).abs() > 2.5) {
        _activity = true;
        widget.onActivity(true);
      }
      if (mounted) setState(() => _acc = e);
    }, onError: (_) {}));
    _subs.add(gyroscopeEventStream().listen((e) {
      if (mounted) setState(() => _gyro = e);
    }, onError: (_) {}));
    _subs.add(magnetometerEventStream().listen((e) {
      if (mounted) setState(() => _mag = e);
    }, onError: (_) {}));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _bar('Accelerometer', _acc == null ? null : '${_fmt(_acc!.x)}, ${_fmt(_acc!.y)}, ${_fmt(_acc!.z)}'),
        _bar('Gyroscope', _gyro == null ? null : '${_fmt(_gyro!.x)}, ${_fmt(_gyro!.y)}, ${_fmt(_gyro!.z)}'),
        _bar('Compass (magnetometer)', _mag == null ? null : '${_fmt(_mag!.x)}, ${_fmt(_mag!.y)}, ${_fmt(_mag!.z)} µT'),
        const SizedBox(height: 16),
        AnimatedOpacity(
          opacity: _activity ? 1 : 0.4,
          duration: const Duration(milliseconds: 300),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_activity ? Icons.check_circle_rounded : Icons.vibration_rounded,
                  color: _activity ? AppColors.good : AppColors.textDim),
              const SizedBox(width: 8),
              Text(_activity ? 'Movement detected — sensors live' : 'Move the phone to confirm',
                  style: TextStyle(color: _activity ? AppColors.good : AppColors.textDim)),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(double v) => v.toStringAsFixed(1);

  Widget _bar(String name, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(name, style: const TextStyle(fontSize: 12, color: AppColors.textDim))),
          Expanded(
            child: Text(value ?? 'Not present',
                style: TextStyle(
                    fontFeatures: const [],
                    color: value == null ? AppColors.unknown : AppColors.accent,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
