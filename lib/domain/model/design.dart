// Diseño que arma el estudiante: bloques elegidos y lógica del firmware.

import 'catalog.dart';

double _d(Object? v, [double fallback = 0.0]) => (v as num?)?.toDouble() ?? fallback;

enum ControlAlgorithm {
  onoff('onoff', 'Encendido/apagado', 'Enciende por debajo de la consigna y apaga por encima.'),
  hysteresis('hysteresis', 'Histéresis', 'Dos umbrales separados por una banda muerta.'),
  proportional('proportional', 'Proporcional', 'Salida PWM proporcional al error.'),
  pid('pid', 'PID', 'Proporcional, integral y derivativo sobre una salida PWM.'),
  trip('trip', 'Disparo con enclavamiento', 'Actúa al superar el umbral y queda enclavado hasta un rearme manual.');

  const ControlAlgorithm(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  bool get isContinuous => this == ControlAlgorithm.proportional || this == ControlAlgorithm.pid;

  static ControlAlgorithm fromKey(String key) =>
      ControlAlgorithm.values.firstWhere((a) => a.key == key, orElse: () => ControlAlgorithm.onoff);
}

enum FirmwareStyle {
  blocking('blocking', 'Bucle bloqueante', 'delay() y esperas: simple, pero detiene el control mientras espera.'),
  nonblocking('nonblocking', 'Bucle no bloqueante', 'millis() y máquinas de estado: el control nunca se detiene.'),
  rtos('rtos', 'RTOS con tareas', 'FreeRTOS separa el control y la comunicación en tareas con prioridad.');

  const FirmwareStyle(this.key, this.label, this.description);

  final String key;
  final String label;
  final String description;

  static FirmwareStyle fromKey(String key) =>
      FirmwareStyle.values.firstWhere((f) => f.key == key, orElse: () => FirmwareStyle.blocking);
}

class LogicConfig {
  final ControlAlgorithm algorithm;
  final double setpoint;
  final double hysteresis;
  final double kp;
  final double ki;
  final double kd;
  final double samplingS;
  final double reportS;
  final FirmwareStyle firmware;
  final bool lowPower;
  final bool retry;

  const LogicConfig({
    required this.algorithm,
    required this.setpoint,
    required this.hysteresis,
    required this.kp,
    required this.ki,
    required this.kd,
    required this.samplingS,
    required this.reportS,
    required this.firmware,
    required this.lowPower,
    required this.retry,
  });

  LogicConfig copyWith({
    ControlAlgorithm? algorithm,
    double? setpoint,
    double? hysteresis,
    double? kp,
    double? ki,
    double? kd,
    double? samplingS,
    double? reportS,
    FirmwareStyle? firmware,
    bool? lowPower,
    bool? retry,
  }) =>
      LogicConfig(
        algorithm: algorithm ?? this.algorithm,
        setpoint: setpoint ?? this.setpoint,
        hysteresis: hysteresis ?? this.hysteresis,
        kp: kp ?? this.kp,
        ki: ki ?? this.ki,
        kd: kd ?? this.kd,
        samplingS: samplingS ?? this.samplingS,
        reportS: reportS ?? this.reportS,
        firmware: firmware ?? this.firmware,
        lowPower: lowPower ?? this.lowPower,
        retry: retry ?? this.retry,
      );

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm.key,
        'setpoint': setpoint,
        'hysteresis': hysteresis,
        'kp': kp,
        'ki': ki,
        'kd': kd,
        'samplingS': samplingS,
        'reportS': reportS,
        'firmware': firmware.key,
        'lowPower': lowPower,
        'retry': retry,
      };

  factory LogicConfig.fromJson(Map<String, dynamic> j) => LogicConfig(
        algorithm: ControlAlgorithm.fromKey(j['algorithm']?.toString() ?? 'onoff'),
        setpoint: _d(j['setpoint']),
        hysteresis: _d(j['hysteresis']),
        kp: _d(j['kp']),
        ki: _d(j['ki']),
        kd: _d(j['kd']),
        samplingS: _d(j['samplingS'], 10),
        reportS: _d(j['reportS'], 60),
        firmware: FirmwareStyle.fromKey(j['firmware']?.toString() ?? 'blocking'),
        lowPower: j['lowPower'] == true,
        retry: j['retry'] == true,
      );
}

/// Un sistema completo o en construcción. Los bloques vacíos son null.
class SystemDesign {
  final String? sensorId;
  final String? controllerId;
  final String? actuatorId;
  final String? commId;
  final String? powerId;
  final bool conditioning;
  final LogicConfig logic;

  const SystemDesign({
    this.sensorId,
    this.controllerId,
    this.actuatorId,
    this.commId,
    this.powerId,
    this.conditioning = false,
    required this.logic,
  });

  bool get isComplete =>
      sensorId != null && controllerId != null && actuatorId != null && commId != null && powerId != null;

  int get filledSlots =>
      [sensorId, controllerId, actuatorId, commId, powerId].where((e) => e != null).length;

  String? partId(PartKind kind) => switch (kind) {
        PartKind.sensor => sensorId,
        PartKind.controller => controllerId,
        PartKind.actuator => actuatorId,
        PartKind.comm => commId,
        PartKind.power => powerId,
      };

  SystemDesign withPart(PartKind kind, String id) => SystemDesign(
        sensorId: kind == PartKind.sensor ? id : sensorId,
        controllerId: kind == PartKind.controller ? id : controllerId,
        actuatorId: kind == PartKind.actuator ? id : actuatorId,
        commId: kind == PartKind.comm ? id : commId,
        powerId: kind == PartKind.power ? id : powerId,
        conditioning: conditioning,
        logic: logic,
      );

  SystemDesign copyWith({bool? conditioning, LogicConfig? logic}) => SystemDesign(
        sensorId: sensorId,
        controllerId: controllerId,
        actuatorId: actuatorId,
        commId: commId,
        powerId: powerId,
        conditioning: conditioning ?? this.conditioning,
        logic: logic ?? this.logic,
      );

  Map<String, dynamic> toJson() => {
        'sensorId': sensorId,
        'controllerId': controllerId,
        'actuatorId': actuatorId,
        'commId': commId,
        'powerId': powerId,
        'conditioning': conditioning,
        'logic': logic.toJson(),
      };

  factory SystemDesign.fromJson(Map<String, dynamic> j) => SystemDesign(
        sensorId: j['sensorId'] as String?,
        controllerId: j['controllerId'] as String?,
        actuatorId: j['actuatorId'] as String?,
        commId: j['commId'] as String?,
        powerId: j['powerId'] as String?,
        conditioning: j['conditioning'] == true,
        logic: LogicConfig.fromJson(j['logic'] as Map<String, dynamic>),
      );
}
