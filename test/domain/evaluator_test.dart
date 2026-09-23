import 'package:electroboard/domain/engine/run_pipeline.dart';
import 'package:electroboard/domain/model/catalog.dart';
import 'package:electroboard/domain/model/content_bundle.dart';
import 'package:electroboard/domain/model/design.dart';
import 'package:electroboard/domain/model/evaluation.dart';
import 'package:electroboard/domain/model/finding.dart';
import 'package:electroboard/domain/model/learning.dart';
import 'package:electroboard/domain/model/mission.dart';
import 'package:flutter_test/flutter_test.dart' hide Evaluation;

import '../support/test_content.dart';

void main() {
  late ContentBundle content;
  const pipeline = RunPipeline();

  setUpAll(() async {
    content = await loadContent();
  });

  Evaluation eval(Mission m, SystemDesign d) => pipeline.run(content, m, d).evaluation;

  test('aprobar equivale a no tener hallazgos críticos', () {
    for (final m in content.missions) {
      for (final actuator in m.pools.actuators) {
        final e = eval(m, m.referenceDesign.withPart(PartKind.actuator, actuator));
        expect(e.passed, e.criticalCount == 0, reason: '${m.id}/$actuator');
      }
    }
  });

  test('los puntajes quedan entre 0 y 100 y el total es el promedio', () {
    final m = content.mission('aula_co2');
    for (final s in m.pools.sensors) {
      final e = eval(m, m.referenceDesign.withPart(PartKind.sensor, s));
      for (final v in e.scores.values) {
        expect(v, inInclusiveRange(0, 100));
      }
      final avg = e.scores.values.reduce((a, b) => a + b) / e.scores.length;
      expect((e.overall - avg).abs(), lessThanOrEqualTo(0.5));
      expect(e.scores.keys.toSet(), Dimension.values.toSet());
    }
  });

  test('los mensajes no dejan marcadores sin completar', () {
    for (final m in content.missions) {
      for (final kind in PartKind.values) {
        final pool = switch (kind) {
          PartKind.sensor => m.pools.sensors,
          PartKind.controller => m.pools.controllers,
          PartKind.actuator => m.pools.actuators,
          PartKind.comm => m.pools.comms,
          PartKind.power => m.pools.power,
        };
        for (final id in pool) {
          final e = eval(m, m.referenceDesign.withPart(kind, id));
          for (final f in e.findings) {
            final text = '${f.title} ${f.message} ${f.fix}';
            expect(RegExp(r'\{[a-zA-Z]+\}').hasMatch(text), isFalse, reason: '${f.code}: $text');
            expect(f.title, isNot(f.code), reason: 'falta el texto de ${f.code}');
          }
        }
      }
    }
  });

  test('cada hallazgo enlaza una lección existente', () {
    final m = content.mission('incubadora');
    final e = eval(m, m.referenceDesign.withPart(PartKind.sensor, 'dht11'));
    for (final f in e.findings) {
      expect(content.lesson(f.lessonId), isNotNull, reason: f.code);
    }
  });

  test('el DHT22 en el vivero se reconoce como sensor de humedad del aire', () {
    final m = content.mission('riego_vivero');
    final e = eval(m, m.referenceDesign.withPart(PartKind.sensor, 'dht22'));
    final f = e.findings.firstWhere((x) => x.code == 'S01_wrong_variable');
    expect(f.message, contains('humedad del aire'));
    expect(f.severity, Severity.critical);
  });

  test('la Raspberry Pi en la faja advierte sobre tiempo real', () {
    final m = content.mission('vibracion_faja');
    final e = eval(m, m.referenceDesign.withPart(PartKind.controller, 'raspberry_pi4'));
    expect(e.findings.map((f) => f.code), contains('A04_linux_realtime'));
    expect(e.findings.map((f) => f.code), contains('S05_no_adc'));
  });

  test('una histéresis estrecha daña el compresor de la cadena de frío', () {
    final m = content.mission('cadena_frio');
    final e = eval(m, m.referenceDesign.copyWith(logic: m.referenceDesign.logic.copyWith(hysteresis: 0.4)));
    final f = e.findings.firstWhere((x) => x.code == 'C08_switch_rate');
    expect(f.severity, Severity.critical);
    expect(e.passed, isFalse);
  });

  test('la consigna fuera de la banda es crítica', () {
    final m = content.mission('incubadora');
    final e = eval(m, m.referenceDesign.copyWith(logic: m.referenceDesign.logic.copyWith(setpoint: 39.0)));
    expect(e.criticalCodes, contains('L02_setpoint_outside'));
  });

  test('los requisitos incluyen autonomía solo en misiones con batería', () {
    final riego = content.mission('riego_vivero');
    final inc = content.mission('incubadora');
    expect(eval(riego, riego.referenceDesign).requirements.map((r) => r.label), contains('Autonomía sin sol'));
    expect(eval(inc, inc.referenceDesign).requirements.map((r) => r.label), isNot(contains('Autonomía sin sol')));
  });

  test('las competencias se derivan de las dimensiones', () {
    final m = content.mission('aula_co2');
    final e = eval(m, m.referenceDesign);
    expect(e.competencyScores.keys.toSet(), Competency.values.toSet());
    expect(e.competencyScores[Competency.programar], e.scores[Dimension.logica]);
  });

  test('los hallazgos se ordenan de más a menos grave', () {
    final m = content.mission('incubadora');
    final e = eval(m, m.referenceDesign.withPart(PartKind.sensor, 'dht11'));
    for (var i = 1; i < e.findings.length; i++) {
      expect(e.findings[i].severity.index, greaterThanOrEqualTo(e.findings[i - 1].severity.index));
    }
  });
}
