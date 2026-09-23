import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/board_theme.dart';
import 'common.dart';

/// Anillo de puntaje de 0 a 100.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, this.size = 116, this.caption = 'de 100'});

  final int score;
  final double size;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(score);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(score / 100.0, color),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$score', style: BoardTheme.mono.copyWith(fontSize: size * 0.28, fontWeight: FontWeight.w800, color: color)),
              Text(caption, style: const TextStyle(color: BoardColors.silkDim, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 7;
    final bg = Paint()
      ..color = BoardColors.maskDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bg);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction || old.color != color;
}
