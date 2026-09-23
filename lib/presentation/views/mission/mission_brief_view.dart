import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../../core/format.dart';
import '../../../domain/model/content_bundle.dart';
import '../../../domain/model/mission.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../bench/bench_view.dart';
import '../learn/lesson_view.dart';

/// Ficha de la misión: contexto, requisitos y condiciones de prueba.
class MissionBriefView extends ConsumerWidget {
  const MissionBriefView({super.key, required this.missionId});

  final String missionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(contentProvider);
    final progress = ref.watch(progressProvider);
    return content.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(body: ErrorView(error: e)),
      data: (c) {
        final m = c.mission(missionId);
        final best = progress.bestFor(m.id);
        return Scaffold(
          appBar: AppBar(title: Text('${m.code} · Ficha del proyecto')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 16, color: BoardColors.silkDim),
                        const SizedBox(width: 4),
                        Expanded(child: Text(m.place, style: const TextStyle(color: BoardColors.silkDim))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      SpecChip(m.difficulty, icon: Icons.signal_cellular_alt),
                      for (final mod in m.modules) SpecChip(c.module(mod).title, color: BoardColors.signal),
                    ]),
                  ],
                ),
              ),
              const SectionTitle('El problema'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(m.story, style: const TextStyle(height: 1.45)),
              ),
              BoardPanel(
                borderColor: BoardColors.copper,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.flag_outlined, color: BoardColors.copper),
                    const SizedBox(width: 10),
                    Expanded(child: Text(m.goal, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35))),
                  ],
                ),
              ),
              const SectionTitle('Requisitos que se evaluarán'),
              _RequirementsTable(mission: m),
              const SectionTitle('Lugar e infraestructura'),
              BoardPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.site.description, style: const TextStyle(height: 1.4)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      SpecChip(m.requirements.mainsAvailable ? 'Hay red eléctrica' : 'Sin red eléctrica',
                          icon: Icons.power_outlined),
                      SpecChip('Ambiente ${m.environmentLabel.split(',').first}', icon: Icons.thermostat),
                      if (m.site.distanceM > 0) SpecChip('Destino a ${fmtCompact(m.site.distanceM)} m', icon: Icons.straighten),
                    ]),
                  ],
                ),
              ),
              const SectionTitle('Condiciones de la prueba'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'La simulación dura ${fmtDuration(m.horizonS)} e incluye estos eventos. El evaluador empieza a medir '
                  'a los ${fmtDuration(m.settleS)}, cuando termina el arranque.',
                  style: const TextStyle(color: BoardColors.silkDim, fontSize: 13, height: 1.4),
                ),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < m.events.length; i++) _EventRow(index: i + 1, event: m.events[i]),
              const SectionTitle('Lecciones relacionadas'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final id in m.lessonIds)
                      if (c.lesson(id) != null)
                        ActionChip(
                          avatar: Icon(
                            progress.lessonAnswered(id) ? Icons.check_circle : Icons.menu_book_outlined,
                            size: 16,
                            color: progress.lessonAnswered(id) ? BoardColors.ok : BoardColors.silkDim,
                          ),
                          label: Text(c.lesson(id)!.title),
                          onPressed: () => Navigator.of(context)
                              .push(MaterialPageRoute(builder: (_) => LessonView(lessonId: id))),
                        ),
                  ],
                ),
              ),
              if (best != null) ...[
                const SectionTitle('Tu mejor intento'),
                BoardPanel(
                  child: Row(
                    children: [
                      StatusLed(color: best.passed ? BoardColors.ok : BoardColors.warn),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          best.passed
                              ? 'Aprobado con ${best.overall} puntos.'
                              : '${best.overall} puntos, con ${best.criticalCount} ${best.criticalCount == 1 ? 'falla crítica' : 'fallas críticas'}.',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              icon: const Icon(Icons.developer_board),
              label: const Text('Abrir el tablero de diseño'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: () => _openBench(context, ref, c, m),
            ),
          ),
        );
      },
    );
  }

  void _openBench(BuildContext context, WidgetRef ref, ContentBundle c, Mission m) {
    ref.read(benchProvider.notifier).open(c, m);
    Navigator.of(context).push(
      MaterialPageRoute(settings: const RouteSettings(name: BenchView.routeName), builder: (_) => const BenchView()),
    );
  }
}

class _RequirementsTable extends StatelessWidget {
  const _RequirementsTable({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final r = m.requirements;
    final u = m.unit;
    String v(double x) => '${fmtNum(x, m.decimals)} $u';
    final rows = <(String, String)>[
      ('Banda permitida', '${v(m.band.low)} a ${v(m.band.high)}'),
      ('Tiempo dentro de la banda', '≥ ${fmtCompact(r.minTimeInBandPct)} %'),
      ('Alerta: ${m.alarm.label.toLowerCase()}', '${m.alarm.up ? '>' : '<'} ${v(m.alarm.threshold)} en ≤ ${fmtDuration(r.maxAlarmLatencyS)}'),
      if (r.maxActionLatencyS > 0) ('Tiempo máximo de parada', fmtDuration(r.maxActionLatencyS)),
      if (r.requiresLatch) ('Rearme', 'Manual (la parada no se libera sola)'),
      ('Reporte de datos', 'Cada ${fmtInterval(r.reportEveryS)}, ≥ ${fmtCompact(r.minDeliveryPct)} % entregado'),
      if (r.minAutonomyDays > 0) ('Autonomía sin sol', '≥ ${fmtCompact(r.minAutonomyDays)} días'),
      ('Rango que debe ver el sensor', '${fmtCompact(m.sensorRangeMin)} a ${fmtCompact(m.sensorRangeMax)} $u'),
      ('Presupuesto de hardware', '≤ ${fmtPen(r.budgetPen)}'),
    ];
    return BoardPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: BoardColors.trace)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: Text(rows[i].$1, style: const TextStyle(color: BoardColors.silkDim, fontSize: 13))),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 6,
                    child: Text(rows[i].$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.index, required this.event});

  final int index;
  final MissionEvent event;

  @override
  Widget build(BuildContext context) {
    final color = event.type == EventType.linkOutage ? BoardColors.hint : BoardColors.warn;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color)),
            child: Text('$index', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.label, style: const TextStyle(height: 1.3)),
                Text(
                  'Desde ${fmtClock(event.atS)} · dura ${fmtDuration(event.durS)}',
                  style: BoardTheme.mono.copyWith(color: BoardColors.silkDim, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
