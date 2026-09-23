// Análisis eléctrico estático: cómo quedan conectados los bloques elegidos.
//
// Equivale a prepare() de tools/reference_engine.py. No simula el tiempo: decide
// qué rieles alimentan a cada bloque, si las tensiones lógicas coinciden, qué
// resolución efectiva tiene el sensor y si la etapa de potencia puede mover la carga.

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/design.dart';
import '../model/mission.dart';
import '../model/sim_result.dart';

/// Bloques concretos de un diseño completo.
class ResolvedDesign {
  final ControllerSpec controller;
  final SensorSpec sensor;
  final ActuatorSpec actuator;
  final CommSpec comm;
  final PowerSpec power;
  final SystemDesign design;

  const ResolvedDesign({
    required this.controller,
    required this.sensor,
    required this.actuator,
    required this.comm,
    required this.power,
    required this.design,
  });

  factory ResolvedDesign.of(Catalog catalog, SystemDesign d) {
    if (!d.isComplete) {
      throw ArgumentError('El diseño está incompleto.');
    }
    return ResolvedDesign(
      controller: catalog.controller(d.controllerId!),
      sensor: catalog.sensor(d.sensorId!),
      actuator: catalog.actuator(d.actuatorId!),
      comm: catalog.comm(d.commId!),
      power: catalog.powerSource(d.powerId!),
      design: d,
    );
  }

  LogicConfig get logic => design.logic;
}

bool _same(double a, double b) => (a - b).abs() < 1e-6;

class WiringAnalyzer {
  const WiringAnalyzer();

  WiringSetup analyze(Mission mission, ResolvedDesign r) {
    final c = r.controller;
    final s = r.sensor;
    final a = r.actuator;
    final k = r.comm;
    final p = r.power;
    final lg = r.logic;
    final variable = mission.variable;
    final rails = p.rails;
    final cond = r.design.conditioning;

    bool railAvailable(double v) => rails.any((x) => _same(x, v));

    final controllerAlive = c.supplyOptions.any(railAvailable);
    final controllerV = (railAvailable(5.0) && c.supplyOptions.any((v) => _same(v, 5.0))) ? 5.0 : 3.3;

    // --- sensor: riel de alimentación elegido ---
    double? supply;
    final sortedRails = [...rails]..sort((x, y) => y.compareTo(x));
    for (final v in [c.logicV, ...sortedRails]) {
      if (railAvailable(v) && v >= s.supplyMin - 1e-9 && v <= s.supplyMax + 1e-9) {
        supply = v;
        break;
      }
    }
    final sensorPowered = supply != null;
    final measuresVar = s.measures.contains(variable);
    final sensorLogic = s.logicV > 0 ? s.logicV : (supply ?? 0.0);
    var sensorDead = !sensorPowered || !measuresVar || !controllerAlive;
    var intermittent = 0.0;
    var levelMismatch = '';
    var noAdc = false;
    var overrange = false;
    double? satCap;
    var effRes = s.resolution;
    var adcNoise = 0.0;

    if (s.isAnalog) {
      if (c.adcBits == 0) {
        noAdc = true;
        sensorDead = true;
      } else {
        final outMax = math.min(s.outputMaxV, supply ?? 0.0);
        final lsbV = c.adcVref / math.pow(2, c.adcBits);
        var lsbUnits = lsbV / s.sensitivity;
        if (outMax > c.adcVref + 1e-9) {
          if (cond) {
            lsbUnits *= outMax / c.adcVref;
          } else {
            overrange = true;
            satCap = s.rangeMin + (c.adcVref - s.offsetV) / s.sensitivity;
          }
        }
        effRes = math.max(s.resolution, lsbUnits);
        adcNoise = c.adcErrorLsb * lsbUnits;
      }
    } else {
      if (!sensorDead && sensorLogic > 3.4 && c.logicV < 3.4 && !c.fiveVTolerant && !cond) {
        intermittent = 0.4;
        levelMismatch = 'high_to_low';
      } else if (!sensorDead && sensorLogic < 3.4 && c.logicV > 3.4 && !s.fiveVTolerant && !cond) {
        intermittent = 0.2;
        levelMismatch = 'low_to_high';
      }
    }

    var attenuation = 1.0;
    if (mission.signalFreqHz > 0) {
      final bw = s.bandwidthHz;
      attenuation = bw >= mission.signalFreqHz ? 1.0 : (bw > 0 ? bw / mission.signalFreqHz : 0.0);
    }
    final drift = s.driftPerDay * (lg.lowPower ? 0.5 : 1.0);

    // --- actuador ---
    final eff = a.effectOn(variable);
    final effectSign = eff == 0 ? 0 : (eff > 0 ? 1 : -1);
    final loadVOk = a.loadV == 0 || railAvailable(a.loadV);
    final driverSupplyOk = a.driverSupplyV == 0 || railAvailable(a.driverSupplyV);
    var gate = 1.0;
    if (a.driver == 'mosfet_std') {
      gate = c.logicV < 3.4 ? 0.25 : 0.6;
    }
    final gpioOver = a.driver == 'gpio' && a.loadA * 1000 > c.gpioMaxMa;
    final brownout = a.loadV > 0 && loadVOk && a.loadA > p.maxA + 1e-9;
    final relayLike = a.isRelay;
    final relayPwm = relayLike && lg.algorithm.isContinuous;
    final sleepPwmLoss = lg.lowPower && c.supportsDeepSleep && lg.algorithm.isContinuous && !relayLike;
    var base = 1.0;
    if (!loadVOk || !driverSupplyOk || brownout || !controllerAlive) {
      base = 0.0;
    }
    final actBase = base * gate * (sleepPwmLoss ? 0.1 : 1.0);

    // --- comunicación ---
    final site = mission.site;
    final tech = k.tech;
    final needsModule =
        tech != 'none' && tech != 'usb' && (k.builtInKey.isEmpty || !c.builtInComms.contains(k.builtInKey));
    final infraOk = tech == 'none' || site.infra.contains(k.infra);
    final rangeOk = tech == 'none' || site.distanceM <= k.rangeM;
    final commOk = tech != 'none' && infraOk && rangeOk && controllerAlive;
    var loss = k.lossBase + (site.linkPenalty[tech] ?? 0.0);
    if (rangeOk && k.rangeM > 0) {
      final q = site.distanceM / k.rangeM;
      loss += 0.3 * (q * q);
    }
    loss = math.min(loss, 0.95);

    // --- costos ---
    var cost = c.costPen + s.costPen + a.costPen + p.costPen;
    if (needsModule) cost += k.moduleCostPen;
    if (cond) cost += 4;

    return WiringSetup(
      controllerAlive: controllerAlive,
      controllerV: controllerV,
      sensorSupplyV: supply,
      sensorPowered: sensorPowered,
      sensorMeasuresVar: measuresVar,
      sensorLogicV: sensorLogic,
      sensorDead: sensorDead,
      intermittent: intermittent,
      levelMismatch: levelMismatch,
      noAdc: noAdc,
      overrange: overrange,
      satCap: satCap,
      effRes: effRes,
      noiseAmp: s.accuracy * 0.5 + adcNoise,
      bias: s.accuracy * 0.4,
      adcNoise: adcNoise,
      attenuation: attenuation,
      sensorDriftPerDay: drift,
      effectSign: effectSign,
      effect: eff,
      loadVOk: loadVOk,
      driverSupplyOk: driverSupplyOk,
      gateFactor: gate,
      gpioOver: gpioOver,
      brownout: brownout,
      relayLike: relayLike,
      relayPwm: relayPwm,
      sleepPwmLoss: sleepPwmLoss,
      actBase: actBase,
      commTech: tech,
      commNeedsModule: needsModule,
      infraOk: infraOk,
      rangeOk: rangeOk,
      commOk: commOk,
      loss: loss,
      commLatency: k.latencyS,
      commMinInterval: k.minIntervalS,
      costPen: cost,
      monthlyPen: k.monthlyPen,
    );
  }
}
