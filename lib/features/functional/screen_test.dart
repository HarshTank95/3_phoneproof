import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Full-screen solid colours for dead-pixel / uniformity inspection.
class DeadPixelTest extends StatefulWidget {
  final VoidCallback onAllSeen;
  const DeadPixelTest({super.key, required this.onAllSeen});

  @override
  State<DeadPixelTest> createState() => _DeadPixelTestState();
}

class _DeadPixelTestState extends State<DeadPixelTest> {
  static const _colors = [
    Color(0xFFFF0000),
    Color(0xFF00FF00),
    Color(0xFF0000FF),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];
  int _i = 0;

  void _next() {
    if (_i < _colors.length - 1) {
      setState(() => _i++);
      if (_i == _colors.length - 1) widget.onAllSeen();
    } else {
      setState(() => _i = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _next,
      child: Container(
        color: _colors[_i],
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 40),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Tap to change colour  (${_i + 1}/${_colors.length})',
              style: const TextStyle(color: Colors.white)),
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
