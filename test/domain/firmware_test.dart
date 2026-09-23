import 'package:electroboard/domain/codegen/firmware_generator.dart';
import 'package:electroboard/domain/model/catalog.dart';
import 'package:electroboard/domain/model/content_bundle.dart';
import 'package:electroboard/domain/model/design.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_content.dart';

void main() {
  late ContentBundle content;
  const gen = FirmwareGenerator();

  setUpAll(() async {
    content = await loadContent();
  });

  test('genera firmware para todas las soluciones de referencia', () {
    for (final m in content.missions) {
      final l = gen.generate(m, content.catalog, m.referenceDesign);
      expect(l.code, contains('void setup()'), reason: m.id);
      expect(l.code, contains('void loop()'), reason: m.id);
      expect(l.code, contains(m.code), reason: m.id);
      expect(l.fileName, endsWith('.ino'));
      expect(l.lineCount, greaterThan(60));
    }
  });

  test('cada sensor aporta su biblioteca', () {
    final m = content.mission('incubadora');
    final ds = gen.generate(m, content.catalog, m.referenceDesign);
    expect(ds.libraries, containsAll(['OneWire.h', 'DallasTemperature.h', 'WiFi.h', 'PubSubClient.h']));
    final dht = gen.generate(m, content.catalog, m.referenceDesign.withPart(PartKind.sensor, 'dht22'));
    expect(dht.code, contains('DHT dht(PIN_SENSOR, DHT22);'));
  });

  test('la conversión del DS18B20 es asíncrona si el firmware no es bloqueante', () {
    final m = content.mission('incubadora');
    final nb = gen.generate(m, content.catalog, m.referenceDesign);
    final bl = gen.generate(
      m,
      content.catalog,
      m.referenceDesign.copyWith(logic: m.referenceDesign.logic.copyWith(firmware: FirmwareStyle.blocking)),
    );
    expect(nb.code, contains('setWaitForConversion(false)'));
    expect(bl.code, contains('delay(MUESTREO_MS)'));
  });

  test('el algoritmo elegido aparece en el código', () {
    final m = content.mission('vibracion_faja');
    final trip = gen.generate(m, content.catalog, m.referenceDesign);
    expect(trip.code, contains('enclavado = true'));
    final inc = content.mission('incubadora');
    final pid = gen.generate(inc, content.catalog, inc.referenceDesign);
    expect(pid.code, contains('anti-windup'));
  });

  test('almacenar y reenviar genera un búfer circular', () {
    final m = content.mission('cadena_frio');
    final l = gen.generate(m, content.catalog, m.referenceDesign);
    expect(l.code, contains('MAX_PENDIENTES'));
    expect(l.code, contains('sendSMS'));
  });

  test('el bajo consumo en ESP32 usa sueño profundo', () {
    final m = content.mission('riego_vivero');
    final l = gen.generate(m, content.catalog, m.referenceDesign.withPart(PartKind.controller, 'esp32_devkit'));
    expect(l.code, contains('esp_deep_sleep_start()'));
    expect(l.code, contains('RTC_DATA_ATTR'));
  });

  test('una Raspberry Pi recibe un programa en Python', () {
    final m = content.mission('incubadora');
    final l = gen.generate(m, content.catalog, m.referenceDesign.withPart(PartKind.controller, 'raspberry_pi4'));
    expect(l.fileName, endsWith('.py'));
    expect(l.code, contains('def main():'));
  });

  test('una carga directa al GPIO se advierte en el código', () {
    final m = content.mission('incubadora');
    final l = gen.generate(m, content.catalog, m.referenceDesign.withPart(PartKind.actuator, 'heater_gpio'));
    expect(l.code, contains('ADVERTENCIA'));
  });

  test('la consigna se limita en el firmware', () {
    final m = content.mission('aula_co2');
    final l = gen.generate(m, content.catalog, m.referenceDesign);
    expect(l.code, contains('CONSIGNA_MAX_SEGURA'));
    expect(l.code, contains('constrain(CONSIGNA'));
  });
}
