import 'dart:io';

import 'package:electroboard/domain/model/catalog.dart';
import 'package:electroboard/domain/model/content_bundle.dart';
import 'package:electroboard/domain/model/design.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_content.dart';

void main() {
  late ContentBundle content;

  setUpAll(() async {
    content = await loadContent();
  });

  test('se cargan seis misiones, cinco módulos y el catálogo completo', () {
    expect(content.missions.length, 6);
    expect(content.modules.length, 5);
    expect(content.lessonCount, greaterThanOrEqualTo(20));
    expect(content.catalog.controllers.length, greaterThanOrEqualTo(6));
    expect(content.catalog.sensors.length, greaterThanOrEqualTo(15));
    expect(content.catalog.actuators.length, greaterThanOrEqualTo(10));
    expect(content.catalog.comms.length, 7);
    expect(content.catalog.power.length, 6);
  });

  test('los módulos son los cinco del encargo, en orden', () {
    expect(content.modules.map((m) => m.title).toList(), [
      'Arquitectura embebida',
      'Sensores',
      'Actuadores y control',
      'Comunicación',
      'IoT',
    ]);
  });

  test('las misiones están ordenadas y con códigos únicos', () {
    final orders = content.missions.map((m) => m.order).toList();
    expect(orders, [1, 2, 3, 4, 5, 6]);
    expect(content.missions.map((m) => m.code).toSet().length, 6);
  });

  test('la primera misión es el sistema inteligente de temperatura', () {
    final m = content.missions.first;
    expect(m.variable, 'temperature');
    expect(m.title, contains('Incubadora'));
  });

  test('cada catálogo de misión apunta a componentes existentes', () {
    for (final m in content.missions) {
      for (final id in m.pools.sensors) {
        expect(() => content.catalog.sensor(id), returnsNormally, reason: '${m.id}/$id');
      }
      for (final id in m.pools.controllers) {
        expect(() => content.catalog.controller(id), returnsNormally);
      }
      for (final id in m.pools.actuators) {
        expect(() => content.catalog.actuator(id), returnsNormally);
      }
      for (final id in m.pools.comms) {
        expect(() => content.catalog.comm(id), returnsNormally);
      }
      for (final id in m.pools.power) {
        expect(() => content.catalog.powerSource(id), returnsNormally);
      }
    }
  });

  test('cada misión ofrece al menos un distractor por ranura', () {
    for (final m in content.missions) {
      expect(m.pools.sensors.length, greaterThanOrEqualTo(3), reason: m.id);
      expect(m.pools.actuators.length, greaterThanOrEqualTo(2), reason: m.id);
      expect(m.pools.power.length, greaterThanOrEqualTo(3), reason: m.id);
    }
  });

  test('las lecciones citadas por misiones y hallazgos existen', () {
    for (final m in content.missions) {
      for (final id in m.lessonIds) {
        expect(content.lesson(id), isNotNull, reason: '${m.id}: $id');
      }
    }
    for (final entry in content.findingTemplates.entries) {
      expect(content.lesson(entry.value.lessonId), isNotNull, reason: entry.key);
    }
  });

  test('las preguntas de control son válidas', () {
    for (final l in content.allLessons) {
      expect(l.check.options.length, greaterThanOrEqualTo(3), reason: l.id);
      expect(l.check.answer, inInclusiveRange(0, l.check.options.length - 1), reason: l.id);
      expect(l.check.explanation, isNotEmpty);
      expect(l.body, isNotEmpty);
    }
  });

  test('todo código de regla del evaluador tiene texto', () {
    final src = File('lib/domain/evaluator/design_evaluator.dart').readAsStringSync();
    final codes = RegExp(r"'([A-Z]\d{2}_[a-z0-9_]+)'").allMatches(src).map((m) => m.group(1)!).toSet();
    expect(codes.length, greaterThanOrEqualTo(55));
    for (final c in codes) {
      expect(content.findingTemplates.containsKey(c), isTrue, reason: c);
    }
  });

  test('los algoritmos por defecto están habilitados en cada misión', () {
    for (final m in content.missions) {
      expect(m.logic.algorithms, contains(m.defaultLogic.algorithm), reason: m.id);
      expect(m.logic.algorithms, contains(m.referenceDesign.logic.algorithm), reason: m.id);
    }
    final faja = content.mission('vibracion_faja');
    expect(faja.logic.algorithms, contains(ControlAlgorithm.trip));
  });

  test('los identificadores del catálogo son ASCII', () {
    final ids = <String>[
      ...content.catalog.sensors.map((e) => e.id),
      ...content.catalog.controllers.map((e) => e.id),
      ...content.catalog.actuators.map((e) => e.id),
      ...content.catalog.comms.map((e) => e.id),
      ...content.catalog.power.map((e) => e.id),
    ];
    for (final id in ids) {
      expect(RegExp(r'^[a-z0-9_]+$').hasMatch(id), isTrue, reason: id);
    }
    expect(PartKind.values.length, 5);
  });
}
