import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../../core/format.dart';
import '../../../domain/model/catalog.dart';
import '../../providers.dart';
import '../../widgets/block_board.dart';
import '../../widgets/common.dart';
import '../../widgets/score_ring.dart';
import '../firmware/firmware_view.dart';
import '../report/report_view.dart';
import '../run/run_view.dart';
import 'logic_editor_view.dart';
import 'part_picker_sheet.dart';

/// Tablero de diseño: el estudiante arma el sistema bloque por bloque.
class BenchView extends ConsumerWidget {
  const BenchView({super.key});

  static const routeName = '/tablero';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchProvider);
    if (state == null) {
      return const Scaffold(body: LoadingView(message: 'Preparando el tablero…'));
    }
    final vm = ref.read(benchProvider.notifier);
    final progress = ref.watch(progressProvider);
    final m = state.mission;
    final d = state.design;
    final passed = progress.passed(m.id);

    SlotInfo slot(PartKind kind) {
      final part = state.selected(kind);
      return SlotInfo(
        title: partTitle(kind),
        icon: partIcon(kind),
        value: part?.name,
        detail: part == null ? null : _slotDetail(part),
      );
    }

    final lg = d.logic;
    final logicSlot = SlotInfo(
      title: 'Lógica y firmware',
      icon: Icons.code,
      value: '${lg.algorithm.label} · muestreo ${fmtInterval(lg.samplingS)}',
      detail: '${lg.firmware.label}${lg.retry ? ' · reenvío' : ''}${lg.lowPower ? ' · bajo consumo' : ''}',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${m.code} · Tablero'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Más opciones',
            onSelected: (v) => _onMenu(context, ref, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'reset', child: Text('Empezar de nuevo')),
              PopupMenuItem(
                value: 'reference',
                enabled: passed,
                child: Text(passed ? 'Ver la solución de referencia' : 'Solución de referencia (al aprobar)'),
              ),
              PopupMenuItem(value: 'firmware', enabled: d.isComplete, child: const Text('Ver el firmware generado')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _BudgetBar(
            cost: state.estimatedCost,
            budget: m.requirements.budgetPen,
            missing: state.missingSlots.map(partTitle).toList(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: BlockBoard(
              slots: {for (final k in PartKind.values) k: slot(k)},
              logic: logicSlot,
              destination: _destination(m.site.infra),
              onSlotTap: (kind) => showPartPicker(context, kind),
              onLogicTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogicEditorView())),
            ),
          ),
          BoardPanel(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: d.conditioning,
              onChanged: vm.setConditioning,
              title: const Text('Acondicionamiento de señal'),
              subtitle: const Text(
                'Adaptador de nivel lógico o divisor resistivo entre el sensor y el controlador (+ S/ 4).',
                style: TextStyle(fontSize: 12.5, color: BoardColors.silkDim),
              ),
            ),
          ),
          if (state.lastRun != null) _LastRunPanel(onOpen: () => _openReport(context)),
          const SectionTitle('Pistas'),
          for (var i = 0; i < m.hints.length; i++)
            _HintTile(
              index: i,
              text: m.hints[i],
              revealed: progress.hintRevealed(m.id, i),
              onReveal: () => ref.read(progressProvider.notifier).revealHint(m.id, i),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(d.isComplete ? 'Simular y evaluar' : 'Completa los ${state.missingSlots.length} bloques restantes'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: d.isComplete ? () => _run(context, ref) : null,
        ),
      ),
    );
  }

  String _destination(List<String> infra) {
    if (infra.contains('router')) return 'Router Wi-Fi';
    if (infra.contains('gateway')) return 'Gateway LoRaWAN';
    if (infra.contains('cable')) return 'PLC / SCADA';
    if (infra.contains('coverage')) return 'Red celular';
    return 'Responsable';
  }

  String _slotDetail(PartSpec part) {
    if (part is SensorSpec) return interfaceLabel(part.interface);
    if (part is ControllerSpec) return part.adcBits > 0 ? 'Lógica ${fmtVolts(part.logicV)}' : 'Sin ADC';
    if (part is ActuatorSpec) return driverLabel(part.driver);
    if (part is CommSpec) return part.isNone ? 'Sin enlace' : 'Alcance ${_range(part.rangeM)}';
    if (part is PowerSpec) return fmtRails(part.rails);
    return '';
  }

  String _range(double m) {
    if (m >= 1000000) return 'con cobertura';
    if (m >= 1000) return '${fmtCompact(m / 1000, maxDecimals: 1)} km';
    return '${fmtCompact(m)} m';
  }

  void _run(BuildContext context, WidgetRef ref) {
    final outcome = ref.read(benchProvider.notifier).run();
    if (outcome == null) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RunView()));
  }

  void _openReport(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportView()));
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String value) async {
    final vm = ref.read(benchProvider.notifier);
    switch (value) {
      case 'reset':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('¿Empezar de nuevo?'),
            content: const Text('Se vaciarán los bloques y la lógica volverá a su configuración inicial. '
                'Tus intentos anteriores quedan guardados en la bitácora.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Vaciar tablero')),
            ],
          ),
        );
        if (ok == true) vm.resetDesign();
      case 'reference':
        vm.loadReference();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Se cargó la solución de referencia. Compárala con la tuya.')),
          );
        }
      case 'firmware':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FirmwareView()));
    }
  }
}

class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.cost, required this.budget, required this.missing});

  final double cost;
  final double budget;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final over = cost > budget;
    final color = over ? BoardColors.crit : BoardColors.copper;
    return Container(
      color: BoardColors.maskDeep,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Costo del hardware',
                    overflow: TextOverflow.ellipsis, style: TextStyle(color: BoardColors.silkDim, fontSize: 12.5)),
              ),
              const SizedBox(width: 8),
              Text('${fmtPen(cost)} / ${fmtPen(budget)}',
                  style: BoardTheme.mono.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: budget <= 0 ? 0 : (cost / budget).clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: BoardColors.maskHigh,
              color: color,
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Falta elegir: ${missing.join(', ').toLowerCase()}.',
                style: const TextStyle(color: BoardColors.silkDim, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class _LastRunPanel extends ConsumerWidget {
  const _LastRunPanel({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.watch(benchProvider)?.lastRun;
    if (run == null) return const SizedBox.shrink();
    final e = run.evaluation;
    return BoardPanel(
      onTap: onOpen,
      borderColor: e.passed ? BoardColors.ok : BoardColors.warn,
      child: Row(
        children: [
          ScoreRing(score: e.overall, size: 64, caption: ''),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.passed ? 'Último intento: aprobado' : 'Último intento: aún no cumple',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${e.criticalCount} críticos · ${e.warningCount} advertencias',
                    style: const TextStyle(color: BoardColors.silkDim, fontSize: 12.5)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: BoardColors.silkDim),
        ],
      ),
    );
  }
}

class _HintTile extends StatelessWidget {
  const _HintTile({required this.index, required this.text, required this.revealed, required this.onReveal});

  final int index;
  final String text;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return BoardPanel(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      onTap: revealed ? null : onReveal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(revealed ? Icons.lightbulb : Icons.lightbulb_outline, color: BoardColors.hint, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              revealed ? text : 'Pista ${index + 1}: toca para mostrarla',
              style: TextStyle(color: revealed ? BoardColors.silk : BoardColors.silkDim, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
