import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/board_theme.dart';
import '../../../core/format.dart';
import '../../../domain/model/design.dart';
import '../../providers.dart';
import '../../widgets/common.dart';
import '../firmware/firmware_view.dart';

/// Editor de la lógica de control y de la arquitectura del firmware.
class LogicEditorView extends ConsumerWidget {
  const LogicEditorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(benchProvider);
    if (state == null) return const Scaffold(body: LoadingView());
    final vm = ref.read(benchProvider.notifier);
    final m = state.mission;
    final lim = m.logic;
    final lg = state.design.logic;
    void set(LogicConfig next) => vm.updateLogic(next);
    String unit(double v, [int? dec]) => '${fmtNum(v, dec ?? m.decimals)} ${m.unit}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lógica y firmware'),
        actions: [
          if (state.design.isComplete)
            IconButton(
              tooltip: 'Ver el firmware generado',
              icon: const Icon(Icons.code),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FirmwareView())),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          BoardPanel(
            child: Text(
              'Objetivo: mantener ${m.variableLabel.toLowerCase()} entre ${unit(m.band.low)} y ${unit(m.band.high)}. '
              'Tu firmware ${m.direction > 0 ? 'enciende el actuador para subirla' : 'enciende el actuador para bajarla'}.',
              style: const TextStyle(height: 1.4),
            ),
          ),
          const SectionTitle('Algoritmo de control'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in lim.algorithms)
                  ChoiceChip(
                    label: Text(a.label),
                    selected: lg.algorithm == a,
                    onSelected: (_) => set(lg.copyWith(algorithm: a)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(lg.algorithm.description, style: const TextStyle(color: BoardColors.silkDim, fontSize: 13)),
          ),
          _SliderField(
            label: lg.algorithm == ControlAlgorithm.trip ? 'Umbral de disparo' : 'Consigna',
            valueText: unit(lg.setpoint, m.decimals + 1),
            value: lg.setpoint,
            min: lim.setpointMin,
            max: lim.setpointMax,
            step: lim.setpointStep,
            onChanged: (v) => set(lg.copyWith(setpoint: v)),
            helper: 'Banda permitida: ${unit(m.band.low)} a ${unit(m.band.high)}.',
          ),
          if (lg.algorithm == ControlAlgorithm.hysteresis)
            _SliderField(
              label: 'Histéresis (ancho de la banda muerta)',
              valueText: unit(lg.hysteresis, m.decimals + 1),
              value: lg.hysteresis,
              min: 0,
              max: lim.hystMax,
              step: lim.hystStep,
              onChanged: (v) => set(lg.copyWith(hysteresis: v)),
              helper: _hysteresisHelper(lg, m.direction, unit),
            ),
          if (lg.algorithm.isContinuous)
            _SliderField(
              label: 'Kp (ganancia proporcional)',
              valueText: fmtCompact(lg.kp, maxDecimals: 4),
              value: lg.kp,
              min: 0,
              max: lim.kpMax,
              step: lim.kpStep,
              onChanged: (v) => set(lg.copyWith(kp: v)),
              helper: 'Salida = Kp × error. Con Kp = ${fmtCompact(lg.kp, maxDecimals: 4)}, un error de '
                  '${unit(lg.kp > 0 ? 1 / lg.kp : 0.0)} lleva el actuador al 100 %.',
            ),
          if (lg.algorithm == ControlAlgorithm.pid) ...[
            _SliderField(
              label: 'Ki (ganancia integral)',
              valueText: fmtCompact(lg.ki, maxDecimals: 6),
              value: lg.ki,
              min: 0,
              max: lim.kiMax,
              step: lim.kiStep,
              onChanged: (v) => set(lg.copyWith(ki: v)),
              helper: 'Elimina el error estacionario. Demasiado provoca sobreimpulso.',
            ),
            _SliderField(
              label: 'Kd (ganancia derivativa)',
              valueText: fmtCompact(lg.kd, maxDecimals: 3),
              value: lg.kd,
              min: 0,
              max: lim.kdMax,
              step: lim.kdStep,
              onChanged: (v) => set(lg.copyWith(kd: v)),
              helper: 'Frena los cambios bruscos. Amplifica el ruido del sensor.',
            ),
          ],
          const SectionTitle('Periodo de muestreo'),
          _Choices(
            options: lim.samplingOptions,
            selected: lg.samplingS,
            onSelected: (v) => set(lg.copyWith(samplingS: v)),
          ),
          const SectionTitle('Periodo de reporte'),
          _Choices(
            options: lim.reportOptions,
            selected: lg.reportS,
            onSelected: (v) => set(lg.copyWith(reportS: v)),
            caption: 'La misión pide un dato cada ${fmtInterval(m.requirements.reportEveryS)}. Las alertas se envían por evento.',
          ),
          const SectionTitle('Arquitectura del firmware'),
          for (final f in FirmwareStyle.values)
            RadioListTile<FirmwareStyle>(
              value: f,
              groupValue: lg.firmware,
              onChanged: (v) => set(lg.copyWith(firmware: v)),
              title: Text(f.label),
              subtitle: Text(f.description, style: const TextStyle(fontSize: 12.5, color: BoardColors.silkDim)),
            ),
          const SectionTitle('Opciones'),
          SwitchListTile(
            value: lg.retry,
            onChanged: (v) => set(lg.copyWith(retry: v)),
            title: const Text('Almacenar y reenviar (QoS 1)'),
            subtitle: const Text('Guarda los mensajes que no se pudieron enviar y los reintenta.',
                style: TextStyle(fontSize: 12.5, color: BoardColors.silkDim)),
          ),
          SwitchListTile(
            value: lg.lowPower,
            onChanged: (v) => set(lg.copyWith(lowPower: v)),
            title: const Text('Bajo consumo (sueño profundo)'),
            subtitle: const Text('El controlador duerme entre muestras. Detiene el PWM mientras duerme.',
                style: TextStyle(fontSize: 12.5, color: BoardColors.silkDim)),
          ),
        ],
      ),
    );
  }

  String _hysteresisHelper(LogicConfig lg, int direction, String Function(double, [int?]) unit) {
    final on = direction > 0 ? lg.setpoint - lg.hysteresis / 2 : lg.setpoint + lg.hysteresis / 2;
    final off = direction > 0 ? lg.setpoint + lg.hysteresis / 2 : lg.setpoint - lg.hysteresis / 2;
    return 'Enciende en ${unit(on)} y apaga en ${unit(off)}.';
  }
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.valueText,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final String valueText;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final divisions = step > 0 ? ((max - min) / step).round().clamp(1, 1000) : null;
    final v = value.clamp(min, max);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(valueText, style: BoardTheme.mono.copyWith(color: BoardColors.copper, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: v,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: (x) {
              final snapped = step > 0 ? min + ((x - min) / step).round() * step : x;
              onChanged(double.parse(snapped.toStringAsFixed(8)));
            },
          ),
          if (helper != null) Text(helper!, style: const TextStyle(color: BoardColors.silkDim, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class _Choices extends StatelessWidget {
  const _Choices({required this.options, required this.selected, required this.onSelected, this.caption});

  final List<double> options;
  final double selected;
  final ValueChanged<double> onSelected;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                ChoiceChip(
                  label: Text(fmtInterval(o)),
                  selected: (o - selected).abs() < 1e-9,
                  onSelected: (_) => onSelected(o),
                ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 6),
            Text(caption!, style: const TextStyle(color: BoardColors.silkDim, fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}
