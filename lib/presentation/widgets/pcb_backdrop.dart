import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/board_theme.dart';

/// Fondo decorativo con pistas de cobre y vías, generado de forma determinista.
class PcbBackdrop extends StatelessWidget {
  const PcbBackdrop({super.key, required this.child, this.seed = 7, this.opacity = 0.55});

  final Widget child;
  final int seed;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PcbPainter(seed: seed, opacity: opacity),
      child: child,
    );
  }
}

class _PcbPainter extends CustomPainter {
  _PcbPainter({required this.seed, required this.opacity});

  final int seed;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final trace = Paint()
      ..color = BoardColors.trace.withOpacity(opacity)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final pad = Paint()..color = BoardColors.copperDim.withOpacity(opacity * 0.9);
    final hole = Paint()..color = BoardColors.maskDeep;
    const step = 22.0;
    final lines = (size.height / step).floor();
    for (var i = 0; i < lines; i++) {
      if (rnd.nextDouble() < 0.45) continue;
      final y = i * step + step / 2;
      var x = rnd.nextDouble() * size.width * 0.3;
      final path = Path()..moveTo(x, y);
      var cy = y;
      final segments = 2 + rnd.nextInt(3);
      for (var s = 0; s < segments; s++) {
        x += 30 + rnd.nextDouble() * size.width * 0.25;
        path.lineTo(x, cy);
        if (rnd.nextBool()) {
          final dy = (rnd.nextBool() ? 1 : -1) * step;
          x += step;
          cy += dy;
          path.lineTo(x, cy);
        }
      }
      canvas.drawPath(path, trace);
      canvas.drawCircle(Offset(x, cy), 4, pad);
      canvas.drawCircle(Offset(x, cy), 1.6, hole);
    }
  }

  @override
  bool shouldRepaint(covariant _PcbPainter old) => old.seed != seed || old.opacity != opacity;
}
