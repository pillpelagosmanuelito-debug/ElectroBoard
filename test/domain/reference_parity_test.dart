// Paridad entre el motor de Dart y el motor de referencia en Python.
//
// tools/reference_engine.py --fixture calcula, para cada misión, el diseño de
// referencia y decenas de variantes con errores típicos. Aquí se exige que el
// motor de la app llegue a las mismas conclusiones.

import 'package:electroboard/domain/engine/run_pipeline.dart';
import 'package:electroboard/domain/model/content_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_content.dart';

const simulationCodes = {
  'L01_time_in_band',
  'L08_alarm_latency',
  'L10_action_latency',
  'I01_delivery',
  'A05_autonomy',
  'C08_switch_rate',
};

void main() {
  late ContentBundle content;
  final cases = referenceCases();
  const pipeline = RunPipeline();

  setUpAll(() async {
    content = await loadContent();
  });

  test('el archivo de casos cubre las seis misiones', () {
    final missions = cases.map((c) => c['mission']).toSet();
    expect(missions.length, 6);
    expect(cases.length, greaterThanOrEqualTo(60));
  });

  for (final c in cases) {
    final label = '${c['mission']} · ${c['label']}';
    test('paridad: $label', () {
      final mission = content.mission(c['mission'] as String);
      final design = designFrom(c['design'] as Map<String, dynamic>);
      final out = pipeline.run(content, mission, design);
      final critical = out.evaluation.criticalCodes;
      final expectedCritical = (c['critical'] as List<dynamic>).cast<String>().toSet();
      final expectedStatic = (c['staticCritical'] as List<dynamic>).cast<String>().toSet();

      // Las reglas estáticas no dependen de la simulación: deben coincidir siempre.
      expect(critical.difference(simulationCodes), expectedStatic, reason: 'reglas estáticas');
      expect(out.sim.metrics.costPen, closeTo((c['costPen'] as num).toDouble(), 1e-9));

      if (c['robust'] == true) {
        expect(critical, expectedCritical, reason: 'hallazgos críticos');
        expect(out.evaluation.passed, c['passed']);
        expect(out.sim.metrics.timeInBandPct, closeTo((c['timeInBandPct'] as num).toDouble(), 1.0));
        expect(out.sim.metrics.energyWhDay, closeTo((c['energyWhDay'] as num).toDouble(), 0.05));
      }
    });
  }

  test('todas las soluciones de referencia aprueban', () {
    for (final m in content.missions) {
      final out = pipeline.run(content, m, m.referenceDesign);
      expect(out.evaluation.passed, isTrue, reason: m.id);
      expect(out.evaluation.overall, greaterThanOrEqualTo(90), reason: m.id);
    }
  });
}
