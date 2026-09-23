import 'package:electroboard/domain/engine/lcg_random.dart';
import 'package:electroboard/domain/engine/system_simulator.dart';
import 'package:electroboard/domain/model/catalog.dart';
import 'package:electroboard/domain/model/content_bundle.dart';
import 'package:electroboard/domain/model/design.dart';
import 'package:electroboard/domain/model/mission.dart';
import 'package:electroboard/domain/model/sim_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_content.dart';

void main() {
  late ContentBundle content;
  const sim = SystemSimulator();

  setUpAll(() async {
    content = await loadContent();
  });

  SimResult run(Mission m, SystemDesign d) => sim.run(m, content.catalog, d);

  group('generador pseudoaleatorio', () {
    test('coincide con la secuencia de referencia de Python', () {
      final r = LcgRandom(11);
      // Primeros valores de Rng(11) en tools/reference_engine.py.
      var state = 11;
      for (var i = 0; i < 5; i++) {
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
        expect(r.next(), state / 2147483647.0);
      }
    });

    test('redondeo al par como Python', () {
      expect(roundHalfEven(2.5), 2.0);
      expect(roundHalfEven(3.5), 4.0);
      expect(roundHalfEven(-2.5), -2.0);
      expect(roundHalfEven(2.4999), 2.0);
      expect(roundHalfEven(2.5001), 3.0);
    });
  });

  test('la simulación es determinista', () {
    final m = content.mission('incubadora');
    final a = run(m, m.referenceDesign);
    final b = run(m, m.referenceDesign);
    expect(a.metrics.timeInBandPct, b.metrics.timeInBandPct);
    expect(a.metrics.delivered, b.metrics.delivered);
    expect(a.series.x, b.series.x);
  });

  test('la serie se submuestrea a unos 600 puntos', () {
    for (final m in content.missions) {
      final r = run(m, m.referenceDesign);
      expect(r.series.length, inInclusiveRange(550, 700), reason: m.id);
      expect(r.series.t.length, r.series.x.length);
      expect(r.series.m.length, r.series.u.length);
    }
  });

  test('un calefactor directo al GPIO daña el pin y deja de calentar', () {
    final m = content.mission('incubadora');
    final d = m.referenceDesign.withPart(PartKind.actuator, 'heater_gpio');
    final r = run(m, d);
    expect(r.metrics.pinDamaged, isTrue);
    expect(r.events.any((e) => e.kind == SimEventKind.pinDamage), isTrue);
    expect(r.series.x.last, lessThan(30));
  });

  test('sin enclavamiento el motor arranca y para repetidamente', () {
    final m = content.mission('vibracion_faja');
    final latch = run(m, m.referenceDesign);
    final onoff = run(m, m.referenceDesign.copyWith(logic: m.referenceDesign.logic.copyWith(algorithm: ControlAlgorithm.onoff)));
    expect(latch.metrics.switchesPerHour, lessThanOrEqualTo(6));
    expect(onoff.metrics.switchesPerHour, greaterThan(60));
  });

  test('LoRaWAN suprime los reportes que exceden el tiempo en el aire', () {
    final m = content.mission('riego_vivero');
    final ok = run(m, m.referenceDesign);
    final fast = run(m, m.referenceDesign.copyWith(logic: m.referenceDesign.logic.copyWith(reportS: 300)));
    expect(ok.metrics.suppressed, 0);
    expect(fast.metrics.suppressed, greaterThan(0));
  });

  test('almacenar y reenviar recupera los mensajes de un enlace degradado', () {
    final m = content.mission('tanque_edificio');
    final base = m.referenceDesign.withPart(PartKind.comm, 'wifi_mqtt');
    final sin = run(m, base.copyWith(logic: base.logic.copyWith(retry: false)));
    final con = run(m, base.copyWith(logic: base.logic.copyWith(retry: true)));
    expect(sin.metrics.deliveredPct, lessThan(80));
    expect(con.metrics.deliveredPct, greaterThan(95));
  });

  test('la autonomía depende de la carga y del bajo consumo', () {
    final m = content.mission('riego_vivero');
    final valvula = run(m, m.referenceDesign).metrics.autonomyDays!;
    final bomba = run(m, m.referenceDesign.withPart(PartKind.actuator, 'pump_relay')).metrics.autonomyDays!;
    expect(valvula, greaterThan(bomba));
    expect(valvula, greaterThan(m.requirements.minAutonomyDays));
  });

  test('las misiones con red eléctrica no calculan autonomía', () {
    final m = content.mission('incubadora');
    expect(run(m, m.referenceDesign).metrics.autonomyDays, isNull);
  });

  test('un firmware bloqueante acumula esperas', () {
    final m = content.mission('cadena_frio');
    final nb = run(m, m.referenceDesign);
    final bl = run(m, m.referenceDesign.copyWith(logic: m.referenceDesign.logic.copyWith(firmware: FirmwareStyle.blocking)));
    expect(nb.metrics.stallS, 0);
    expect(bl.metrics.stallS, greaterThan(0));
  });
}
