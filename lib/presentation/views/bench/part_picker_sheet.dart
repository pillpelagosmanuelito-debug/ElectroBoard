import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../../core/format.dart';
import '../../../domain/model/catalog.dart';
import '../../../domain/model/mission.dart';
import '../../providers.dart';
import '../../widgets/common.dart';

/// Abre el catálogo de componentes de una ranura del tablero.
Future<void> showPartPicker(BuildContext context, PartKind kind) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BoardColors.mask,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, controller) => _PartPicker(kind: kind, controller: controller),
    ),
  );
}

class _PartPicker extends ConsumerWidget {
  const _PartPicker({required this.kind, required this.controller});

  final PartKind kind;
  final ScrollController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchProvider);
    if (state == null) return const SizedBox.shrink();
    final pool = state.poolFor(kind);
    final selectedId = state.design.partId(kind);
    final controllerSpec = state.selected(PartKind.controller);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: BoardColors.trace, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Icon(partIcon(kind), color: BoardColors.copper),
              const SizedBox(width: 8),
              Text('Elige: ${partTitle(kind).toLowerCase()}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(_prompt(kind, state.mission),
              style: const TextStyle(color: BoardColors.silkDim, fontSize: 13, height: 1.35)),
        ),
        for (final part in pool)
          _PartCard(
            part: part,
            mission: state.mission,
            controller: controllerSpec is ControllerSpec ? controllerSpec : null,
            selected: part.id == selectedId,
            onTap: () {
              ref.read(benchProvider.notifier).selectPart(kind, part.id);
              Navigator.of(context).pop();
            },
          ),
      ],
    );
  }

  String _prompt(PartKind kind, Mission m) => switch (kind) {
        PartKind.sensor => 'Debe medir ${m.variableLabel.toLowerCase()} entre ${fmtCompact(m.sensorRangeMin)} y '
            '${fmtCompact(m.sensorRangeMax)} ${m.unit}, con exactitud suficiente para una banda de '
            '${fmtCompact(m.band.low)} a ${fmtCompact(m.band.high)} ${m.unit}.',
        PartKind.controller => 'Revisa la tensión lógica, el conversor analógico, la radio integrada y el consumo.',
        PartKind.actuator => 'Debe ${m.direction > 0 ? 'aumentar' : 'reducir'} ${m.variableLabel.toLowerCase()}. '
            'Fíjate en la etapa de potencia y en la tensión de la carga.',
        PartKind.comm => m.site.description,
        PartKind.power => m.requirements.mainsAvailable
            ? 'Hay red eléctrica. La fuente debe ofrecer las tensiones y la corriente de todos los bloques.'
            : 'No hay red eléctrica: el sistema debe funcionar con batería al menos '
                '${fmtCompact(m.requirements.minAutonomyDays)} días sin sol.',
      };
}

class _PartCard extends StatelessWidget {
  const _PartCard({
    required this.part,
    required this.mission,
    required this.controller,
    required this.selected,
    required this.onTap,
  });

  final PartSpec part;
  final Mission mission;
  final ControllerSpec? controller;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BoardPanel(
      onTap: onTap,
      borderColor: selected ? BoardColors.copper : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(part.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(_cost(), style: BoardTheme.mono.copyWith(color: BoardColors.copper, fontWeight: FontWeight.w700)),
            ],
          ),
          if (_subtitle() != null) ...[
            const SizedBox(height: 2),
            Text(_subtitle()!, style: const TextStyle(color: BoardColors.silkDim, fontSize: 12)),
          ],
          const SizedBox(height: 6),
          Text(part.summary, style: const TextStyle(fontSize: 13, height: 1.35)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _chips()),
          if (_notes() != null) ...[
            const SizedBox(height: 8),
            Text(_notes()!, style: const TextStyle(color: BoardColors.silkDim, fontSize: 12, height: 1.3)),
          ],
          if (selected) ...[
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.check_circle, color: BoardColors.copper, size: 16),
              SizedBox(width: 6),
              Text('Elegido en tu diseño', style: TextStyle(color: BoardColors.copper, fontSize: 12.5)),
            ]),
          ],
        ],
      ),
    );
  }

  String _cost() {
    final p = part;
    if (p is CommSpec) {
      if (p.isNone || p.tech == 'usb') return 'S/ 0';
      final c = controller;
      if (c != null && p.builtInKey.isNotEmpty && c.builtInComms.contains(p.builtInKey)) return 'Integrado';
      return fmtPen(p.moduleCostPen);
    }
    return fmtPen(p.costPen);
  }

  String? _subtitle() {
    final p = part;
    if (p is SensorSpec) return p.kindLabel;
    if (p is ControllerSpec) return p.chip;
    if (p is ActuatorSpec) return p.role;
    return null;
  }

  String? _notes() {
    final p = part;
    if (p is SensorSpec && p.notes.isNotEmpty) return p.notes;
    if (p is ActuatorSpec && p.notes.isNotEmpty) return p.notes;
    if (p is CommSpec && p.notes.isNotEmpty) return p.notes;
    return null;
  }

  List<Widget> _chips() {
    final p = part;
    if (p is SensorSpec) {
      final unit = p.measures.contains(mission.variable) ? mission.unit : '';
      return [
        SpecChip(interfaceLabel(p.interface), icon: Icons.cable),
        SpecChip('±${fmtCompact(p.accuracy)} $unit'.trim(), icon: Icons.gps_fixed),
        SpecChip('${fmtCompact(p.rangeMin)} a ${fmtCompact(p.rangeMax)} $unit'.trim(), icon: Icons.straighten),
        SpecChip(p.supplyMin == p.supplyMax
            ? fmtVolts(p.supplyMin)
            : '${fmtCompact(p.supplyMin, maxDecimals: 1)}–${fmtVolts(p.supplyMax)}', icon: Icons.bolt),
        if (p.logicV > 0) SpecChip('Lógica ${fmtVolts(p.logicV)}', icon: Icons.swap_vert),
        if (p.isAnalog) SpecChip('Salida hasta ${fmtVolts(p.outputMaxV)}', icon: Icons.show_chart),
        if (p.bandwidthHz > 0) SpecChip('${fmtCompact(p.bandwidthHz)} Hz', icon: Icons.graphic_eq),
        if (p.minIntervalS >= 0.5) SpecChip('1 lectura / ${fmtCompact(p.minIntervalS)} s', icon: Icons.timer_outlined),
        SpecChip(p.sealed ? 'Sellado' : 'No sellado', icon: Icons.water_drop_outlined,
            color: p.sealed ? BoardColors.ok : BoardColors.silkDim),
      ];
    }
    if (p is ControllerSpec) {
      return [
        SpecChip('Lógica ${fmtVolts(p.logicV)}${p.fiveVTolerant && p.logicV < 4 ? ' (tolera 5 V)' : ''}', icon: Icons.swap_vert),
        SpecChip(p.adcBits > 0 ? 'ADC ${p.adcBits} bits · ${p.adcChannels} canales' : 'Sin ADC',
            icon: Icons.analytics_outlined, color: p.adcBits > 0 ? null : BoardColors.warn),
        SpecChip(p.builtInComms.isEmpty ? 'Sin radio' : p.builtInComms.map(_radio).join(' + '), icon: Icons.wifi),
        SpecChip(p.ramKb >= 1048576 ? '${p.ramKb ~/ 1048576} GB RAM' : '${p.ramKb} KB RAM', icon: Icons.memory),
        SpecChip('${fmtCompact(p.activeMa)} mA activo', icon: Icons.battery_charging_full),
        SpecChip(p.supportsDeepSleep ? 'Sueño profundo' : 'Sin sueño profundo', icon: Icons.bedtime_outlined),
        SpecChip('GPIO máx. ${fmtCompact(p.gpioMaxMa)} mA', icon: Icons.electrical_services),
      ];
    }
    if (p is ActuatorSpec) {
      final effect = p.effectOn(mission.variable);
      return [
        SpecChip(driverLabel(p.driver), icon: Icons.electric_bolt),
        if (p.loadV > 0) SpecChip('${fmtVolts(p.loadV)} · ${fmtCompact(p.loadA, maxDecimals: 2)} A', icon: Icons.bolt),
        SpecChip(p.pwmCapable ? 'Admite PWM' : 'Solo encendido/apagado', icon: Icons.tune),
        if (p.maxSwitchesPerHour > 0) SpecChip('Máx. ${fmtCompact(p.maxSwitchesPerHour)} arranques/h', icon: Icons.repeat),
        SpecChip(
          effect == 0 ? 'No actúa sobre ${mission.variableLabel.toLowerCase()}' : (effect > 0 ? 'Aumenta' : 'Reduce'),
          icon: effect == 0 ? Icons.block : (effect > 0 ? Icons.arrow_upward : Icons.arrow_downward),
        ),
      ];
    }
    if (p is CommSpec) {
      if (p.isNone) return [const SpecChip('Sin enlace remoto', icon: Icons.portable_wifi_off)];
      return [
        SpecChip(p.rangeM >= 1000000 ? 'Alcance: cobertura' : 'Alcance ${fmtCompact(p.rangeM)} m', icon: Icons.straighten),
        SpecChip('Necesita ${infraLabel(p.infra)}', icon: Icons.router_outlined),
        SpecChip('Latencia ${fmtCompact(p.latencyS, maxDecimals: 2)} s', icon: Icons.timer_outlined),
        if (p.minIntervalS > 0) SpecChip('Máx. 1 mensaje / ${fmtInterval(p.minIntervalS)}', icon: Icons.hourglass_bottom),
        if (p.monthlyPen > 0) SpecChip('${fmtPen(p.monthlyPen)} al mes', icon: Icons.receipt_long, color: BoardColors.warn),
      ];
    }
    if (p is PowerSpec) {
      return [
        SpecChip(fmtRails(p.rails), icon: Icons.bolt),
        SpecChip('Hasta ${fmtCompact(p.maxA, maxDecimals: 1)} A', icon: Icons.speed),
        SpecChip(p.mains ? 'Requiere tomacorriente' : 'Batería ${fmtCompact(p.batteryWh, maxDecimals: 1)} Wh',
            icon: p.mains ? Icons.power : Icons.battery_full),
        if (p.solarWhDay > 0) SpecChip('Solar ${fmtCompact(p.solarWhDay)} Wh/día', icon: Icons.wb_sunny_outlined),
      ];
    }
    return const [];
  }

  static String _radio(String key) => switch (key) {
        'wifi' => 'Wi-Fi',
        'ble' => 'BLE',
        _ => key,
      };
}
