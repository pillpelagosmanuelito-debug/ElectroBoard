import 'package:flutter/material.dart';

import '../../app/board_theme.dart';
import '../../domain/model/catalog.dart';
import 'common.dart';

/// Datos de una ranura del tablero.
class SlotInfo {
  const SlotInfo({required this.title, required this.icon, this.value, this.detail});

  final String title;
  final IconData icon;
  final String? value;
  final String? detail;

  bool get filled => value != null;
}

/// Tablero de bloques: alimentación arriba, cadena sensor → controlador →
/// actuador al centro, comunicación y lógica abajo. Las pistas de cobre se
/// iluminan cuando ambos extremos están conectados.
class BlockBoard extends StatelessWidget {
  const BlockBoard({
    super.key,
    required this.slots,
    required this.logic,
    required this.destination,
    required this.onSlotTap,
    required this.onLogicTap,
  });

  final Map<PartKind, SlotInfo> slots;
  final SlotInfo logic;
  final String destination;
  final void Function(PartKind kind) onSlotTap;
  final VoidCallback onLogicTap;

  static const _gap = 10.0;
  static const _powerH = 70.0;
  static const _rowH = 128.0;
  static const _commH = 80.0;
  static const _logicH = 84.0;
  static const _vGap = 26.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cw = (w - 2 * _gap) / 3;
      const yRow = _powerH + _vGap;
      const yComm = yRow + _rowH + _vGap;
      const yLogic = yComm + _commH + _vGap;
      const total = yLogic + _logicH;

      final rects = <PartKind, Rect>{
        PartKind.power: Rect.fromLTWH(0, 0, w, _powerH),
        PartKind.sensor: Rect.fromLTWH(0, yRow, cw, _rowH),
        PartKind.controller: Rect.fromLTWH(cw + _gap, yRow, cw, _rowH),
        PartKind.actuator: Rect.fromLTWH(2 * (cw + _gap), yRow, cw, _rowH),
        PartKind.comm: Rect.fromLTWH(cw + _gap, yComm, cw * 2 + _gap, _commH),
      };
      final logicRect = Rect.fromLTWH(0, yLogic, w, _logicH);

      return SizedBox(
        height: total,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TracePainter(
                  rects: rects,
                  logicRect: logicRect,
                  filled: {for (final e in slots.entries) e.key: e.value.filled},
                ),
              ),
            ),
            for (final kind in PartKind.values)
              Positioned.fromRect(
                rect: rects[kind]!,
                child: _SlotCard(
                  info: slots[kind]!,
                  compact: kind == PartKind.power || kind == PartKind.comm,
                  onTap: () => onSlotTap(kind),
                ),
              ),
            Positioned(
              left: 0,
              top: yComm,
              width: cw,
              height: _commH,
              child: _CloudNode(label: destination),
            ),
            Positioned.fromRect(
              rect: logicRect,
              child: _SlotCard(info: logic, compact: true, onTap: onLogicTap, accent: BoardColors.signal),
            ),
          ],
        ),
      );
    });
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({required this.info, required this.onTap, this.compact = false, this.accent});

  final SlotInfo info;
  final VoidCallback onTap;
  final bool compact;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? BoardColors.copper;
    final filled = info.filled;
    return Semantics(
      button: true,
      label: '${info.title}: ${info.value ?? 'sin elegir'}',
      child: Material(
        color: filled ? BoardColors.maskHigh : BoardColors.maskDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: filled ? color : BoardColors.trace, width: filled ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: compact ? _row(color, filled) : _column(color, filled),
          ),
        ),
      ),
    );
  }

  Widget _row(Color color, bool filled) {
    return Row(
      children: [
        Icon(info.icon, color: filled ? color : BoardColors.silkDim, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(info.title.toUpperCase(),
                  style: const TextStyle(fontSize: 10, letterSpacing: 1.1, color: BoardColors.silkDim)),
              const SizedBox(height: 2),
              Text(
                info.value ?? 'Toca para elegir',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: filled ? BoardColors.silk : BoardColors.silkDim,
                ),
              ),
              if (info.detail != null)
                Text(info.detail!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: BoardColors.silkDim)),
            ],
          ),
        ),
        Icon(filled ? Icons.edit_outlined : Icons.add_circle_outline, size: 18, color: BoardColors.silkDim),
      ],
    );
  }

  Widget _column(Color color, bool filled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(info.icon, color: filled ? color : BoardColors.silkDim, size: 20),
            const Spacer(),
            StatusLed(color: filled ? BoardColors.ok : BoardColors.trace, size: 7, glow: filled),
          ],
        ),
        const SizedBox(height: 6),
        Text(info.title.toUpperCase(), style: const TextStyle(fontSize: 9.5, letterSpacing: 1.0, color: BoardColors.silkDim)),
        const SizedBox(height: 2),
        Expanded(
          child: Text(
            info.value ?? 'Toca para elegir',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: filled ? BoardColors.silk : BoardColors.silkDim,
            ),
          ),
        ),
        if (info.detail != null)
          Text(info.detail!, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: BoardColors.silkDim)),
      ],
    );
  }
}

class _CloudNode extends StatelessWidget {
  const _CloudNode({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: BoardColors.trace),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.person_pin_circle_outlined, color: BoardColors.silkDim, size: 18),
          const SizedBox(height: 2),
          Text(label, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: BoardColors.silk)),
        ],
      ),
    );
  }
}

class _TracePainter extends CustomPainter {
  _TracePainter({required this.rects, required this.logicRect, required this.filled});

  final Map<PartKind, Rect> rects;
  final Rect logicRect;
  final Map<PartKind, bool> filled;

  @override
  void paint(Canvas canvas, Size size) {
    Paint traceFor(bool active) => Paint()
      ..color = active ? BoardColors.copper : BoardColors.trace
      ..strokeWidth = active ? 3 : 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    void via(Offset p, bool active) {
      canvas.drawCircle(p, 4.5, Paint()..color = active ? BoardColors.copper : BoardColors.trace);
      canvas.drawCircle(p, 1.8, Paint()..color = BoardColors.maskDeep);
    }

    bool on(PartKind a, PartKind b) => (filled[a] ?? false) && (filled[b] ?? false);

    final power = rects[PartKind.power]!;
    final sensor = rects[PartKind.sensor]!;
    final ctrl = rects[PartKind.controller]!;
    final act = rects[PartKind.actuator]!;
    final comm = rects[PartKind.comm]!;

    // Bus de alimentación hacia cada bloque de la fila central.
    for (final k in [PartKind.sensor, PartKind.controller, PartKind.actuator]) {
      final r = rects[k]!;
      final a = Offset(r.center.dx, power.bottom);
      final b = Offset(r.center.dx, r.top);
      final active = on(PartKind.power, k);
      canvas.drawLine(a, b, traceFor(active));
      via(a, active);
    }
    // Señal: sensor → controlador → actuador.
    final y = sensor.center.dy;
    final s1 = on(PartKind.sensor, PartKind.controller);
    canvas.drawLine(Offset(sensor.right, y), Offset(ctrl.left, y), traceFor(s1));
    final s2 = on(PartKind.controller, PartKind.actuator);
    canvas.drawLine(Offset(ctrl.right, y), Offset(act.left, y), traceFor(s2));
    // Controlador → comunicación.
    final s3 = on(PartKind.controller, PartKind.comm);
    final cx = ctrl.center.dx;
    canvas.drawLine(Offset(cx, ctrl.bottom), Offset(cx, comm.top), traceFor(s3));
    via(Offset(cx, comm.top), s3);
    // Comunicación → destino (a la izquierda).
    canvas.drawLine(Offset(comm.left, comm.center.dy), Offset(sensor.right - 4, comm.center.dy),
        traceFor(filled[PartKind.comm] ?? false));
    // Lógica (firmware dentro del controlador).
    final ctrlOn = filled[PartKind.controller] ?? false;
    final dash = traceFor(ctrlOn)..strokeWidth = 1.5;
    var yy = comm.bottom;
    while (yy < logicRect.top) {
      canvas.drawLine(Offset(comm.right - 24, yy), Offset(comm.right - 24, yy + 4), dash);
      yy += 8;
    }
  }

  @override
  bool shouldRepaint(covariant _TracePainter old) => true;
}
