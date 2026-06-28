import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Live preview + capture for one lens. Reports whether capture succeeded and
/// the captured resolution. Degrades to a clear message if the camera or
/// permission is unavailable.
class CameraCaptureTest extends StatefulWidget {
  final CameraLensDirection lens;
  final void Function(bool ok, String detail) onResult;
  const CameraCaptureTest({super.key, required this.lens, required this.onResult});

  @override
  State<CameraCaptureTest> createState() => _CameraCaptureTestState();
}

class _CameraCaptureTestState extends State<CameraCaptureTest> {
  CameraController? _controller;
  String? _error;
  bool _capturing = false;
  String? _captured;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final cams = await availableCameras();
      final cam = cams.firstWhere(
        (c) => c.lensDirection == widget.lens,
        orElse: () => throw CameraException('no_camera', 'No ${widget.lens.name} camera'),
      );
      final ctrl = CameraController(cam, ResolutionPreset.high, enableAudio: false);
      await ctrl.initialize();
      if (!mounted) return;
      setState(() => _controller = ctrl);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
      widget.onResult(false, 'Camera unavailable / permission denied');
    }
  }

  Future<void> _capture() async {
    final ctrl = _controller;
    if (ctrl == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await ctrl.takePicture();
      final size = ctrl.value.previewSize;
      final detail = size != null
          ? 'Captured ${size.height.toInt()}×${size.width.toInt()}'
          : 'Captured OK';
      setState(() {
        _captured = file.path;
        _capturing = false;
      });
      widget.onResult(true, detail);
    } catch (e) {
      setState(() => _capturing = false);
      widget.onResult(false, 'Capture failed');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography_rounded, color: AppColors.unknown, size: 48),
          const SizedBox(height: 12),
          Text('${widget.lens.name} camera unavailable',
              style: const TextStyle(color: AppColors.textDim)),
        ],
      );
    }
    final ctrl = _controller;
    if (ctrl == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    return Column(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: _captured == null
                ? CameraPreview(ctrl)
                : Image.file(File(_captured!), fit: BoxFit.cover, errorBuilder: (_, __, ___) {
                    return const Center(child: Icon(Icons.check_circle, color: AppColors.good, size: 64));
                  }),
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _captured == null ? _capture : null,
          icon: _capturing
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_captured == null ? Icons.camera_rounded : Icons.check_rounded),
          label: Text(_captured == null ? 'Capture' : 'Captured'),
        ),
      ],
    );
  }
}
