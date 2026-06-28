import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:torch_light/torch_light.dart';
import 'package:vibration/vibration.dart';

import '../../core/models/test_result.dart';
import '../../ui/glass_card.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';
import '../../ui/transitions.dart';
import '../report/reveal_screen.dart';
import '../scan/scan_controller.dart';
import 'audio_test.dart';
import 'camera_test.dart';
import 'connectivity_test.dart';
import 'screen_test.dart';
import 'sensor_live_test.dart';

/// Guided, full-screen functional hardware tests. One big instruction per step
/// with large PASS / FAIL / SKIP targets. Results feed the scan controller.
class FunctionalView extends StatefulWidget {
  final ScanController controller;
  const FunctionalView({super.key, required this.controller});

  @override
  State<FunctionalView> createState() => _FunctionalViewState();
}

class _FunctionalViewState extends State<FunctionalView> {
  int _index = 0;
  bool _gateUnlocked = false; // an interactive precondition was satisfied

  late final List<_StepDef> _steps = _buildSteps();

  ScanController get c => widget.controller;

  List<_StepDef> _buildSteps() => [
        _StepDef('intro', 'Hardware checks', Icons.touch_app_rounded, isIntro: true),
        _StepDef('touch', 'Touch coverage', Icons.grid_on_rounded),
        _StepDef('deadpixel', 'Dead-pixel & uniformity', Icons.gradient_rounded),
        _StepDef('speaker', 'Loudspeaker', Icons.volume_up_rounded),
        _StepDef('mic', 'Microphone', Icons.mic_rounded),
        _StepDef('vibration', 'Vibration motor', Icons.vibration_rounded),
        _StepDef('flashlight', 'Flashlight / LED', Icons.flashlight_on_rounded),
        _StepDef('cam_rear', 'Rear camera', Icons.photo_camera_back_rounded),
        _StepDef('cam_front', 'Front camera', Icons.photo_camera_front_rounded),
        _StepDef('buttons', 'Volume & power buttons', Icons.smart_button_rounded),
        _StepDef('sensors', 'Motion sensors', Icons.sensors_rounded),
        _StepDef('connectivity', 'Connectivity', Icons.wifi_rounded),
      ];

  void _record(String id, String title, CheckStatus status, String detail, String meaning) {
    c.addFunctional(CheckResult(id: id, title: title, status: status, detail: detail, meaning: meaning));
  }

  Future<void> _advance() async {
    await Motion.tick(context);
    if (_index < _steps.length - 1) {
      setState(() {
        _index++;
        _gateUnlocked = false;
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    c.markHardwareComplete();
    final report = c.buildReport();
    Navigator.of(context).pushReplacement(
      fadeThroughRoute(context, RevealScreen(report: report)),
    );
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera, Permission.microphone, Permission.locationWhenInUse].request();
  }

  @override
  void dispose() {
    AudioTest.dispose();
    // FunctionalView owns the controller once ScanScreen hands it over.
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_index];
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Progress(index: _index, total: _steps.length),
              Expanded(child: _buildStep(step)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(_StepDef step) {
    switch (step.id) {
      case 'intro':
        return _intro(step);
      case 'touch':
        return _touch(step);
      case 'deadpixel':
        return _deadPixel(step);
      case 'speaker':
        return _speaker(step);
      case 'mic':
        return _mic(step);
      case 'vibration':
        return _vibration(step);
      case 'flashlight':
        return _flashlight(step);
      case 'cam_rear':
        return _camera(step, CameraLensDirection.back);
      case 'cam_front':
        return _camera(step, CameraLensDirection.front);
      case 'buttons':
        return _buttons(step);
      case 'sensors':
        return _sensors(step);
      case 'connectivity':
        return _connectivity(step);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------- steps

  Widget _intro(_StepDef s) {
    return _Frame(
      step: s,
      hero: true,
      instruction:
          'A few quick guided tests for screen, audio, cameras, buttons and sensors. '
          'Each one is PASS / FAIL / SKIP — skip anything you can’t do right now.',
      body: const Icon(Icons.checklist_rtl_rounded, size: 96, color: AppColors.accent),
      actions: [
        FilledButton.icon(
          onPressed: () async {
            await _requestPermissions();
            if (!mounted) return;
            _advance();
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Begin hardware tests'),
        ),
        TextButton(
          onPressed: () {
            // Record all as skipped, jump to finish.
            for (final st in _steps.where((e) => !e.isIntro)) {
              _record(st.id, st.title, CheckStatus.skipped, 'Skipped', '');
            }
            _finish();
          },
          child: const Text('Skip all hardware tests'),
        ),
      ],
    );
  }

  Widget _touch(_StepDef s) {
    return _Frame(
      step: s,
      instruction: 'Drag your finger across every cell. They turn teal as they register touch.',
      bodyExpanded: true,
      body: TouchGridTest(onComplete: () {
        Motion.success(context);
        setState(() => _gateUnlocked = true);
      }),
      actions: _passFailSkip(s,
          passEnabled: _gateUnlocked,
          passLabel: _gateUnlocked ? 'All cells responded' : 'Cover all cells first',
          passDetail: 'All touch zones responded',
          failDetail: 'Dead touch zone(s) detected',
          meaning: 'Detects dead or unresponsive areas of the digitiser.'),
    );
  }

  Widget _deadPixel(_StepDef s) {
    return _Frame(
      step: s,
      instruction: 'Tap the panel to cycle red, green, blue, white and black. Look for dead/stuck pixels or discolouration.',
      bodyExpanded: true,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: DeadPixelTest(onAllSeen: () => setState(() => _gateUnlocked = true)),
      ),
      actions: _passFailSkip(s,
          passDetail: 'No dead pixels / uniform panel',
          failDetail: 'Dead pixels or discolouration',
          meaning: 'Solid colours reveal stuck pixels and backlight issues.'),
    );
  }

  Widget _speaker(_StepDef s) {
    return _Frame(
      step: s,
      hero: true,
      instruction: 'Play the test tone. Did you hear a clear, undistorted sound from the speaker?',
      body: _BigTapButton(
        icon: Icons.graphic_eq_rounded,
        label: 'Play test tone',
        onTap: () async {
          await AudioTest.playTone(freq: 660);
          setState(() => _gateUnlocked = true);
        },
      ),
      actions: _passFailSkip(s,
          passDetail: 'Speaker clear',
          failDetail: 'No sound / distorted',
          meaning: 'Checks the loudspeaker output.'),
    );
  }

  Widget _mic(_StepDef s) {
    return _MicStep(
      onResult: (status, detail) {
        _record('mic', s.title, status, detail, 'Records a clip and plays it back.');
        _advance();
      },
      onSkip: () {
        _record('mic', s.title, CheckStatus.skipped, 'Skipped', '');
        _advance();
      },
    );
  }

  Widget _vibration(_StepDef s) {
    return _Frame(
      step: s,
      hero: true,
      instruction: 'Trigger the vibration motor. Did you feel a clear buzz?',
      body: _BigTapButton(
        icon: Icons.vibration_rounded,
        label: 'Vibrate',
        onTap: () async {
          if (await Vibration.hasVibrator()) {
            Vibration.vibrate(duration: 500);
          } else {
            await Motion.heavy(context);
          }
          setState(() => _gateUnlocked = true);
        },
      ),
      actions: _passFailSkip(s,
          passDetail: 'Vibration felt',
          failDetail: 'No vibration',
          meaning: 'Checks the haptic / vibration motor.'),
    );
  }

  Widget _flashlight(_StepDef s) {
    return _Frame(
      step: s,
      hero: true,
      instruction: 'Turn the flashlight on and off. Does the rear LED light up?',
      body: _FlashlightBody(onUsed: () => setState(() => _gateUnlocked = true)),
      actions: _passFailSkip(s,
          passDetail: 'LED works',
          failDetail: 'LED did not light',
          meaning: 'Checks the camera flash / torch LED.'),
    );
  }

  Widget _camera(_StepDef s, CameraLensDirection lens) {
    return _Frame(
      step: s,
      instruction: 'Preview should be live. Capture a photo to confirm the ${lens.name} camera works.',
      bodyExpanded: true,
      body: CameraCaptureTest(
        key: ValueKey(lens),
        lens: lens,
        onResult: (ok, detail) {
          _record(s.id, s.title, ok ? CheckStatus.pass : CheckStatus.fail, detail,
              'Live preview + capture from the ${lens.name} camera.');
          setState(() => _gateUnlocked = true);
        },
      ),
      actions: [
        FilledButton(
          onPressed: _gateUnlocked ? _advance : null,
          child: Text(_gateUnlocked ? 'Next' : 'Capture to continue'),
        ),
        TextButton(
          onPressed: () {
            _record(s.id, s.title, CheckStatus.skipped, 'Skipped', '');
            _advance();
          },
          child: const Text('Skip'),
        ),
      ],
    );
  }

  Widget _buttons(_StepDef s) {
    return _Frame(
      step: s,
      hero: true,
      instruction: 'Press Volume Up, Volume Down and the Power button. Confirm each physically clicks and works.',
      body: const Icon(Icons.smart_button_rounded, size: 96, color: AppColors.accent),
      actions: _passFailSkip(s,
          passEnabled: true,
          passDetail: 'Buttons click & respond',
          failDetail: 'A button is stuck / dead',
          meaning: 'Physical button check (confirmed by you).'),
    );
  }

  Widget _sensors(_StepDef s) {
    return _Frame(
      step: s,
      instruction: 'Gently move and rotate the phone. Live values should change as you move.',
      body: LiveSensorsTest(onActivity: (_) => setState(() => _gateUnlocked = true)),
      actions: _passFailSkip(s,
          passEnabled: _gateUnlocked,
          passLabel: _gateUnlocked ? 'Sensors responding' : 'Move the phone first',
          passDetail: 'Accelerometer / gyro / compass live',
          failDetail: 'Sensors not responding',
          meaning: 'Live motion-sensor check.'),
    );
  }

  Widget _connectivity(_StepDef s) {
    return FutureBuilder<ConnectivitySnapshot>(
      future: ConnectivityTest.read(),
      builder: (context, snap) {
        final data = snap.data;
        return _Frame(
          step: s,
          instruction: 'Detected radios and links. This is the final step.',
          body: data == null
              ? const CircularProgressIndicator(color: AppColors.accent)
              : GlassCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _conn('Wi-Fi', data.wifi, data.wifiName),
                      const Divider(color: AppColors.hairline, height: 14),
                      _conn('Mobile data', data.mobile, null),
                      const Divider(color: AppColors.hairline, height: 14),
                      _conn('Bluetooth link', data.bluetooth, null),
                      if (data.ip != null) ...[
                        const Divider(color: AppColors.hairline, height: 14),
                        _conn('IP address', true, data.ip),
                      ],
                    ],
                  ),
                ),
          actions: [
            FilledButton.icon(
              onPressed: () {
                if (data != null) {
                  _record('connectivity', s.title, CheckStatus.info,
                      'Wi-Fi ${data.wifi ? 'on' : 'off'} · Mobile ${data.mobile ? 'on' : 'off'}',
                      'Detected network radios.');
                } else {
                  _record('connectivity', s.title, CheckStatus.skipped, 'Skipped', '');
                }
                _finish();
              },
              icon: const Icon(Icons.assessment_rounded),
              label: const Text('See results'),
            ),
          ],
        );
      },
    );
  }

  Widget _conn(String name, bool on, String? detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(on ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: on ? AppColors.good : AppColors.unknown, size: 20),
          const SizedBox(width: 10),
          Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (detail != null)
            Flexible(
                child: Text(detail,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 12))),
        ],
      ),
    );
  }

  // PASS / FAIL / SKIP action set that records and advances.
  List<Widget> _passFailSkip(
    _StepDef s, {
    bool passEnabled = true,
    String? passLabel,
    required String passDetail,
    required String failDetail,
    required String meaning,
  }) {
    return [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.good),
              onPressed: passEnabled
                  ? () {
                      _record(s.id, s.title, CheckStatus.pass, passDetail, meaning);
                      _advance();
                    }
                  : null,
              icon: const Icon(Icons.check_rounded, color: Colors.black),
              label: Text(passLabel ?? 'Pass',
                  style: const TextStyle(color: Colors.black)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.risk), foregroundColor: AppColors.risk),
              onPressed: () {
                _record(s.id, s.title, CheckStatus.fail, failDetail, meaning);
                _advance();
              },
              icon: const Icon(Icons.close_rounded),
              label: const Text('Fail'),
            ),
          ),
        ],
      ),
      TextButton(
        onPressed: () {
          _record(s.id, s.title, CheckStatus.skipped, 'Skipped', meaning);
          _advance();
        },
        child: const Text('Skip'),
      ),
    ];
  }
}

// ---------------------------------------------------------------- scaffolding

class _StepDef {
  final String id;
  final String title;
  final IconData icon;
  final bool isIntro;
  _StepDef(this.id, this.title, this.icon, {this.isIntro = false});
}

class _Frame extends StatelessWidget {
  final _StepDef step;
  final String instruction;
  final Widget body;
  final bool bodyExpanded;
  final bool hero;
  final List<Widget> actions;
  const _Frame({
    required this.step,
    required this.instruction,
    required this.body,
    required this.actions,
    this.bodyExpanded = false,
    this.hero = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(step.icon, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(step.title, style: Theme.of(context).textTheme.headlineMedium)),
            ],
          ),
          const SizedBox(height: 8),
          Text(instruction, style: const TextStyle(color: AppColors.textDim, height: 1.4)),
          const SizedBox(height: 16),
          if (bodyExpanded)
            Expanded(child: body)
          else if (hero)
            Expanded(
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.accent.withValues(alpha: 0.10),
                      AppColors.accent.withValues(alpha: 0.0),
                    ]),
                  ),
                  child: Padding(padding: const EdgeInsets.all(44), child: body),
                ),
              ),
            )
          else
            Expanded(child: Center(child: body)),
          const SizedBox(height: 14),
          ...actions,
        ],
      ),
    );
  }
}

class _BigTapButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BigTapButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.accent),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

class _FlashlightBody extends StatefulWidget {
  final VoidCallback onUsed;
  const _FlashlightBody({required this.onUsed});

  @override
  State<_FlashlightBody> createState() => _FlashlightBodyState();
}

class _FlashlightBodyState extends State<_FlashlightBody> {
  bool _on = false;

  Future<void> _toggle() async {
    try {
      if (_on) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() => _on = !_on);
      widget.onUsed();
    } catch (_) {
      widget.onUsed();
    }
  }

  @override
  void dispose() {
    if (_on) {
      TorchLight.disableTorch().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _BigTapButton(
      icon: _on ? Icons.flashlight_on_rounded : Icons.flashlight_off_rounded,
      label: _on ? 'Turn off' : 'Turn on',
      onTap: _toggle,
    );
  }
}

class _MicStep extends StatefulWidget {
  final void Function(CheckStatus, String) onResult;
  final VoidCallback onSkip;
  const _MicStep({required this.onResult, required this.onSkip});

  @override
  State<_MicStep> createState() => _MicStepState();
}

class _MicStepState extends State<_MicStep> {
  int _phase = 0; // 0 idle, 1 recording, 2 recorded
  String? _path;

  Future<void> _toggle() async {
    if (_phase == 0) {
      final ok = await AudioTest.startRecording();
      if (!ok) {
        widget.onResult(CheckStatus.skipped, 'Mic permission denied');
        return;
      }
      setState(() => _phase = 1);
    } else if (_phase == 1) {
      final p = await AudioTest.stopRecording();
      setState(() {
        _path = p;
        _phase = 2;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Frame(
      step: _StepDef('mic', 'Microphone', Icons.mic_rounded),
      hero: true,
      instruction: _phase == 0
          ? 'Tap to record ~3 seconds, then play it back. Do you hear your voice clearly?'
          : _phase == 1
              ? 'Recording… speak now, then tap to stop.'
              : 'Play back the recording. Clear?',
      body: _BigTapButton(
        icon: _phase == 1 ? Icons.stop_rounded : (_phase == 2 ? Icons.play_arrow_rounded : Icons.mic_rounded),
        label: _phase == 0 ? 'Record' : (_phase == 1 ? 'Stop' : 'Play back'),
        onTap: () async {
          if (_phase == 2 && _path != null) {
            await AudioTest.playback(_path!);
          } else {
            await _toggle();
          }
        },
      ),
      actions: [
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.good),
              onPressed: _phase == 2
                  ? () => widget.onResult(CheckStatus.pass, 'Mic records & plays back')
                  : null,
              icon: const Icon(Icons.check_rounded, color: Colors.black),
              label: const Text('Pass', style: TextStyle(color: Colors.black)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.risk), foregroundColor: AppColors.risk),
              onPressed: _phase == 2
                  ? () => widget.onResult(CheckStatus.fail, 'Mic unclear / silent')
                  : null,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Fail'),
            ),
          ),
        ]),
        TextButton(onPressed: widget.onSkip, child: const Text('Skip')),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  final int index;
  final int total;
  const _Progress({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
      child: Row(
        children: List.generate(total, (i) {
          final done = i <= index;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: done ? AppColors.accent : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}
