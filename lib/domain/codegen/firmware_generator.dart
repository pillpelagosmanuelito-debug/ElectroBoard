// Generador de firmware de referencia.
//
// Traduce el diseño del estudiante a un esqueleto de firmware comentado
// (Arduino/C++ para microcontroladores, Python para Linux). Su objetivo es
// didáctico: mostrar cómo cada decisión de hardware se convierte en código
// (bibliotecas, conversión de unidades, algoritmo de control, comunicación y
// arquitectura del bucle). No pretende compilar sin ajustes para cada placa.

import '../../core/format.dart';
import '../engine/wiring_analyzer.dart';
import '../model/catalog.dart';
import '../model/design.dart';
import '../model/mission.dart';

class FirmwareListing {
  final String fileName;
  final String language;
  final String code;
  final List<String> libraries;

  const FirmwareListing({
    required this.fileName,
    required this.language,
    required this.code,
    required this.libraries,
  });

  int get lineCount => '\n'.allMatches(code).length + 1;
}

class FirmwareGenerator {
  const FirmwareGenerator();

  FirmwareListing generate(Mission mission, Catalog catalog, SystemDesign design) {
    final r = ResolvedDesign.of(catalog, design);
    if (r.controller.isLinux) return _python(mission, r);
    return _arduino(mission, r);
  }

  // ------------------------------------------------------------------
  // Arduino / C++
  // ------------------------------------------------------------------

  FirmwareListing _arduino(Mission mission, ResolvedDesign r) {
    final c = r.controller;
    final s = r.sensor;
    final a = r.actuator;
    final k = r.comm;
    final lg = r.logic;
    final libs = <String>[];
    final b = StringBuffer();
    final pins = _pins(c.id);
    final topic = 'electroboard/${mission.id}';
    final isEsp32 = c.id == 'esp32_devkit';
    final usesRtos = lg.firmware == FirmwareStyle.rtos;
    final lowPower = lg.lowPower && c.supportsDeepSleep;

    void w([String line = '']) => b.writeln(line);

    w('/*');
    w(' * ElectroBoard · ${mission.code} · ${mission.title}');
    w(' * Firmware de referencia generado a partir de tu diseño.');
    w(' *');
    w(' * Controlador : ${c.name} (${c.chip})');
    w(' * Sensor      : ${s.name} (${interfaceLabel(s.interface)})');
    w(' * Actuador    : ${a.name}');
    w(' * Enlace      : ${k.name}');
    w(' * Lógica      : ${lg.algorithm.label}, muestreo ${fmtInterval(lg.samplingS)}, reporte ${fmtInterval(lg.reportS)}');
    w(' * Arquitectura: ${lg.firmware.label}${lowPower ? ' + sueño profundo' : ''}');
    w(' *');
    w(' * Es un esqueleto didáctico: revisa pines, bibliotecas y credenciales antes de cargarlo.');
    w(' */');
    w();

    // ---------- bibliotecas ----------
    final includes = <String>[];
    includes.addAll(_sensorIncludes(s.id));
    includes.addAll(_commIncludes(k.tech, c));
    if (a.driver == 'servo') includes.add(isEsp32 ? '#include <ESP32Servo.h>' : '#include <Servo.h>');
    if (usesRtos && !isEsp32 && c.rtosCapable) includes.add('#include <FreeRTOS.h>');
    if (lowPower && isEsp32) includes.add('#include <esp_sleep.h>');
    if (k.tech == 'wifi' || k.tech == 'lte') includes.add('#include "secrets.h"   // credenciales fuera del repositorio');
    for (final inc in includes.toSet()) {
      w(inc);
      final m = RegExp(r'<([^>]+)>').firstMatch(inc);
      if (m != null) libs.add(m.group(1)!);
    }
    if (includes.isNotEmpty) w();

    // ---------- constantes ----------
    w('// ---------- Pines ----------');
    w('const int PIN_SENSOR   = ${pins.sensor};');
    if (s.interface == 'pulse') w('const int PIN_TRIGGER  = ${pins.aux};');
    if (s.id == 'soil_resistive') w('const int PIN_SENSOR_VCC = ${pins.aux};   // alimenta el sensor solo al medir');
    w('const int PIN_ACTUADOR = ${pins.actuator};');
    w();
    w('// ---------- Parámetros de la misión ----------');
    w('const float CONSIGNA        = ${_f(lg.setpoint)};   // ${mission.unit}');
    w('const float BANDA_MIN       = ${_f(mission.band.low)};');
    w('const float BANDA_MAX       = ${_f(mission.band.high)};');
    w('const float UMBRAL_ALERTA   = ${_f(mission.alarm.threshold)};   // ${mission.alarm.label}');
    w('const unsigned long MUESTREO_MS = ${(lg.samplingS * 1000).round()}UL;');
    w('const unsigned long REPORTE_MS  = ${(lg.reportS * 1000).round()}UL;');
    switch (lg.algorithm) {
      case ControlAlgorithm.hysteresis:
        w('const float HISTERESIS      = ${_f(lg.hysteresis)};');
      case ControlAlgorithm.proportional:
        w('const float KP              = ${_f(lg.kp, 5)};');
      case ControlAlgorithm.pid:
        w('const float KP = ${_f(lg.kp, 5)}, KI = ${_f(lg.ki, 6)}, KD = ${_f(lg.kd, 3)};');
      case ControlAlgorithm.onoff:
      case ControlAlgorithm.trip:
        break;
    }
    // Límites de seguridad implementados en el firmware (lección iot_seguridad).
    w('const float CONSIGNA_MIN_SEGURA = ${_f(mission.logic.setpointMin)};');
    w('const float CONSIGNA_MAX_SEGURA = ${_f(mission.logic.setpointMax)};');
    if (s.isAnalog && c.adcBits > 0) {
      w();
      w('// ---------- Conversor analógico-digital ----------');
      w('const float VREF    = ${_f(c.adcVref, 2)};      // V');
      w('const int   ADC_MAX = ${(1 << c.adcBits) - 1};       // ${c.adcBits} bits');
      if (r.design.conditioning) {
        w('const float DIVISOR = ${_f(s.outputMaxV / c.adcVref, 3)};   // divisor resistivo: tensión real = medida × DIVISOR');
      }
    }
    w();

    // ---------- objetos globales ----------
    final globals = _sensorGlobals(s.id);
    final commGlobals = _commGlobals(k.tech);
    if (globals.isNotEmpty || commGlobals.isNotEmpty || a.driver == 'servo') {
      w('// ---------- Objetos globales ----------');
      for (final g in globals) {
        w(g);
      }
      for (final g in commGlobals) {
        w(g);
      }
      if (a.driver == 'servo') w('Servo ventanilla;');
      w();
    }

    w('// ---------- Estado ----------');
    if (lowPower && isEsp32) {
      w('RTC_DATA_ATTR bool actuadorEncendido = false;   // sobrevive al sueño profundo');
      w('RTC_DATA_ATTR bool alertaActiva = false;');
    } else {
      w('bool  actuadorEncendido = false;');
      w('bool  alertaActiva = false;');
    }
    if (lg.algorithm == ControlAlgorithm.trip) w('bool  enclavado = false;   // solo se libera con rearme manual');
    if (lg.algorithm == ControlAlgorithm.pid) w('float integral = 0, errorPrevio = 0;');
    if (lg.firmware == FirmwareStyle.nonblocking) w('unsigned long ultimoMuestreo = 0, ultimoReporte = 0;');
    if (lg.retry) {
      w();
      w('// Almacenar y reenviar: búfer circular de mensajes pendientes (QoS 1).');
      w('const int MAX_PENDIENTES = 32;');
      w('String pendientes[MAX_PENDIENTES];');
      w('int cabeza = 0, cola = 0;');
    }
    w();

    // ---------- lectura del sensor ----------
    w('// Devuelve la medición en ${mission.unit}, o NAN si la lectura falló.');
    w('float leerSensor() {');
    for (final line in _sensorRead(s, c, r.design.conditioning, lg.firmware)) {
      w('  $line');
    }
    w('}');
    w();

    // ---------- control ----------
    w('// Calcula la salida del actuador (0.0 a 1.0) a partir de la medición.');
    w('float calcularSalida(float medicion) {');
    w('  if (isnan(medicion)) return 0.0;   // falla segura: sin dato, sin actuación');
    w('  float consigna = constrain(CONSIGNA, CONSIGNA_MIN_SEGURA, CONSIGNA_MAX_SEGURA);');
    final dirExpr = mission.direction > 0 ? 'consigna - medicion' : 'medicion - consigna';
    w('  float error = $dirExpr;   // positivo = hay que ${mission.direction > 0 ? 'aumentar' : 'reducir'} la variable');
    switch (lg.algorithm) {
      case ControlAlgorithm.onoff:
        w('  actuadorEncendido = error > 0;');
        w('  return actuadorEncendido ? 1.0 : 0.0;');
      case ControlAlgorithm.hysteresis:
        w('  if (error > HISTERESIS / 2) actuadorEncendido = true;');
        w('  else if (error < -HISTERESIS / 2) actuadorEncendido = false;');
        w('  return actuadorEncendido ? 1.0 : 0.0;');
      case ControlAlgorithm.proportional:
        w('  return constrain(KP * error, 0.0, 1.0);');
      case ControlAlgorithm.pid:
        w('  const float dt = MUESTREO_MS / 1000.0;');
        w('  integral += error * dt;');
        w('  if (KI > 0) integral = constrain(integral, -1.0 / KI, 1.0 / KI);   // anti-windup');
        w('  float derivada = (error - errorPrevio) / dt;');
        w('  errorPrevio = error;');
        w('  return constrain(KP * error + KI * integral + KD * derivada, 0.0, 1.0);');
      case ControlAlgorithm.trip:
        w('  if (error > 0) enclavado = true;   // la parada queda memorizada');
        w('  return enclavado ? 1.0 : 0.0;');
    }
    w('}');
    w();

    // ---------- actuador ----------
    w('void aplicarSalida(float u) {');
    for (final line in _actuatorWrite(a, c)) {
      w('  $line');
    }
    w('}');
    w();

    // ---------- comunicación ----------
    w('// Publica un mensaje. Devuelve true si el enlace confirmó la entrega.');
    w('bool enviar(const String& tema, const String& carga) {');
    for (final line in _commSend(k.tech)) {
      w('  $line');
    }
    w('}');
    w();
    if (lg.retry) {
      w('void encolar(const String& msg) {');
      w('  pendientes[cabeza] = msg;');
      w('  cabeza = (cabeza + 1) % MAX_PENDIENTES;');
      w('  if (cabeza == cola) cola = (cola + 1) % MAX_PENDIENTES;   // búfer lleno: se descarta el más antiguo');
      w('}');
      w();
      w('void reenviarPendientes() {');
      w('  while (cola != cabeza) {');
      w('    if (!enviar("$topic/medicion", pendientes[cola])) return;   // el enlace sigue caído');
      w('    cola = (cola + 1) % MAX_PENDIENTES;');
      w('  }');
      w('}');
      w();
    }
    w('void reportar(float medicion, float u) {');
    w('  String carga = "{\\"valor\\":" + String(medicion, ${mission.decimals}) + ",\\"salida\\":" + String(u, 2) + ",\\"t\\":" + String(millis() / 1000) + "}";');
    if (lg.retry) {
      w('  reenviarPendientes();');
      w('  if (!enviar("$topic/medicion", carga)) encolar(carga);');
    } else {
      w('  enviar("$topic/medicion", carga);   // sin reintento: si falla, el dato se pierde');
    }
    w('}');
    w();
    w('void revisarAlerta(float medicion) {');
    w('  if (isnan(medicion)) return;');
    final cond = mission.alarm.up ? 'medicion > UMBRAL_ALERTA' : 'medicion < UMBRAL_ALERTA';
    w('  bool condicion = $cond;');
    w('  if (condicion && !alertaActiva) {');
    w('    alertaActiva = true;');
    w('    String alerta = "{\\"alerta\\":\\"${mission.alarm.label}\\",\\"valor\\":" + String(medicion, ${mission.decimals}) + "}";');
    if (lg.retry) {
      w('    if (!enviar("$topic/alerta", alerta)) encolar(alerta);   // las alertas también se reintentan');
    } else {
      w('    enviar("$topic/alerta", alerta);');
    }
    w('  } else if (!condicion) {');
    w('    alertaActiva = false;');
    w('  }');
    w('}');
    w();

    // ---------- setup y bucle ----------
    w('void setup() {');
    w('  Serial.begin(115200);');
    for (final line in _sensorSetup(s.id)) {
      w('  $line');
    }
    if (a.driver == 'servo') {
      w('  ventanilla.attach(PIN_ACTUADOR);');
    } else {
      w('  pinMode(PIN_ACTUADOR, OUTPUT);');
    }
    for (final line in _commSetup(k.tech)) {
      w('  $line');
    }
    if (usesRtos) {
      w('  xTaskCreate(tareaControl, "control", 4096, NULL, 2, NULL);        // prioridad alta');
      w('  xTaskCreate(tareaComunicacion, "comunicacion", 8192, NULL, 1, NULL);');
    }
    w('}');
    w();

    if (lowPower && isEsp32) {
      w('// Bajo consumo: cada despertar mide, decide, reporta y vuelve a dormir.');
      w('// El estado del actuador se conserva en memoria RTC y el pin se retiene con gpio_hold_en().');
      w('RTC_DATA_ATTR unsigned long despertares = 0;');
      w('void loop() {');
      w('  float medicion = leerSensor();');
      w('  float u = calcularSalida(medicion);');
      w('  aplicarSalida(u);');
      w('  gpio_hold_en((gpio_num_t)PIN_ACTUADOR);');
      w('  revisarAlerta(medicion);');
      w('  despertares++;');
      w('  if (despertares * MUESTREO_MS >= REPORTE_MS) { reportar(medicion, u); despertares = 0; }');
      w('  esp_sleep_enable_timer_wakeup(MUESTREO_MS * 1000ULL);');
      w('  esp_deep_sleep_start();');
      w('}');
    } else if (lg.firmware == FirmwareStyle.blocking) {
      w('// Bucle bloqueante: cada espera (sensor, radio, delay) detiene el control.');
      w('unsigned long acumulado = 0;');
      w('void loop() {');
      w('  float medicion = leerSensor();');
      w('  float u = calcularSalida(medicion);');
      w('  aplicarSalida(u);');
      w('  revisarAlerta(medicion);');
      w('  acumulado += MUESTREO_MS;');
      w('  if (acumulado >= REPORTE_MS) { reportar(medicion, u); acumulado = 0; }   // espera la confirmación');
      w('  delay(MUESTREO_MS);');
      w('}');
    } else if (usesRtos) {
      w('// Tarea de control: nunca espera a la red.');
      w('volatile float ultimaMedicion = NAN, ultimaSalida = 0;');
      w('void tareaControl(void* arg) {');
      w('  TickType_t ultimo = xTaskGetTickCount();');
      w('  for (;;) {');
      w('    float medicion = leerSensor();');
      w('    float u = calcularSalida(medicion);');
      w('    aplicarSalida(u);');
      w('    ultimaMedicion = medicion;');
      w('    ultimaSalida = u;');
      w('    vTaskDelayUntil(&ultimo, pdMS_TO_TICKS(MUESTREO_MS));');
      w('  }');
      w('}');
      w();
      w('// Tarea de comunicación: puede bloquearse sin afectar el control.');
      w('void tareaComunicacion(void* arg) {');
      w('  unsigned long ultimoReporte = 0;');
      w('  for (;;) {');
      w('    revisarAlerta(ultimaMedicion);');
      w('    if (millis() - ultimoReporte >= REPORTE_MS) { reportar(ultimaMedicion, ultimaSalida); ultimoReporte = millis(); }');
      w('    vTaskDelay(pdMS_TO_TICKS(200));');
      w('  }');
      w('}');
      w();
      w('void loop() { vTaskDelete(NULL); }   // todo ocurre en las tareas');
    } else {
      w('// Bucle no bloqueante: temporizadores con millis(), sin delay().');
      w('float medicion = NAN, u = 0;');
      w('void loop() {');
      w('  unsigned long ahora = millis();');
      w('  if (ahora - ultimoMuestreo >= MUESTREO_MS) {');
      w('    ultimoMuestreo = ahora;');
      w('    medicion = leerSensor();');
      w('    u = calcularSalida(medicion);');
      w('    aplicarSalida(u);');
      w('    revisarAlerta(medicion);');
      w('  }');
      w('  if (ahora - ultimoReporte >= REPORTE_MS) {');
      w('    ultimoReporte = ahora;');
      w('    reportar(medicion, u);');
      w('  }');
      for (final line in _commLoop(k.tech)) {
        w('  $line');
      }
      w('}');
    }

    return FirmwareListing(
      fileName: 'electroboard_${mission.id}.ino',
      language: 'Arduino (C++)',
      code: b.toString(),
      libraries: libs,
    );
  }

  // ------------------------------------------------------------------
  // Python para Linux (Raspberry Pi)
  // ------------------------------------------------------------------

  FirmwareListing _python(Mission mission, ResolvedDesign r) {
    final s = r.sensor;
    final a = r.actuator;
    final k = r.comm;
    final lg = r.logic;
    final b = StringBuffer();
    void w([String line = '']) => b.writeln(line);
    w('#!/usr/bin/env python3');
    w('"""ElectroBoard · ${mission.code} · ${mission.title}');
    w();
    w('Programa de referencia para ${r.controller.name}.');
    w('Linux no garantiza tiempos de respuesta: no uses este equipo como única');
    w('protección de seguridad."""');
    w('import time');
    w('from gpiozero import OutputDevice');
    if (s.isAnalog) {
      w();
      w('# La Raspberry Pi no tiene ADC: ${s.name} necesita un conversor externo');
      w('# (por ejemplo, un ADS1115 por I²C). Sin él no hay lectura.');
      w('import board, busio');
      w('import adafruit_ads1x15.ads1115 as ADS');
      w('from adafruit_ads1x15.analog_in import AnalogIn');
    }
    if (k.tech == 'wifi') w('import paho.mqtt.client as mqtt');
    w();
    w('CONSIGNA = ${_f(lg.setpoint)}');
    w('HISTERESIS = ${_f(lg.hysteresis)}');
    w('MUESTREO_S = ${fmtCompact(lg.samplingS)}');
    w('REPORTE_S = ${fmtCompact(lg.reportS)}');
    w('actuador = OutputDevice(17)   # ${a.name}');
    w();
    w('def leer_sensor():');
    w('    """Devuelve la medición en ${mission.unit} o None si falla."""');
    w('    raise NotImplementedError("Implementa la lectura de ${s.name}")');
    w();
    w('def main():');
    w('    encendido = False');
    w('    ultimo_reporte = 0.0');
    w('    while True:');
    w('        medicion = leer_sensor()');
    w('        if medicion is not None:');
    final err = mission.direction > 0 ? 'CONSIGNA - medicion' : 'medicion - CONSIGNA';
    w('            error = $err');
    w('            if error > HISTERESIS / 2:');
    w('                encendido = True');
    w('            elif error < -HISTERESIS / 2:');
    w('                encendido = False');
    w('        else:');
    w('            encendido = False   # falla segura');
    w('        actuador.value = encendido');
    w('        if time.monotonic() - ultimo_reporte >= REPORTE_S:');
    w('            ultimo_reporte = time.monotonic()');
    w('            print({"valor": medicion, "salida": encendido})');
    w('        time.sleep(MUESTREO_S)');
    w();
    w('if __name__ == "__main__":');
    w('    main()');
    return FirmwareListing(
      fileName: 'electroboard_${mission.id}.py',
      language: 'Python 3 (Linux)',
      code: b.toString(),
      libraries: const ['gpiozero'],
    );
  }

  // ------------------------------------------------------------------
  // Fragmentos por componente
  // ------------------------------------------------------------------

  static String _f(double v, [int decimals = 2]) => fmtCompact(v, maxDecimals: decimals).contains('.')
      ? fmtCompact(v, maxDecimals: decimals)
      : '${fmtCompact(v, maxDecimals: decimals)}.0';

  _Pins _pins(String controllerId) => switch (controllerId) {
        'arduino_uno' => const _Pins('A0', '7', '9'),
        'esp32_devkit' => const _Pins('34', '27', '25'),
        'esp8266_nodemcu' => const _Pins('A0', 'D6', 'D5'),
        'pico_w' => const _Pins('26', '14', '15'),
        'stm32_bluepill' => const _Pins('PA0', 'PB12', 'PA8'),
        _ => const _Pins('0', '1', '2'),
      };

  List<String> _sensorIncludes(String id) => switch (id) {
        'dht11' || 'dht22' => ['#include <DHT.h>'],
        'ds18b20' => ['#include <OneWire.h>', '#include <DallasTemperature.h>'],
        'bme280' => ['#include <Wire.h>', '#include <Adafruit_BME280.h>'],
        'max6675_k' => ['#include <max6675.h>'],
        'scd40' => ['#include <Wire.h>', '#include <SensirionI2CScd4x.h>'],
        'mhz19b' => ['#include <MHZ19.h>'],
        'ccs811' => ['#include <Wire.h>', '#include <Adafruit_CCS811.h>'],
        'mpu6050' => ['#include <Wire.h>', '#include <Adafruit_MPU6050.h>'],
        'adxl345' => ['#include <Wire.h>', '#include <Adafruit_ADXL345_U.h>'],
        _ => <String>[],
      };

  List<String> _sensorGlobals(String id) => switch (id) {
        'dht11' => ['DHT dht(PIN_SENSOR, DHT11);'],
        'dht22' => ['DHT dht(PIN_SENSOR, DHT22);'],
        'ds18b20' => ['OneWire bus(PIN_SENSOR);', 'DallasTemperature sondas(&bus);'],
        'bme280' => ['Adafruit_BME280 bme;'],
        'max6675_k' => ['MAX6675 termopar(18, 5, 19);   // SCK, CS, SO'],
        'scd40' => ['SensirionI2CScd4x scd4x;'],
        'mhz19b' => ['MHZ19 mhz;'],
        'ccs811' => ['Adafruit_CCS811 ccs;'],
        'mpu6050' => ['Adafruit_MPU6050 imu;'],
        'adxl345' => ['Adafruit_ADXL345_Unified acel(12345);'],
        _ => <String>[],
      };

  List<String> _sensorSetup(String id) => switch (id) {
        'dht11' || 'dht22' => ['dht.begin();'],
        'ds18b20' => ['sondas.begin();', 'sondas.setResolution(12);'],
        'bme280' => ['bme.begin(0x76);'],
        'scd40' => ['Wire.begin();', 'scd4x.begin(Wire);', 'scd4x.startPeriodicMeasurement();   // una lectura cada 5 s'],
        'mhz19b' => ['Serial2.begin(9600);', 'mhz.begin(Serial2);', 'mhz.autoCalibration(false);'],
        'ccs811' => ['ccs.begin();'],
        'mpu6050' => ['imu.begin();', 'imu.setFilterBandwidth(MPU6050_BAND_260_HZ);'],
        'adxl345' => ['acel.begin();', 'acel.setDataRate(ADXL345_DATARATE_3200_HZ);'],
        'hcsr04' || 'jsnsr04t' => ['pinMode(PIN_TRIGGER, OUTPUT);', 'pinMode(PIN_SENSOR, INPUT);'],
        'soil_resistive' => ['pinMode(PIN_SENSOR_VCC, OUTPUT);'],
        'sw420' => ['pinMode(PIN_SENSOR, INPUT);'],
        _ => <String>[],
      };

  List<String> _sensorRead(SensorSpec s, ControllerSpec c, bool conditioning, FirmwareStyle style) {
    final volts = conditioning ? '(raw * VREF / ADC_MAX) * DIVISOR' : 'raw * VREF / ADC_MAX';
    if (s.isAnalog && c.adcBits == 0) {
      return ['// ${c.name} no tiene ADC: esta lectura no es posible.', 'return NAN;'];
    }
    switch (s.id) {
      case 'lm35':
        return ['int raw = analogRead(PIN_SENSOR);', 'float voltios = $volts;', 'return voltios * 100.0;   // 10 mV/°C'];
      case 'ntc_10k':
        return [
          '// Divisor con resistencia fija de 10 kΩ y ecuación Beta (B = 3950).',
          'int raw = analogRead(PIN_SENSOR);',
          'if (raw <= 0 || raw >= ADC_MAX) return NAN;',
          'float r = 10000.0 * raw / (ADC_MAX - raw);',
          'float kelvin = 1.0 / (1.0 / 298.15 + log(r / 10000.0) / 3950.0);',
          'return kelvin - 273.15;',
        ];
      case 'dht11':
      case 'dht22':
        return ['float t = dht.readTemperature();', 'return isnan(t) ? NAN : t;'];
      case 'ds18b20':
        if (style == FirmwareStyle.blocking) {
          return [
            'sondas.requestTemperatures();   // bloquea unos 750 ms a 12 bits',
            'float t = sondas.getTempCByIndex(0);',
            'return (t == DEVICE_DISCONNECTED_C) ? NAN : t;',
          ];
        }
        return [
          '// Conversión asíncrona: se pide una y se lee la anterior, sin esperar.',
          'static bool primera = true;',
          'sondas.setWaitForConversion(false);',
          'float t = primera ? NAN : sondas.getTempCByIndex(0);',
          'sondas.requestTemperatures();',
          'primera = false;',
          'return (t == DEVICE_DISCONNECTED_C) ? NAN : t;',
        ];
      case 'bme280':
        return ['return bme.readTemperature();'];
      case 'max6675_k':
        return ['return termopar.readCelsius();'];
      case 'soil_capacitive':
        return [
          '// Calibración de dos puntos: mide en suelo seco y saturado y ajusta estos valores.',
          'const int SECO = ${((s.offsetV + s.sensitivity * 100) / c.adcVref * ((1 << c.adcBits) - 1)).round()};',
          'const int SATURADO = ${(s.offsetV / c.adcVref * ((1 << c.adcBits) - 1)).round()};',
          'int raw = analogRead(PIN_SENSOR);',
          'return constrain(map(raw, SECO, SATURADO, 0, 100), 0, 100);',
        ];
      case 'soil_resistive':
        return [
          'digitalWrite(PIN_SENSOR_VCC, HIGH);   // alimentar solo al medir reduce la corrosión',
          'delay(10);',
          'int raw = analogRead(PIN_SENSOR);',
          'digitalWrite(PIN_SENSOR_VCC, LOW);',
          'return 100.0 - 100.0 * raw / ADC_MAX;',
        ];
      case 'scd40':
        return [
          'uint16_t co2 = 0; float t, h;',
          'if (scd4x.readMeasurement(co2, t, h) != 0 || co2 == 0) return NAN;',
          'return co2;',
        ];
      case 'mhz19b':
        return ['int co2 = mhz.getCO2();', 'return (co2 <= 0) ? NAN : co2;'];
      case 'mq135':
        return [
          '// El MQ-135 no es selectivo: esta conversión es solo una aproximación.',
          'int raw = analogRead(PIN_SENSOR);',
          'float voltios = $volts;',
          'return voltios / 0.0025;',
        ];
      case 'ccs811':
        return [
          '// Atención: eCO₂ es una estimación a partir de compuestos volátiles.',
          'if (!ccs.available() || ccs.readData()) return NAN;',
          'return ccs.geteCO2();',
        ];
      case 'hcsr04':
      case 'jsnsr04t':
        return [
          'const float ALTURA_CM = 200.0;   // tanque de 2 m, sensor en la tapa',
          'digitalWrite(PIN_TRIGGER, LOW); delayMicroseconds(2);',
          'digitalWrite(PIN_TRIGGER, HIGH); delayMicroseconds(10);',
          'digitalWrite(PIN_TRIGGER, LOW);',
          'unsigned long eco = pulseIn(PIN_SENSOR, HIGH, 30000UL);',
          'if (eco == 0) return NAN;',
          'float distancia = eco * 0.0343 / 2.0;   // cm',
          'return constrain(100.0 * (ALTURA_CM - distancia) / ALTURA_CM, 0, 100);',
        ];
      case 'pressure_level':
        return [
          'int raw = analogRead(PIN_SENSOR);',
          'float voltios = $volts;',
          'return constrain((voltios - 0.5) / 4.0 * 100.0, 0, 100);   // 0.5 V vacío, 4.5 V lleno',
        ];
      case 'mpu6050':
      case 'adxl345':
        return [
          '// Velocidad RMS: se integra la aceleración en una ventana y se calcula la raíz cuadrática media.',
          'const int N = 256;',
          'float suma = 0, v = 0;',
          'for (int i = 0; i < N; i++) {',
          '  sensors_event_t e;',
          '  ${s.id == 'mpu6050' ? 'sensors_event_t g, tmp; imu.getEvent(&e, &g, &tmp);' : 'acel.getEvent(&e);'}',
          '  v += e.acceleration.z * (1.0 / 3200.0) * 1000.0;   // mm/s',
          '  suma += v * v;',
          '}',
          'return sqrt(suma / N);',
        ];
      case 'accel_4_20':
        return [
          '// 4–20 mA sobre 250 Ω = 1–5 V, equivalente a 0–50 mm/s.',
          'int raw = analogRead(PIN_SENSOR);',
          'float voltios = $volts;',
          'return (voltios - 1.0) / 4.0 * 50.0;',
        ];
      case 'sw420':
        return ['// Solo indica si hubo golpes: no mide la severidad.', 'return digitalRead(PIN_SENSOR) ? 1.0 : 0.0;'];
      default:
        return ['return NAN;   // lectura no implementada'];
    }
  }

  List<String> _actuatorWrite(ActuatorSpec a, ControllerSpec c) {
    switch (a.driver) {
      case 'relay':
        return [
          '// Módulo relé: solo encendido o apagado. Muchos módulos se activan con nivel bajo.',
          'digitalWrite(PIN_ACTUADOR, u >= 0.5 ? HIGH : LOW);',
        ];
      case 'mosfet_ll':
      case 'mosfet_std':
        return [
          if (a.driver == 'mosfet_std') '// ADVERTENCIA: el IRF540N no conduce por completo con ${fmtVolts(c.logicV)} en la compuerta.',
          '// MOSFET: el PWM regula la potencia media entregada a la carga.',
          'analogWrite(PIN_ACTUADOR, (int)(u * 255));',
        ];
      case 'gpio':
        return [
          '// ADVERTENCIA: la carga consume ${(a.loadA * 1000).round()} mA y un pin entrega ${c.gpioMaxMa.round()} mA como máximo.',
          '// Falta una etapa de potencia (MOSFET o relé) entre el pin y la carga.',
          'digitalWrite(PIN_ACTUADOR, u >= 0.5 ? HIGH : LOW);',
        ];
      case 'servo':
        return ['ventanilla.write((int)(u * 90));   // 0° cerrada, 90° abierta'];
      default:
        return ['digitalWrite(PIN_ACTUADOR, u >= 0.5 ? HIGH : LOW);'];
    }
  }

  List<String> _commIncludes(String tech, ControllerSpec c) => switch (tech) {
        'wifi' => [
            if (c.id == 'esp8266_nodemcu') '#include <ESP8266WiFi.h>' else '#include <WiFi.h>',
            '#include <PubSubClient.h>',
          ],
        'ble' => ['#include <BLEDevice.h>'],
        'lora' => ['#include <RadioLib.h>'],
        'lte' => ['#define TINY_GSM_MODEM_SIM7080', '#include <TinyGsmClient.h>'],
        'rs485' => ['#include <ModbusRTU.h>'],
        _ => <String>[],
      };

  List<String> _commGlobals(String tech) => switch (tech) {
        'wifi' => ['WiFiClient red;', 'PubSubClient mqtt(red);'],
        'lora' => ['SX1276 radio = new Module(18, 26, 14, 33);'],
        'lte' => ['TinyGsm modem(Serial1);'],
        'rs485' => ['ModbusRTU mb;'],
        'ble' => ['BLECharacteristic* caracteristica;'],
        _ => <String>[],
      };

  List<String> _commSetup(String tech) => switch (tech) {
        'wifi' => ['WiFi.begin(WIFI_SSID, WIFI_CLAVE);', 'mqtt.setServer(MQTT_BROKER, 8883);   // TLS'],
        'lora' => ['radio.begin(915.0);   // banda de 915 MHz', 'radio.setSpreadingFactor(9);'],
        'lte' => ['Serial1.begin(115200);', 'modem.restart();', 'modem.gprsConnect(APN);'],
        'rs485' => ['Serial2.begin(9600);', 'mb.begin(&Serial2);', 'mb.slave(1);', 'mb.addHreg(0, 0, 4);   // registros para el SCADA'],
        'ble' => ['BLEDevice::init("ElectroBoard");'],
        'usb' => ['// El reporte viaja por el mismo puerto serie.'],
        _ => <String>[],
      };

  List<String> _commSend(String tech) => switch (tech) {
        'none' => ['// Sin enlace: el dato solo queda en el equipo.', 'return false;'],
        'usb' => ['Serial.println(tema + " " + carga);', 'return true;'],
        'wifi' => [
            'if (!mqtt.connected() && !mqtt.connect("electroboard", MQTT_USUARIO, MQTT_CLAVE)) return false;',
            'return mqtt.publish(tema.c_str(), carga.c_str());',
          ],
        'ble' => ['caracteristica->setValue(carga.c_str());', 'caracteristica->notify();', 'return true;   // BLE no confirma la recepción'],
        'lora' => [
            '// LoRaWAN: mensajes de pocos bytes; se envía el valor compactado, no texto.',
            'return radio.transmit(carga) == RADIOLIB_ERR_NONE;',
          ],
        'lte' => [
            'if (tema.endsWith("alerta")) return modem.sendSMS(TELEFONO_RESPONSABLE, carga);',
            'return modem.isGprsConnected();   // aquí iría la publicación MQTT sobre GPRS',
          ],
        'rs485' => ['mb.Hreg(0, (uint16_t)(carga.length()));   // el PLC consulta los registros', 'return true;'],
        _ => ['return false;'],
      };

  List<String> _commLoop(String tech) => switch (tech) {
        'wifi' => ['mqtt.loop();'],
        'rs485' => ['mb.task();'],
        _ => <String>[],
      };
}

class _Pins {
  const _Pins(this.sensor, this.aux, this.actuator);

  final String sensor;
  final String aux;
  final String actuator;
}
