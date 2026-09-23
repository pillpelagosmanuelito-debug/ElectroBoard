// Especificaciones de componentes del catálogo de ElectroBoard.
//
// Los datos provienen de assets/data/components.json. Cada clase refleja las
// propiedades eléctricas que el simulador y el evaluador necesitan.

double _d(Object? v) => (v as num?)?.toDouble() ?? 0.0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
bool _b(Object? v) => v == true;
String _s(Object? v) => v?.toString() ?? '';
List<String> _ls(Object? v) =>
    (v as List<dynamic>? ?? const <dynamic>[]).map((e) => e.toString()).toList();
List<double> _ld(Object? v) =>
    (v as List<dynamic>? ?? const <dynamic>[]).map((e) => (e as num).toDouble()).toList();

/// Categoría de bloque en el tablero de diseño.
enum PartKind { sensor, controller, actuator, comm, power }

/// Datos comunes a cualquier componente seleccionable.
abstract class PartSpec {
  String get id;
  String get name;
  String get summary;
  double get costPen;
  PartKind get kind;
}

class ControllerSpec implements PartSpec {
  @override
  final String id;
  @override
  final String name;
  final String chip;
  final double logicV;
  final bool fiveVTolerant;
  final List<double> supplyOptions;
  final int adcBits;
  final double adcVref;
  final double adcErrorLsb;
  final int adcChannels;
  final int ramKb;
  final int flashKb;
  final double gpioMaxMa;
  final List<String> builtInComms;
  final double activeMa;
  final double sleepMa;
  final bool supportsDeepSleep;
  final bool rtosCapable;
  final bool isLinux;
  @override
  final double costPen;
  @override
  final String summary;
  final List<String> strengths;
  final List<String> limits;

  const ControllerSpec({
    required this.id,
    required this.name,
    required this.chip,
    required this.logicV,
    required this.fiveVTolerant,
    required this.supplyOptions,
    required this.adcBits,
    required this.adcVref,
    required this.adcErrorLsb,
    required this.adcChannels,
    required this.ramKb,
    required this.flashKb,
    required this.gpioMaxMa,
    required this.builtInComms,
    required this.activeMa,
    required this.sleepMa,
    required this.supportsDeepSleep,
    required this.rtosCapable,
    required this.isLinux,
    required this.costPen,
    required this.summary,
    required this.strengths,
    required this.limits,
  });

  @override
  PartKind get kind => PartKind.controller;

  factory ControllerSpec.fromJson(Map<String, dynamic> j) => ControllerSpec(
        id: _s(j['id']),
        name: _s(j['name']),
        chip: _s(j['chip']),
        logicV: _d(j['logicV']),
        fiveVTolerant: _b(j['fiveVTolerant']),
        supplyOptions: _ld(j['supplyOptions']),
        adcBits: _i(j['adcBits']),
        adcVref: _d(j['adcVref']),
        adcErrorLsb: _d(j['adcErrorLsb']),
        adcChannels: _i(j['adcChannels']),
        ramKb: _i(j['ramKb']),
        flashKb: _i(j['flashKb']),
        gpioMaxMa: _d(j['gpioMaxMa']),
        builtInComms: _ls(j['builtInComms']),
        activeMa: _d(j['activeMa']),
        sleepMa: _d(j['sleepMa']),
        supportsDeepSleep: _b(j['supportsDeepSleep']),
        rtosCapable: _b(j['rtosCapable']),
        isLinux: _b(j['isLinux']),
        costPen: _d(j['costPen']),
        summary: _s(j['summary']),
        strengths: _ls(j['strengths']),
        limits: _ls(j['limits']),
      );
}

class SensorSpec implements PartSpec {
  @override
  final String id;
  @override
  final String name;
  final String kindLabel;
  final List<String> measures;
  final String interface;
  final double supplyMin;
  final double supplyMax;
  final double logicV;
  final bool fiveVTolerant;
  final double outputMaxV;
  final double sensitivity;
  final double offsetV;
  final double rangeMin;
  final double rangeMax;
  final double accuracy;
  final double resolution;
  final double timeConstantS;
  final double minIntervalS;
  final double convTimeS;
  final double currentMa;
  final bool sealed;
  final double bandwidthHz;
  final double driftPerDay;
  @override
  final double costPen;
  @override
  final String summary;
  final String notes;

  const SensorSpec({
    required this.id,
    required this.name,
    required this.kindLabel,
    required this.measures,
    required this.interface,
    required this.supplyMin,
    required this.supplyMax,
    required this.logicV,
    required this.fiveVTolerant,
    required this.outputMaxV,
    required this.sensitivity,
    required this.offsetV,
    required this.rangeMin,
    required this.rangeMax,
    required this.accuracy,
    required this.resolution,
    required this.timeConstantS,
    required this.minIntervalS,
    required this.convTimeS,
    required this.currentMa,
    required this.sealed,
    required this.bandwidthHz,
    required this.driftPerDay,
    required this.costPen,
    required this.summary,
    required this.notes,
  });

  @override
  PartKind get kind => PartKind.sensor;

  bool get isAnalog => interface == 'analog';

  factory SensorSpec.fromJson(Map<String, dynamic> j) => SensorSpec(
        id: _s(j['id']),
        name: _s(j['name']),
        kindLabel: _s(j['kind']),
        measures: _ls(j['measures']),
        interface: _s(j['interface']),
        supplyMin: _d(j['supplyMin']),
        supplyMax: _d(j['supplyMax']),
        logicV: _d(j['logicV']),
        fiveVTolerant: _b(j['fiveVTolerant']),
        outputMaxV: _d(j['outputMaxV']),
        sensitivity: _d(j['sensitivity']),
        offsetV: _d(j['offsetV']),
        rangeMin: _d(j['rangeMin']),
        rangeMax: _d(j['rangeMax']),
        accuracy: _d(j['accuracy']),
        resolution: _d(j['resolution']),
        timeConstantS: _d(j['timeConstantS']),
        minIntervalS: _d(j['minIntervalS']),
        convTimeS: _d(j['convTimeS']),
        currentMa: _d(j['currentMa']),
        sealed: _b(j['sealed']),
        bandwidthHz: _d(j['bandwidthHz']),
        driftPerDay: _d(j['driftPerDay']),
        costPen: _d(j['costPen']),
        summary: _s(j['summary']),
        notes: _s(j['notes']),
      );
}

class ActuatorSpec implements PartSpec {
  @override
  final String id;
  @override
  final String name;
  final String role;
  final Map<String, double> effects;
  final String driver;
  final double loadV;
  final double loadA;
  final double driverSupplyV;
  final bool pwmCapable;
  final double maxSwitchesPerHour;
  final bool switchLimitCritical;
  @override
  final double costPen;
  @override
  final String summary;
  final String notes;

  const ActuatorSpec({
    required this.id,
    required this.name,
    required this.role,
    required this.effects,
    required this.driver,
    required this.loadV,
    required this.loadA,
    required this.driverSupplyV,
    required this.pwmCapable,
    required this.maxSwitchesPerHour,
    required this.switchLimitCritical,
    required this.costPen,
    required this.summary,
    required this.notes,
  });

  @override
  PartKind get kind => PartKind.actuator;

  bool get isRelay => driver == 'relay';

  double effectOn(String variable) => effects[variable] ?? 0.0;

  factory ActuatorSpec.fromJson(Map<String, dynamic> j) {
    final raw = (j['effects'] as Map<String, dynamic>? ?? const <String, dynamic>{});
    return ActuatorSpec(
      id: _s(j['id']),
      name: _s(j['name']),
      role: _s(j['role']),
      effects: raw.map((k, v) => MapEntry(k, (v as num).toDouble())),
      driver: _s(j['driver']),
      loadV: _d(j['loadV']),
      loadA: _d(j['loadA']),
      driverSupplyV: _d(j['driverSupplyV']),
      pwmCapable: _b(j['pwmCapable']),
      maxSwitchesPerHour: _d(j['maxSwitchesPerHour']),
      switchLimitCritical: _b(j['switchLimitCritical']),
      costPen: _d(j['costPen']),
      summary: _s(j['summary']),
      notes: _s(j['notes']),
    );
  }
}

class CommSpec implements PartSpec {
  @override
  final String id;
  @override
  final String name;
  final String tech;
  final String builtInKey;
  final double moduleCostPen;
  final double monthlyPen;
  final double rangeM;
  final String infra;
  final double latencyS;
  final double lossBase;
  final double txJ;
  final double wakeJ;
  final double idleMa;
  final double minIntervalS;
  @override
  final String summary;
  final String notes;

  const CommSpec({
    required this.id,
    required this.name,
    required this.tech,
    required this.builtInKey,
    required this.moduleCostPen,
    required this.monthlyPen,
    required this.rangeM,
    required this.infra,
    required this.latencyS,
    required this.lossBase,
    required this.txJ,
    required this.wakeJ,
    required this.idleMa,
    required this.minIntervalS,
    required this.summary,
    required this.notes,
  });

  @override
  PartKind get kind => PartKind.comm;

  /// El costo del enlace depende del controlador (radio integrada o módulo).
  @override
  double get costPen => moduleCostPen;

  bool get isNone => tech == 'none';

  factory CommSpec.fromJson(Map<String, dynamic> j) => CommSpec(
        id: _s(j['id']),
        name: _s(j['name']),
        tech: _s(j['tech']),
        builtInKey: _s(j['builtInKey']),
        moduleCostPen: _d(j['moduleCostPen']),
        monthlyPen: _d(j['monthlyPen']),
        rangeM: _d(j['rangeM']),
        infra: _s(j['infra']),
        latencyS: _d(j['latencyS']),
        lossBase: _d(j['lossBase']),
        txJ: _d(j['txJ']),
        wakeJ: _d(j['wakeJ']),
        idleMa: _d(j['idleMa']),
        minIntervalS: _d(j['minIntervalS']),
        summary: _s(j['summary']),
        notes: _s(j['notes']),
      );
}

class PowerSpec implements PartSpec {
  @override
  final String id;
  @override
  final String name;
  final List<double> rails;
  final double maxA;
  final bool mains;
  final double batteryWh;
  final double solarWhDay;
  @override
  final double costPen;
  @override
  final String summary;

  const PowerSpec({
    required this.id,
    required this.name,
    required this.rails,
    required this.maxA,
    required this.mains,
    required this.batteryWh,
    required this.solarWhDay,
    required this.costPen,
    required this.summary,
  });

  @override
  PartKind get kind => PartKind.power;

  bool hasRail(double v) => rails.any((r) => (r - v).abs() < 1e-6);

  factory PowerSpec.fromJson(Map<String, dynamic> j) => PowerSpec(
        id: _s(j['id']),
        name: _s(j['name']),
        rails: _ld(j['rails']),
        maxA: _d(j['maxA']),
        mains: _b(j['mains']),
        batteryWh: _d(j['batteryWh']),
        solarWhDay: _d(j['solarWhDay']),
        costPen: _d(j['costPen']),
        summary: _s(j['summary']),
      );
}

/// Catálogo completo de componentes.
class Catalog {
  final List<ControllerSpec> controllers;
  final List<SensorSpec> sensors;
  final List<ActuatorSpec> actuators;
  final List<CommSpec> comms;
  final List<PowerSpec> power;

  const Catalog({
    required this.controllers,
    required this.sensors,
    required this.actuators,
    required this.comms,
    required this.power,
  });

  factory Catalog.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) f) =>
        (j[key] as List<dynamic>).map((e) => f(e as Map<String, dynamic>)).toList();
    return Catalog(
      controllers: list('controllers', ControllerSpec.fromJson),
      sensors: list('sensors', SensorSpec.fromJson),
      actuators: list('actuators', ActuatorSpec.fromJson),
      comms: list('comms', CommSpec.fromJson),
      power: list('power', PowerSpec.fromJson),
    );
  }

  ControllerSpec controller(String id) => controllers.firstWhere((e) => e.id == id);
  SensorSpec sensor(String id) => sensors.firstWhere((e) => e.id == id);
  ActuatorSpec actuator(String id) => actuators.firstWhere((e) => e.id == id);
  CommSpec comm(String id) => comms.firstWhere((e) => e.id == id);
  PowerSpec powerSource(String id) => power.firstWhere((e) => e.id == id);

  /// Busca cualquier componente por categoría e identificador.
  PartSpec part(PartKind kind, String id) {
    switch (kind) {
      case PartKind.sensor:
        return sensor(id);
      case PartKind.controller:
        return controller(id);
      case PartKind.actuator:
        return actuator(id);
      case PartKind.comm:
        return comm(id);
      case PartKind.power:
        return powerSource(id);
    }
  }
}
