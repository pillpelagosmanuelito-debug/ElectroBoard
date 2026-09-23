import 'package:electroboard/domain/model/catalog.dart';
import 'package:electroboard/domain/model/content_bundle.dart';
import 'package:electroboard/domain/model/design.dart';
import 'package:electroboard/domain/model/learning.dart';
import 'package:electroboard/presentation/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_content.dart';

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    jsonSourceProvider.overrideWithValue(memorySource()),
    clockProvider.overrideWithValue(() => DateTime(2026, 9, 23, 10, 30)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  late ProviderContainer c;
  late ContentBundle content;

  setUp(() async {
    c = await makeContainer();
    content = await c.read(contentProvider.future);
  });

  test('el tablero abre la misión con la lógica por defecto', () {
    final m = content.mission('incubadora');
    c.read(benchProvider.notifier).open(content, m);
    final s = c.read(benchProvider)!;
    expect(s.mission.id, 'incubadora');
    expect(s.design.filledSlots, 0);
    expect(s.design.logic.algorithm, m.defaultLogic.algorithm);
    expect(s.missingSlots, hasLength(5));
    expect(s.estimatedCost, 0);
  });

  test('elegir bloques actualiza el costo y guarda el borrador', () {
    final m = content.mission('incubadora');
    final vm = c.read(benchProvider.notifier)..open(content, m);
    vm.selectPart(PartKind.controller, 'arduino_uno');
    vm.selectPart(PartKind.comm, 'wifi_mqtt');
    final s = c.read(benchProvider)!;
    expect(s.estimatedCost, 45 + 12);
    vm.selectPart(PartKind.controller, 'esp32_devkit');
    expect(c.read(benchProvider)!.estimatedCost, 38);
    expect(c.read(progressRepositoryProvider).draft('incubadora')?.controllerId, 'esp32_devkit');
  });

  test('un diseño incompleto no se puede simular', () {
    final m = content.mission('incubadora');
    final vm = c.read(benchProvider.notifier)..open(content, m);
    vm.selectPart(PartKind.sensor, 'ds18b20');
    expect(vm.run(), isNull);
  });

  test('simular registra el intento y actualiza las competencias', () {
    final m = content.mission('incubadora');
    final vm = c.read(benchProvider.notifier)..open(content, m);
    vm.loadReference();
    final out = vm.run();
    expect(out, isNotNull);
    expect(out!.evaluation.passed, isTrue);
    final progress = c.read(progressProvider);
    expect(progress.attemptsFor('incubadora'), hasLength(1));
    expect(progress.passed('incubadora'), isTrue);
    expect(progress.competencies()[Competency.programar], isNotNull);
    expect(c.read(benchProvider)!.lastRun, isNotNull);
  });

  test('cambiar el diseño invalida el último resultado', () {
    final m = content.mission('aula_co2');
    final vm = c.read(benchProvider.notifier)..open(content, m);
    vm.loadReference();
    vm.run();
    vm.updateLogic(c.read(benchProvider)!.design.logic.copyWith(samplingS: 60));
    expect(c.read(benchProvider)!.lastRun, isNull);
  });

  test('reabrir la misión recupera el borrador', () async {
    final m = content.mission('tanque_edificio');
    c.read(benchProvider.notifier)
      ..open(content, m)
      ..selectPart(PartKind.sensor, 'hcsr04')
      ..setConditioning(true);
    c.invalidate(benchProvider);
    c.read(benchProvider.notifier).open(content, m);
    final s = c.read(benchProvider)!;
    expect(s.design.sensorId, 'hcsr04');
    expect(s.design.conditioning, isTrue);
  });

  test('un borrador con componentes ajenos a la misión se descarta', () async {
    final m = content.mission('aula_co2');
    await c.read(progressRepositoryProvider).saveDraft(
          m.id,
          SystemDesign(sensorId: 'ds18b20', logic: m.defaultLogic),
        );
    c.read(benchProvider.notifier).open(content, m);
    expect(c.read(benchProvider)!.design.sensorId, isNull);
  });

  test('la mesa de trabajo resume misiones y módulos', () async {
    final summary = c.read(workbenchProvider).value!;
    expect(summary.missions, hasLength(6));
    expect(summary.modules, hasLength(5));
    expect(summary.passedCount, 0);
    expect(summary.next?.mission.id, 'incubadora');
    expect(summary.competencies.values.every((v) => v == null), isTrue);
  });

  test('responder una lección queda registrado en la bitácora', () async {
    final lesson = content.lesson('sen_rango')!;
    await c.read(progressProvider.notifier).answerLesson(lesson.id, lesson.check.answer);
    final log = c.read(logbookProvider).value!;
    expect(log.lessonsCorrect, 1);
    expect(log.lessonsTotal, content.lessonCount);
  });

  test('las pistas se revelan una a una', () async {
    await c.read(progressProvider.notifier).revealHint('incubadora', 1);
    final p = c.read(progressProvider);
    expect(p.hintRevealed('incubadora', 1), isTrue);
    expect(p.hintRevealed('incubadora', 0), isFalse);
  });

  test('borrar el avance reinicia todo', () async {
    final m = content.mission('incubadora');
    c.read(benchProvider.notifier)
      ..open(content, m)
      ..loadReference()
      ..run();
    await c.read(progressProvider.notifier).resetAll();
    expect(c.read(progressProvider).attempts, isEmpty);
  });

  test('el mejor intento prioriza los aprobados', () {
    final m = content.mission('incubadora');
    final vm = c.read(benchProvider.notifier)..open(content, m);
    vm.loadReference();
    vm.run();
    vm.selectPart(PartKind.sensor, 'dht11');
    vm.run();
    final best = c.read(progressProvider).bestFor('incubadora')!;
    expect(best.passed, isTrue);
    expect(best.design.sensorId, 'ds18b20');
    expect(c.read(progressProvider).attemptsFor('incubadora'), hasLength(2));
    expect(best.design.logic.algorithm, ControlAlgorithm.pid);
  });
}
