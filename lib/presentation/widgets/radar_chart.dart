import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/board_theme.dart';

/// Gráfico radial para las dimensiones de la rúbrica (0 a 100).
class RadarChart extends StatelessWidget {
  const RadarChart({super.key, required this.labels, required this.values, this.size = 240});

  final List<String> labels;
  final List<int> values;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rúbrica: ${[for (var i = 0; i < labels.length; i++) '${labels[i]} ${values[i]}'].join(', ')}',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RadarPainter(labels, values)),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.labels, this.values);

  final List<String> labels;
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final n = labels.length;
    if (n < 3) return;
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 34;
    final grid = Paint()
      ..color = BoardColors.trace
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    Offset point(int i, double r) {
      final angle = -math.pi / 2 + 2 * math.pi * i / n;
      return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    }

    for (final level in [0.25, 0.5, 0.75, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = point(i, radius * level);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, grid);
    }
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, point(i, radius), grid);
    }
    final data = Path();
    for (var i = 0; i < n; i++) {
      final p = point(i, radius * (values[i].clamp(0, 100) / 100.0));
      if (i == 0) {
        data.moveTo(p.dx, p.dy);
      } else {
        data.lineTo(p.dx, p.dy);
      }
    }
    data.close();
    canvas.drawPath(data, Paint()..color = BoardColors.signal.withOpacity(0.25));
    canvas.drawPath(
      data,
      Paint()
        ..color = BoardColors.signal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < n; i++) {
      final p = point(i, radius * (values[i].clamp(0, 100) / 100.0));
      canvas.drawCircle(p, 3, Paint()..color = BoardColors.signal);
      final lp = point(i, radius + 20);
      final tp = TextPainter(
        text: TextSpan(
          text: '${labels[i]}\n${values[i]}',
          style: const TextStyle(color: BoardColors.silkDim, fontSize: 10.5, height: 1.2),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.values != values || old.labels != labels;
}
