import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Full-screen solid colours + mid-gray patterns for dead/stuck-pixel and
/// OLED burn-in inspection. Solid R/G/B/W/K expose dead pixels; the gray
/// frames make burn-in ghosting and uniformity blotches easiest to spot.
class DeadPixelTest extends StatefulWidget {
  final VoidCallback onAllSeen;
  const DeadPixelTest({super.key, required this.onAllSeen});

  @override
  State<DeadPixelTest> createState() => _DeadPixelTestState();
}

class _DeadPixelTestState extends State<DeadPixelTest> {
  // Solid colours first (dead/stuck pixels), then gray shades (burn-in).
  static const _frames = [
    (Color(0xFFFF0000), 'Look for dark/bright dots (dead or stuck pixels)'),
    (Color(0xFF00FF00), 'Look for dark/bright dots (dead or stuck pixels)'),
    (Color(0xFF0000FF), 'Look for dark/bright dots (dead or stuck pixels)'),
    (Color(0xFFFFFFFF), 'Look for tint, dark spots or non-uniform patches'),
    (Color(0xFF000000), 'Look for bright/coloured stuck pixels'),
    (Color(0xFF808080), 'Burn-in: look for faint ghost images (icons, keyboard, bars)'),
    (Color(0xFF3F3F3F), 'Burn-in: look for faint ghost images on the dark gray'),
    (Color(0xFFBFBFBF), 'Uniformity: look for blotches or a coloured tint'),
  ];
  int _i = 0;
  bool _fired = false;

  void _next() {
    if (_i < _frames.length - 1) {
      setState(() => _i++);
      if (_i == _frames.length - 1 && !_fired) {
        _fired = true;
        widget.onAllSeen();
      }
    } else {
      setState(() => _i = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frames[_i];
    final onDark = frame.$1.computeLuminance() < 0.5;
    final chipBg = onDark ? Colors.white24 : Colors.black54;
    return GestureDetector(
      onTap: _next,
      child: Container(
        color: frame.$1,
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(frame.$2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13)),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Tap to change pattern  (${_i + 1}/${_frames.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Coverage grid for touch / multi-touch — every cell must be touched.
class TouchGridTest extends StatefulWidget {
  final VoidCallback onComplete;
  const TouchGridTest({super.key, required this.onComplete});

  @override
  State<TouchGridTest> createState() => _TouchGridTestState();
}

class _TouchGridTestState extends State<TouchGridTest> {
  static const _cols = 5;
  static const _rows = 8;
  final Set<int> _hit = {};
  bool _fired = false;

  void _mark(int index) {
    if (_hit.contains(index)) return;
    setState(() => _hit.add(index));
    if (!_fired && _hit.length == _cols * _rows) {
      _fired = true;
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cellW = constraints.maxWidth / _cols;
      final cellH = constraints.maxHeight / _rows;
      return Listener(
        onPointerDown: (e) => _hitTest(e.localPosition, cellW, cellH),
        onPointerMove: (e) => _hitTest(e.localPosition, cellW, cellH),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _cols),
          itemCount: _cols * _rows,
          itemBuilder: (context, i) {
            final hit = _hit.contains(i);
            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: hit ? AppColors.accent.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: AppColors.hairline),
                borderRadius: BorderRadius.circular(6),
              ),
              child: hit
                  ? const Icon(Icons.check, size: 14, color: Colors.black)
                  : null,
            );
          },
        ),
      );
    });
  }

  void _hitTest(Offset p, double cellW, double cellH) {
    final c = (p.dx / cellW).floor();
    final r = (p.dy / cellH).floor();
    if (c < 0 || c >= _cols || r < 0 || r >= _rows) return;
    _mark(r * _cols + c);
  }
}
