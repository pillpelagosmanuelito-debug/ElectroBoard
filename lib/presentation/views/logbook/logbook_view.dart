import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../../core/format.dart';
import '../../../domain/model/finding.dart';
import '../../../domain/model/learning.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/radar_chart.dart';
import '../mission/mission_brief_view.dart';

/// Bitácora: evolución del estudiante por competencia y por proyecto.
class LogbookView extends ConsumerWidget {
  const LogbookView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(logbookProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitácora'),
        actions: [
          IconButton(
            tooltip: 'Borrar el avance',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _confirmReset(context, ref),
          ),
        ],
      ),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (s) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SectionTitle('Competencias'),
            BoardPanel(
              child: Column(
                children: [
                  for (final c in Competency.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: Text(c.label)),
                          Expanded(
                            flex: 4,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (s.competencies[c] ?? 0) / 100,
                                minHeight: 6,
                                backgroundColor: BoardColors.maskDeep,
                                color: s.competencies[c] == null ? BoardColors.trace : scoreColor(s.competencies[c]!),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: Text(s.competencies[c]?.toString() ?? '—',
                                textAlign: TextAlign.right, style: BoardTheme.mono.copyWith(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    s.totalAttempts == 0
                        ? 'Aún no hay intentos. Las competencias se calculan con el mejor intento de cada proyecto.'
                        : 'Calculadas con el mejor intento de cada proyecto (${s.totalAttempts} intentos en total).',
                    style: const TextStyle(color: BoardColors.silkDim, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (s.dimensions.isNotEmpty)
              Center(
                child: RadarChart(
                  labels: [for (final d in Dimension.values) d.label],
                  values: [for (final d in Dimension.values) s.dimensions[d] ?? 0],
                ),
              ),
            BoardPanel(
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined, color: BoardColors.signal),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Preguntas de control respondidas correctamente: ${s.lessonsCorrect} de ${s.lessonsTotal}.'),
                  ),
                ],
              ),
            ),
            const SectionTitle('Proyectos'),
            for (final log in s.missions)
              BoardPanel(
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => MissionBriefView(missionId: log.mission.id))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(log.mission.code, style: BoardTheme.mono.copyWith(color: BoardColors.copper)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(log.mission.title, style: const TextStyle(fontWeight: FontWeight.w700))),
                        StatusLed(
                          color: log.best?.passed == true
                              ? BoardColors.ok
                              : (log.attempts.isEmpty ? BoardColors.trace : BoardColors.warn),
                          glow: log.attempts.isNotEmpty,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (log.attempts.isEmpty)
                      const Text('Sin intentos todavía.', style: TextStyle(color: BoardColors.silkDim, fontSize: 12.5))
                    else ...[
                      Text(
                        '${log.attempts.length} ${log.attempts.length == 1 ? 'intento' : 'intentos'} · '
                        'mejor ${log.best!.overall} · último ${fmtDate(DateTime.fromMillisecondsSinceEpoch(log.attempts.first.timestampMs))}',
                        style: const TextStyle(color: BoardColors.silkDim, fontSize: 12.5),
                      ),
                      if (log.trend.length > 1) ...[
                        const SizedBox(height: 8),
                        SizedBox(height: 36, width: double.infinity, child: CustomPaint(painter: _SparkPainter(log.trend))),
                      ],
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar todo el avance?'),
        content: const Text('Se eliminarán los intentos, las respuestas de las lecciones, las pistas y los borradores. '
            'Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BoardColors.crit),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(progressProvider.notifier).resetAll();
      ref.invalidate(benchProvider);
    }
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final path = Path();
    final dx = size.width / (values.length - 1);
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - size.height * (values[i].clamp(0, 100) / 100.0);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawLine(Offset(0, size.height * 0.15), Offset(size.width, size.height * 0.15),
        Paint()..color = BoardColors.trace);
    canvas.drawPath(
      path,
      Paint()
        ..color = BoardColors.signal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final last = values.last.clamp(0, 100);
    canvas.drawCircle(Offset(size.width, size.height - size.height * last / 100.0), math.max(3.0, size.height / 12),
        Paint()..color = scoreColor(values.last));
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}
