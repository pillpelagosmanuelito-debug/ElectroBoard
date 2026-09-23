import 'package:electroboard/data/repositories/json_content_repository.dart';
import 'package:electroboard/data/repositories/prefs_progress_repository.dart';
import 'package:electroboard/data/sources/json_source.dart';
import 'package:electroboard/domain/model/design.dart';
import 'package:electroboard/domain/model/evaluation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_content.dart';

AttemptRecord _attempt(String mission, int ts, {int overall = 70, bool passed = false}) => AttemptRecord(
      missionId: mission,
      timestampMs: ts,
      overall: overall,
      passed: passed,
      scores: const {'arquitectura': 80, 'sensores': 70, 'actuadores': 60, 'comunicacion': 90, 'iot': 50, 'logica': 70},
      criticalCount: passed ? 0 : 2,
      timeInBandPct: 80,
      costPen: 120,
      design: const SystemDesign(
        sensorId: 'ds18b20',
        logic: LogicConfig(
          algorithm: ControlAlgorithm.hysteresis,
          setpoint: 37.5,
          hysteresis: 0.3,
          kp: 1,
          ki: 0,
          kd: 0,
          samplingS: 5,
          reportS: 60,
          firmware: FirmwareStyle.nonblocking,
          lowPower: false,
          retry: true,
        ),
      ),
    );

void main() {
  late PrefsProgressRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repo = PrefsProgressRepository(await SharedPreferences.getInstance());
  });

  test('guarda y recupera intentos con su diseño', () async {
    await repo.saveAttempt(_attempt('incubadora', 1, overall: 88, passed: true));
    final all = repo.attempts();
    expect(all, hasLength(1));
    expect(all.first.overall, 88);
    expect(all.first.passed, isTrue);
    expect(all.first.design.sensorId, 'ds18b20');
    expect(all.first.design.logic.algorithm, ControlAlgorithm.hysteresis);
  });

  test('conserva solo los intentos más recientes por misión', () async {
    for (var i = 0; i < PrefsProgressRepository.maxAttemptsPerMission + 5; i++) {
      await repo.saveAttempt(_attempt('incubadora', i));
    }
    await repo.saveAttempt(_attempt('aula_co2', 999));
    final inc = repo.attempts().where((a) => a.missionId == 'incubadora').toList();
    expect(inc, hasLength(PrefsProgressRepository.maxAttemptsPerMission));
    expect(inc.first.timestampMs, 5);
    expect(repo.attempts().where((a) => a.missionId == 'aula_co2'), hasLength(1));
  });

  test('guarda respuestas de lecciones, pistas y borradores', () async {
    await repo.saveLessonAnswer('sen_rango', 1);
    await repo.revealHint('incubadora#0');
    final draft = _attempt('x', 0).design;
    await repo.saveDraft('incubadora', draft);
    expect(repo.lessonAnswers(), {'sen_rango': 1});
    expect(repo.revealedHints(), {'incubadora#0'});
    expect(repo.draft('incubadora')?.sensorId, 'ds18b20');
    expect(repo.draft('aula_co2'), isNull);
  });

  test('tolera datos corruptos', () async {
    SharedPreferences.setMockInitialValues({'eb.attempts.v1': '{no es json', 'eb.lessons.v1': '[]'});
    final r = PrefsProgressRepository(await SharedPreferences.getInstance());
    expect(r.attempts(), isEmpty);
    expect(r.lessonAnswers(), isEmpty);
  });

  test('borrar el avance elimina solo las claves de la app', () async {
    SharedPreferences.setMockInitialValues({'otra.app': 'x'});
    final prefs = await SharedPreferences.getInstance();
    final r = PrefsProgressRepository(prefs);
    await r.saveLessonAnswer('arq_bloques', 2);
    await r.clear();
    expect(r.lessonAnswers(), isEmpty);
    expect(prefs.getString('otra.app'), 'x');
  });

  test('el repositorio de contenido cachea la carga', () async {
    final repoContent = JsonContentRepository(memorySource());
    final a = await repoContent.load();
    final b = await repoContent.load();
    expect(identical(a, b), isTrue);
  });

  test('la fuente en memoria informa documentos ausentes', () async {
    final src = MemoryJsonSource({});
    expect(() => src.read('missions.json'), throwsStateError);
  });
}
