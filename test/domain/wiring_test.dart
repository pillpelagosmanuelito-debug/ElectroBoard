import 'package:electroboard/domain/engine/wiring_analyzer.dart';
import 'package:electroboard/domain/model/content_bundle.dart';
import 'package:electroboard/domain/model/design.dart';
import 'package:electroboard/domain/model/mission.dart';
import 'package:electroboard/domain/model/sim_result.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_content.dart';

void main() {
  late ContentBundle content;
  const analyzer = WiringAnalyzer();

  setUpAll(() async {
    content = await loadContent();
  });

  SystemDesign variant(Mission m, {String? sensor, String? controller, String? actuator, String? comm, String? power, bool? cond, LogicConfig? logic}) {
    final r = m.referenceDesign;
    return SystemDesign(
      sensorId: sensor ?? r.sensorId,
      controllerId: controller ?? r.controllerId,
      actuatorId: actuator ?? r.actuatorId,
      commId: comm ?? r.commId,
      powerId: power ?? r.powerId,
      conditioning: cond ?? r.conditioning,
      logic: logic ?? r.logic,
    );
  }

  WiringSetup wire(Mission m, SystemDesign d) => analyzer.analyze(m, ResolvedDesign.of(content.catalog, d));

  test('un sensor analógico en una Raspberry Pi queda sin lectura', () {
    final m = content.mission('incubadora');
    final st = wire(m, variant(m, sensor: 'lm35', controller: 'raspberry_pi4'));
    expect(st.noAdc, isTrue);
    expect(st.sensorDead, isTrue);
  });

  test('el LM35 en un Arduino Uno tiene resolución de unos 0.49 °C', () {
    final m = content.mission('incubadora');
    final st = wire(m, variant(m, sensor: 'lm35', controller: 'arduino_uno'));
    expect(st.effRes, closeTo(5.0 / 1024 / 0.01, 1e-9));
  });

  test('HC-SR04 en ESP32 sin adaptador produce lecturas intermitentes', () {
    final m = content.mission('tanque_edificio');
    final sin = wire(m, variant(m, sensor: 'hcsr04', cond: false));
    final con = wire(m, variant(m, sensor: 'hcsr04', cond: true));
    expect(sin.levelMismatch, 'high_to_low');
    expect(sin.intermittent, 0.4);
    expect(con.levelMismatch, '');
  });

  test('BME280 en un Uno de 5 V exige adaptador de nivel', () {
    final m = content.mission('incubadora');
    final st = wire(m, variant(m, sensor: 'bme280', controller: 'arduino_uno'));
    expect(st.levelMismatch, 'low_to_high');
  });

  test('la salida de 4.5 V del transmisor satura el ADC de 3.3 V sin divisor', () {
    final m = content.mission('tanque_edificio');
    final st = wire(m, variant(m, cond: false));
    expect(st.overrange, isTrue);
    expect(st.satCap, closeTo((3.3 - 0.5) / 0.04, 1e-9));
  });

  test('el IRF540N conduce parcialmente con 3.3 V y 5 V en la compuerta', () {
    final m = content.mission('incubadora');
    expect(wire(m, variant(m, actuator: 'heater_mosfet_std')).gateFactor, 0.25);
    expect(wire(m, variant(m, actuator: 'heater_mosfet_std', controller: 'arduino_uno')).gateFactor, 0.6);
  });

  test('una fuente de 1 A no sostiene un calefactor de 3.3 A', () {
    final m = content.mission('incubadora');
    final st = wire(m, variant(m, power: 'adapter_12v_1a'));
    expect(st.brownout, isTrue);
    expect(st.actBase, 0.0);
  });

  test('un calefactor directo al GPIO supera la corriente del pin', () {
    final m = content.mission('incubadora');
    expect(wire(m, variant(m, actuator: 'heater_gpio')).gpioOver, isTrue);
  });

  test('el Uno no integra Wi-Fi: se agrega un módulo y su costo', () {
    final m = content.mission('incubadora');
    final esp = wire(m, variant(m));
    final uno = wire(m, variant(m, controller: 'arduino_uno'));
    expect(esp.commNeedsModule, isFalse);
    expect(uno.commNeedsModule, isTrue);
    expect(uno.costPen - esp.costPen, closeTo(45 - 38 + 12, 1e-9));
  });

  test('Wi-Fi no alcanza el vivero a 1.2 km, LoRaWAN sí', () {
    final m = content.mission('riego_vivero');
    final wifi = wire(m, variant(m, comm: 'wifi_mqtt'));
    final lora = wire(m, variant(m));
    expect(wifi.infraOk, isFalse);
    expect(wifi.commOk, isFalse);
    expect(lora.commOk, isTrue);
  });

  test('las losas del edificio aumentan la pérdida de paquetes Wi-Fi', () {
    final m = content.mission('tanque_edificio');
    final st = wire(m, variant(m, comm: 'wifi_mqtt'));
    expect(st.loss, closeTo(0.01 + 0.35 + 0.3 * (25 / 40) * (25 / 40), 1e-9));
  });

  test('el MPU-6050 atenúa el defecto de 400 Hz', () {
    final m = content.mission('vibracion_faja');
    final st = wire(m, variant(m, sensor: 'mpu6050', controller: 'esp32_devkit', cond: false));
    expect(st.attenuation, closeTo(260 / 400, 1e-9));
  });

  test('un relé con PID se marca como incompatible', () {
    final m = content.mission('incubadora');
    final st = wire(
      m,
      variant(m, actuator: 'heater_relay', logic: m.referenceDesign.logic.copyWith(algorithm: ControlAlgorithm.pid)),
    );
    expect(st.relayPwm, isTrue);
  });
}
