// Resultado de conectar los bloques (cableado) y de simular el sistema en el tiempo.

/// Cómo quedan conectados los bloques del diseño. Lo calcula WiringAnalyzer
/// antes de simular; el evaluador lo usa para emitir sus reglas.
class WiringSetup {
  final bool controllerAlive;
  final double controllerV;
  final double? sensorSupplyV;
  final bool sensorPowered;
  final bool sensorMeasuresVar;
  final double sensorLogicV;
  final bool sensorDead;
  final double intermittent;
  final String levelMismatch; // '', 'high_to_low', 'low_to_high'
  final bool noAdc;
  final bool overrange;
  final double? satCap;
  final double effRes;
  final double noiseAmp;
  final double bias;
  final double adcNoise;
  final double attenuation;
  final double sensorDriftPerDay;
  final int effectSign;
  final double effect;
  final bool loadVOk;
  final bool driverSupplyOk;
  final double gateFactor;
  final bool gpioOver;
  final bool brownout;
  final bool relayLike;
  final bool relayPwm;
  final bool sleepPwmLoss;
  final double actBase;
  final String commTech;
  final bool commNeedsModule;
  final bool infraOk;
  final bool rangeOk;
  final bool commOk;
  final double loss;
  final double commLatency;
  final double commMinInterval;
  final double costPen;
  final double monthlyPen;

  const WiringSetup({
    required this.controllerAlive,
    required this.controllerV,
    required this.sensorSupplyV,
    required this.sensorPowered,
    required this.sensorMeasuresVar,
    required this.sensorLogicV,
    required this.sensorDead,
    required this.intermittent,
    required this.levelMismatch,
    required this.noAdc,
    required this.overrange,
    required this.satCap,
    required this.effRes,
    required this.noiseAmp,
    required this.bias,
    required this.adcNoise,
    required this.attenuation,
    required this.sensorDriftPerDay,
    required this.effectSign,
    required this.effect,
    required this.loadVOk,
    required this.driverSupplyOk,
    required this.gateFactor,
    required this.gpioOver,
    required this.brownout,
    required this.relayLike,
    required this.relayPwm,
    required this.sleepPwmLoss,
    required this.actBase,
    required this.commTech,
    required this.commNeedsModule,
    required this.infraOk,
    required this.rangeOk,
    required this.commOk,
    required this.loss,
    required this.commLatency,
    required this.commMinInterval,
    required this.costPen,
    required this.monthlyPen,
  });
}

enum SimEventKind { alarm, pinDamage }

class SimEvent {
  final double t;
  final SimEventKind kind;

  const SimEvent(this.t, this.kind);
}

/// Serie temporal submuestreada (unos 600 puntos) para graficar.
class SimSeries {
  final List<double> t;
  final List<double> x;
  final List<double?> m;
  final List<double> u;

  const SimSeries({required this.t, required this.x, required this.m, required this.u});

  int get length => t.length;
}

class SimMetrics {
  final double timeInBandPct;
  final double maxDeviation;
  final double switchesPerHour;

  /// null: la variable real nunca cruzó el umbral. infinity: la alerta nunca llegó.
  final double? alarmLatencyS;
  final double? actionLatencyS;
  final int falseAlarms;
  final int alarmsSent;
  final double deliveredPct;
  final int delivered;
  final int expected;
  final int lost;
  final int suppressed;
  final double energyWhDay;

  /// null cuando la misión funciona con red eléctrica.
  final double? autonomyDays;
  final double costPen;
  final double monthlyPen;
  final double? rmsError;
  final double saturationPct;
  final int resets;
  final bool pinDamaged;
  final double stallS;
  final int validReadings;

  const SimMetrics({
    required this.timeInBandPct,
    required this.maxDeviation,
    required this.switchesPerHour,
    required this.alarmLatencyS,
    required this.actionLatencyS,
    required this.falseAlarms,
    required this.alarmsSent,
    required this.deliveredPct,
    required this.delivered,
    required this.expected,
    required this.lost,
    required this.suppressed,
    required this.energyWhDay,
    required this.autonomyDays,
    required this.costPen,
    required this.monthlyPen,
    required this.rmsError,
    required this.saturationPct,
    required this.resets,
    required this.pinDamaged,
    required this.stallS,
    required this.validReadings,
  });
}

class SimResult {
  final WiringSetup wiring;
  final SimMetrics metrics;
  final SimSeries series;
  final List<SimEvent> events;

  const SimResult({
    required this.wiring,
    required this.metrics,
    required this.series,
    required this.events,
  });
}
