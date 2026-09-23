import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/board_theme.dart';
import '../../core/format.dart';
import '../../domain/model/mission.dart';
import '../../domain/model/sim_result.dart';

/// Pantalla de osciloscopio: valor real, lectura del sensor, banda, umbral de
/// alarma, eventos de la misión y salida del actuador.
class ScopeChart extends StatelessWidget {
  const ScopeChart({
    super.key,
    required this.series,
    required this.mission,
    required this.setpoint,
    this.progress = 1.0,
    this.height = 280,
  });

  final SimSeries series;
  final Mission mission;
  final double setpoint;
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Gráfico de ${mission.variableLabel} en el tiempo con la banda permitida y la salida del actuador.',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ScopePainter(series: series, mission: mission, setpoint: setpoint, progress: progress),
        ),
      ),
    );
  }
}

class _ScopePainter extends CustomPainter {
  _ScopePainter({required this.series, required this.mission, required this.setpoint, required this.progress});

  final SimSeries series;
  final Mission mission;
  final double setpoint;
  final double progress;

  static const _left = 44.0;
  static const _right = 8.0;
  static const _top = 18.0;
  static const _bottom = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = series.length;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = BoardColors.maskDeep);
    if (n < 2) return;

    final stripH = size.height * 0.14;
    final plot = Rect.fromLTRB(_left, _top, size.width - _right, size.height - _bottom - stripH - 6);
    final strip = Rect.fromLTRB(_left, plot.bottom + 6, size.width - _right, size.height - _bottom);

    // ---------- rango vertical ----------
    var lo = math.min(mission.band.low, mission.alarm.threshold);
    var hi = math.max(mission.band.high, mission.alarm.threshold);
    for (final v in series.x) {
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    for (final v in series.m) {
      if (v == null) continue;
      lo = math.min(lo, v);
      hi = math.max(hi, v);
    }
    final span = math.max(hi - lo, 1e-6);
    lo -= span * 0.08;
    hi += span * 0.08;
    final t0 = series.t.first;
    final t1 = mission.horizonS;
    double px(double t) => plot.left + (t - t0) / (t1 - t0) * plot.width;
    double py(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;

    // ---------- cuadrícula ----------
    final gridPaint = Paint()
      ..color = BoardColors.scopeGrid
      ..strokeWidth = 1;
    for (var i = 0; i <= 10; i++) {
      final x = plot.left + plot.width * i / 10;
      canvas.drawLine(Offset(x, plot.top), Offset(x, strip.bottom), gridPaint);
    }
    for (var i = 0; i <= 6; i++) {
      final y = plot.top + plot.height * i / 6;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }

    // ---------- eventos ----------
    var idx = 1;
    for (final e in mission.events) {
      final x0 = px(e.atS).clamp(plot.left, plot.right);
      final x1 = px(math.min(e.endS, t1)).clamp(plot.left, plot.right);
      final color = e.type == EventType.linkOutage ? BoardColors.hint : BoardColors.warn;
      canvas.drawRect(Rect.fromLTRB(x0, plot.top, math.max(x1, x0 + 2), strip.bottom), Paint()..color = color.withOpacity(0.10));
      _label(canvas, '$idx', Offset(x0 + 3, 2), color, 10.5, bold: true);
      idx++;
    }

    // ---------- banda, consigna y umbral ----------
    final bandRect = Rect.fromLTRB(plot.left, py(mission.band.high), plot.right, py(mission.band.low));
    canvas.drawRect(bandRect.intersect(plot), Paint()..color = BoardColors.ok.withOpacity(0.12));
    _dashed(canvas, Offset(plot.left, py(setpoint)), Offset(plot.right, py(setpoint)), BoardColors.copper.withOpacity(0.7));
    _dashed(canvas, Offset(plot.left, py(mission.alarm.threshold)), Offset(plot.right, py(mission.alarm.threshold)),
        BoardColors.crit.withOpacity(0.85));

    // ---------- trazos hasta el punto de reproducción ----------
    final last = math.max(1, (progress.clamp(0.0, 1.0) * (n - 1)).round());
    canvas.save();
    canvas.clipRect(plot);
    final truth = Path()..moveTo(px(series.t[0]), py(series.x[0]));
    for (var i = 1; i <= last; i++) {
      truth.lineTo(px(series.t[i]), py(series.x[i]));
    }
    final meas = Path();
    var started = false;
    double? prevY;
    for (var i = 0; i <= last; i++) {
      final v = series.m[i];
      if (v == null) {
        started = false;
        continue;
      }
      final x = px(series.t[i]);
      final y = py(v);
      if (!started) {
        meas.moveTo(x, y);
        started = true;
      } else {
        meas.lineTo(x, prevY ?? y);
        meas.lineTo(x, y);
      }
      prevY = y;
    }
    canvas.drawPath(
      meas,
      Paint()
        ..color = BoardColors.signal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
    canvas.drawPath(
      truth,
      Paint()
        ..color = BoardColors.truth
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    canvas.restore();

    // ---------- salida del actuador ----------
    canvas.drawRect(strip, Paint()..color = BoardColors.mask);
    final barW = math.max(1.0, strip.width / n);
    final act = Paint()..color = BoardColors.copper;
    for (var i = 0; i <= last; i++) {
      final u = series.u[i].clamp(0.0, 1.0);
      if (u <= 0) continue;
      final h = strip.height * u;
      canvas.drawRect(Rect.fromLTWH(px(series.t[i]), strip.bottom - h, barW, h), act);
    }
    _label(canvas, 'Salida', Offset(4, strip.top + strip.height / 2 - 7), BoardColors.copper, 10);

    // ---------- cursor ----------
    if (progress < 1.0) {
      final cx = px(series.t[last]);
      canvas.drawLine(Offset(cx, plot.top), Offset(cx, strip.bottom), Paint()..color = BoardColors.silk.withOpacity(0.5));
    }

    // ---------- ejes ----------
    final d = mission.decimals;
    _label(canvas, fmtNum(hi, d), Offset(2, plot.top - 6), BoardColors.silkDim, 10);
    _label(canvas, fmtNum((hi + lo) / 2, d), Offset(2, plot.center.dy - 6), BoardColors.silkDim, 10);
    _label(canvas, fmtNum(lo, d), Offset(2, plot.bottom - 12), BoardColors.silkDim, 10);
    for (var i = 0; i <= 4; i++) {
      final t = t0 + (t1 - t0) * i / 4;
      final text = fmtClock(t);
      final x = plot.left + plot.width * i / 4;
      _label(canvas, text, Offset(i == 4 ? x - 30 : (i == 0 ? x : x - 15), size.height - _bottom + 5), BoardColors.silkDim, 10);
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const dash = 6.0;
    const gap = 4.0;
    final total = (b - a).distance;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final s = a + dir * d;
      final e = a + dir * math.min(d + dash, total);
      canvas.drawLine(s, e, paint);
      d += dash + gap;
    }
  }

  void _label(Canvas canvas, String text, Offset at, Color color, double size, {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _ScopePainter old) =>
      old.progress != progress || old.series != series || old.setpoint != setpoint;
}
