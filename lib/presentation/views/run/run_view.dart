import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../../core/format.dart';
import '../../../domain/model/mission.dart';
import '../../../domain/model/sim_result.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../../widgets/scope_chart.dart';
import '../report/report_view.dart';

/// Reproduce la simulación en un osciloscopio y muestra las métricas clave.
class RunView extends ConsumerStatefulWidget {
  const RunView({super.key, this.playback = const Duration(seconds: 6)});

  final Duration playback;

  @override
  ConsumerState<RunView> createState() => _RunViewState();
}

class _RunViewState extends ConsumerState<RunView> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: widget.playback)..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      if (_anim.isAnimating) {
        _anim.stop();
      } else if (_anim.value >= 1.0) {
        _anim.forward(from: 0);
      } else {
        _anim.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(benchProvider);
    final run = state?.lastRun;
    if (state == null || run == null) {
      return const Scaffold(body: LoadingView(message: 'Simulando…'));
    }
    final m = state.mission;
    final sim = run.sim;
    final met = sim.metrics;
    return Scaffold(
      appBar: AppBar(title: Text('${m.code} · Simulación')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => ScopeChart(
                series: sim.series,
                mission: m,
                setpoint: run.design.logic.setpoint,
                progress: _anim.value,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: _anim.isAnimating ? 'Pausar' : 'Reproducir',
                  onPressed: _togglePlay,
                  icon: Icon(_anim.isAnimating ? Icons.pause_circle_outline : Icons.play_circle_outline),
                ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (context, _) => Slider(
                      value: _anim.value,
                      onChanged: (v) => setState(() {
                        _anim.stop();
                        _anim.value = v;
                      }),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _anim,
                  builder: (context, _) => Text(
                    fmtClock(m.horizonS * _anim.value),
                    style: BoardTheme.mono.copyWith(color: BoardColors.silkDim, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const _Legend(),
          if (m.events.isNotEmpty) ...[
            const SectionTitle('Eventos'),
            for (var i = 0; i < m.events.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: Text(
                  '${i + 1}. ${m.events[i].label} (${fmtClock(m.events[i].atS)})',
                  style: TextStyle(
                    fontSize: 13,
                    color: m.events[i].type == EventType.linkOutage ? BoardColors.hint : BoardColors.warn,
                  ),
                ),
              ),
          ],
          if (sim.events.any((e) => e.kind == SimEventKind.pinDamage))
            BoardPanel(
              borderColor: BoardColors.crit,
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_outlined, color: BoardColors.crit),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'A los ${fmtClock(sim.events.firstWhere((e) => e.kind == SimEventKind.pinDamage).t)} el pin del '
                      'controlador se dañó al intentar mover la carga directamente.',
                    ),
                  ),
                ],
              ),
            ),
          const SectionTitle('Métricas'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.0,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricTile(
                  label: 'Tiempo en la banda',
                  value: fmtPct(met.timeInBandPct, 1),
                  color: met.timeInBandPct >= m.requirements.minTimeInBandPct ? BoardColors.ok : BoardColors.crit,
                  caption: 'mínimo ${fmtCompact(m.requirements.minTimeInBandPct)} %',
                ),
                MetricTile(
                  label: 'Alerta remota',
                  value: met.alarmLatencyS == null ? 'No hizo falta' : fmtDuration(met.alarmLatencyS!),
                  color: _latencyColor(met.alarmLatencyS, m.requirements.maxAlarmLatencyS),
                  caption: 'máximo ${fmtDuration(m.requirements.maxAlarmLatencyS)}',
                ),
                MetricTile(
                  label: 'Reportes entregados',
                  value: '${met.delivered}/${met.expected}',
                  color: met.deliveredPct >= m.requirements.minDeliveryPct ? BoardColors.ok : BoardColors.crit,
                  caption: '${fmtPct(met.deliveredPct)} · ${met.lost} perdidos',
                ),
                MetricTile(
                  label: 'Conmutaciones',
                  value: '${fmtNum(met.switchesPerHour, 1)}/h',
                  caption: sim.wiring.relayLike ? 'relé o contactor' : 'estado sólido',
                ),
                MetricTile(
                  label: 'Energía diaria',
                  value: '${fmtNum(met.energyWhDay, 1)} Wh',
                  caption: met.autonomyDays == null
                      ? 'con red eléctrica'
                      : 'autonomía ${met.autonomyDays! >= 999 ? 'indefinida' : '${fmtNum(met.autonomyDays!, 1)} días'}',
                ),
                MetricTile(
                  label: 'Error de medición',
                  value: met.rmsError == null ? 'sin datos' : '${fmtCompact(met.rmsError!, maxDecimals: 2)} ${m.unit}',
                  caption: 'RMS lectura − real',
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Ver el informe del evaluador'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ReportView())),
        ),
      ),
    );
  }

  Color _latencyColor(double? latency, double max) {
    if (latency == null) return BoardColors.silk;
    return latency <= max ? BoardColors.ok : BoardColors.crit;
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String t, {bool dashed = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 16, height: dashed ? 2 : 3, color: c),
            const SizedBox(width: 6),
            Text(t, style: const TextStyle(fontSize: 12, color: BoardColors.silkDim)),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Wrap(
        spacing: 14,
        runSpacing: 6,
        children: [
          item(BoardColors.truth, 'Valor real'),
          item(BoardColors.signal, 'Lectura del sensor'),
          item(BoardColors.ok.withOpacity(0.5), 'Banda permitida'),
          item(BoardColors.copper, 'Consigna / salida', dashed: true),
          item(BoardColors.crit, 'Umbral de alerta', dashed: true),
        ],
      ),
    );
  }
}
