// Misiones de diseño: el problema que el estudiante debe resolver.
//
// Cada misión describe la planta física (cómo evoluciona la variable), los
// requisitos que el sistema debe cumplir, el sitio (infraestructura y distancia)
// y el catálogo curado de componentes disponibles.

import 'design.dart';

double _d(Object? v) => (v as num?)?.toDouble() ?? 0.0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;
String _s(Object? v) => v?.toString() ?? '';
List<String> _ls(Object? v) =>
    (v as List<dynamic>? ?? const <dynamic>[]).map((e) => e.toString()).toList();
List<double> _ld(Object? v) =>
    (v as List<dynamic>? ?? const <dynamic>[]).map((e) => (e as num).toDouble()).toList();

class Plant {
  final double x0;
  final double tauS;
  final double ambient;
  final double ambientAmp;
  final double periodS;
  final double drift;
  final double driftAmp;
  final double gain;
  final double minX;
  final double maxX;

  const Plant({
    required this.x0,
    required this.tauS,
    required this.ambient,
    required this.ambientAmp,
    required this.periodS,
    required this.drift,
    required this.driftAmp,
    required this.gain,
    required this.minX,
    required this.maxX,
  });

  factory Plant.fromJson(Map<String, dynamic> j) => Plant(
        x0: _d(j['x0']),
        tauS: _d(j['tauS']),
        ambient: _d(j['ambient']),
        ambientAmp: _d(j['ambientAmp']),
        periodS: _d(j['periodS']),
        drift: _d(j['drift']),
        driftAmp: _d(j['driftAmp']),
        gain: _d(j['gain']),
        minX: _d(j['minX']),
        maxX: _d(j['maxX']),
      );
}

class Band {
  final double low;
  final double high;
  final double setpoint;

  const Band({required this.low, required this.high, required this.setpoint});

  double get width => high - low;
  double get half => (high - low) / 2.0;
  bool contains(double x) => x >= low && x <= high;

  factory Band.fromJson(Map<String, dynamic> j) =>
      Band(low: _d(j['low']), high: _d(j['high']), setpoint: _d(j['setpoint']));
}

class AlarmSpec {
  final double threshold;
  final bool up;
  final String label;

  const AlarmSpec({required this.threshold, required this.up, required this.label});

  factory AlarmSpec.fromJson(Map<String, dynamic> j) =>
      AlarmSpec(threshold: _d(j['threshold']), up: _s(j['dir']) == 'up', label: _s(j['label']));
}

enum EventType { disturbance, ambientStep, actuatorOutage, linkOutage }

class MissionEvent {
  final EventType type;
  final double atS;
  final double durS;
  final double value;
  final double rampS;
  final String label;

  const MissionEvent({
    required this.type,
    required this.atS,
    required this.durS,
    required this.value,
    required this.rampS,
    required this.label,
  });

  bool activeAt(double t) => t >= atS && t < atS + durS;
  double get endS => atS + durS;

  factory MissionEvent.fromJson(Map<String, dynamic> j) {
    final type = switch (_s(j['type'])) {
      'disturbance' => EventType.disturbance,
      'ambient_step' => EventType.ambientStep,
      'actuator_outage' => EventType.actuatorOutage,
      _ => EventType.linkOutage,
    };
    return MissionEvent(
      type: type,
      atS: _d(j['atS']),
      durS: _d(j['durS']),
      value: _d(j['value']),
      rampS: _d(j['rampS']),
      label: _s(j['label']),
    );
  }
}

class Requirements {
  final double minTimeInBandPct;
  final double maxAlarmLatencyS;
  final double maxActionLatencyS;
  final double reportEveryS;
  final double minDeliveryPct;
  final double budgetPen;
  final bool mainsAvailable;
  final double minAutonomyDays;
  final bool remoteAlarm;
  final bool requiresLatch;
  final bool needsLinux;

  const Requirements({
    required this.minTimeInBandPct,
    required this.maxAlarmLatencyS,
    required this.maxActionLatencyS,
    required this.reportEveryS,
    required this.minDeliveryPct,
    required this.budgetPen,
    required this.mainsAvailable,
    required this.minAutonomyDays,
    required this.remoteAlarm,
    required this.requiresLatch,
    required this.needsLinux,
  });

  factory Requirements.fromJson(Map<String, dynamic> j) => Requirements(
        minTimeInBandPct: _d(j['minTimeInBandPct']),
        maxAlarmLatencyS: _d(j['maxAlarmLatencyS']),
        maxActionLatencyS: _d(j['maxActionLatencyS']),
        reportEveryS: _d(j['reportEveryS']),
        minDeliveryPct: _d(j['minDeliveryPct']),
        budgetPen: _d(j['budgetPen']),
        mainsAvailable: j['mainsAvailable'] == true,
        minAutonomyDays: _d(j['minAutonomyDays']),
        remoteAlarm: j['remoteAlarm'] == true,
        requiresLatch: j['requiresLatch'] == true,
        needsLinux: j['needsLinux'] == true,
      );
}

class Site {
  final double distanceM;
  final List<String> infra;
  final Map<String, double> linkPenalty;
  final String description;

  const Site({
    required this.distanceM,
    required this.infra,
    required this.linkPenalty,
    required this.description,
  });

  factory Site.fromJson(Map<String, dynamic> j) {
    final raw = j['linkPenalty'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return Site(
      distanceM: _d(j['distanceM']),
      infra: _ls(j['infra']),
      linkPenalty: raw.map((k, v) => MapEntry(k, (v as num).toDouble())),
      description: _s(j['description']),
    );
  }
}

class Pools {
  final List<String> sensors;
  final List<String> controllers;
  final List<String> actuators;
  final List<String> comms;
  final List<String> power;

  const Pools({
    required this.sensors,
    required this.controllers,
    required this.actuators,
    required this.comms,
    required this.power,
  });

  factory Pools.fromJson(Map<String, dynamic> j) => Pools(
        sensors: _ls(j['sensors']),
        controllers: _ls(j['controllers']),
        actuators: _ls(j['actuators']),
        comms: _ls(j['comms']),
        power: _ls(j['power']),
      );
}

/// Límites del editor de lógica para una misión concreta.
class LogicLimits {
  final List<ControlAlgorithm> algorithms;
  final List<double> samplingOptions;
  final List<double> reportOptions;
  final double maxGoodSamplingS;
  final double setpointMin;
  final double setpointMax;
  final double setpointStep;
  final double hystMax;
  final double hystStep;
  final double kpMax;
  final double kpStep;
  final double kiMax;
  final double kiStep;
  final double kdMax;
  final double kdStep;

  const LogicLimits({
    required this.algorithms,
    required this.samplingOptions,
    required this.reportOptions,
    required this.maxGoodSamplingS,
    required this.setpointMin,
    required this.setpointMax,
    required this.setpointStep,
    required this.hystMax,
    required this.hystStep,
    required this.kpMax,
    required this.kpStep,
    required this.kiMax,
    required this.kiStep,
    required this.kdMax,
    required this.kdStep,
  });

  factory LogicLimits.fromJson(Map<String, dynamic> j) => LogicLimits(
        algorithms: _ls(j['algorithms']).map(ControlAlgorithm.fromKey).toList(),
        samplingOptions: _ld(j['samplingOptions']),
        reportOptions: _ld(j['reportOptions']),
        maxGoodSamplingS: _d(j['maxGoodSamplingS']),
        setpointMin: _d(j['setpointMin']),
        setpointMax: _d(j['setpointMax']),
        setpointStep: _d(j['setpointStep']),
        hystMax: _d(j['hystMax']),
        hystStep: _d(j['hystStep']),
        kpMax: _d(j['kpMax']),
        kpStep: _d(j['kpStep']),
        kiMax: _d(j['kiMax']),
        kiStep: _d(j['kiStep']),
        kdMax: _d(j['kdMax']),
        kdStep: _d(j['kdStep']),
      );
}

class Mission {
  final String id;
  final int order;
  final String code;
  final String title;
  final String place;
  final String difficulty;
  final List<String> modules;
  final String variable;
  final String variableLabel;
  final String unit;
  final int decimals;
  final String story;
  final String goal;
  final int direction;
  final Band band;
  final double sensorRangeMin;
  final double sensorRangeMax;
  final AlarmSpec alarm;
  final Plant plant;
  final double horizonS;
  final double dtS;
  final double settleS;
  final double signalFreqHz;
  final String environment;
  final int seed;
  final List<MissionEvent> events;
  final Requirements requirements;
  final Site site;
  final Pools pools;
  final LogicLimits logic;
  final LogicConfig defaultLogic;
  final List<String> hints;
  final List<String> lessonIds;
  final SystemDesign referenceDesign;

  const Mission({
    required this.id,
    required this.order,
    required this.code,
    required this.title,
    required this.place,
    required this.difficulty,
    required this.modules,
    required this.variable,
    required this.variableLabel,
    required this.unit,
    required this.decimals,
    required this.story,
    required this.goal,
    required this.direction,
    required this.band,
    required this.sensorRangeMin,
    required this.sensorRangeMax,
    required this.alarm,
    required this.plant,
    required this.horizonS,
    required this.dtS,
    required this.settleS,
    required this.signalFreqHz,
    required this.environment,
    required this.seed,
    required this.events,
    required this.requirements,
    required this.site,
    required this.pools,
    required this.logic,
    required this.defaultLogic,
    required this.hints,
    required this.lessonIds,
    required this.referenceDesign,
  });

  bool get isBatteryMission => !requirements.mainsAvailable;

  /// Texto del ambiente para los mensajes del evaluador.
  String get environmentLabel => switch (environment) {
        'humid' => 'húmedo',
        'industrial' => 'industrial, con polvo y ruido eléctrico',
        'outdoor' => 'a la intemperie',
        _ => 'interior',
      };

  factory Mission.fromJson(Map<String, dynamic> j) {
    final range = j['sensorRange'] as Map<String, dynamic>;
    return Mission(
      id: _s(j['id']),
      order: _i(j['order']),
      code: _s(j['code']),
      title: _s(j['title']),
      place: _s(j['place']),
      difficulty: _s(j['difficulty']),
      modules: _ls(j['modules']),
      variable: _s(j['variable']),
      variableLabel: _s(j['variableLabel']),
      unit: _s(j['unit']),
      decimals: _i(j['decimals']),
      story: _s(j['story']),
      goal: _s(j['goal']),
      direction: _i(j['direction']),
      band: Band.fromJson(j['band'] as Map<String, dynamic>),
      sensorRangeMin: _d(range['min']),
      sensorRangeMax: _d(range['max']),
      alarm: AlarmSpec.fromJson(j['alarm'] as Map<String, dynamic>),
      plant: Plant.fromJson(j['plant'] as Map<String, dynamic>),
      horizonS: _d(j['horizonS']),
      dtS: _d(j['dtS']),
      settleS: _d(j['settleS']),
      signalFreqHz: _d(j['signalFreqHz']),
      environment: _s(j['environment']),
      seed: _i(j['seed']),
      events: (j['events'] as List<dynamic>)
          .map((e) => MissionEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      requirements: Requirements.fromJson(j['requirements'] as Map<String, dynamic>),
      site: Site.fromJson(j['site'] as Map<String, dynamic>),
      pools: Pools.fromJson(j['pools'] as Map<String, dynamic>),
      logic: LogicLimits.fromJson(j['logic'] as Map<String, dynamic>),
      defaultLogic: LogicConfig.fromJson(j['defaultLogic'] as Map<String, dynamic>),
      hints: _ls(j['hints']),
      lessonIds: _ls(j['lessonIds']),
      referenceDesign: SystemDesign.fromJson(j['referenceDesign'] as Map<String, dynamic>),
    );
  }
}
