// Evaluador de diseño: reglas deterministas y explicables.
//
// Equivale a evaluate() de tools/reference_engine.py. Cada regla produce un
// hallazgo con código, dimensión y severidad; el texto proviene de
// assets/data/findings.json y se completa con los valores del diseño.
//
// Decisión de diseño: el evaluador NO usa un modelo de lenguaje. Un
// diagnóstico eléctrico equivocado enseña física falsa y el estudiante no
// tiene cómo detectarlo. Las reglas son verificables, reproducibles y
// revisables por el docente (ver docs/ANALISIS_Y_DECISIONES.md).

import 'dart:math' as math;

import '../../core/format.dart';
import '../engine/lcg_random.dart';
import '../engine/wiring_analyzer.dart';
import '../model/catalog.dart';
import '../model/design.dart';
import '../model/evaluation.dart';
import '../model/finding.dart';
import '../model/mission.dart';
import '../model/sim_result.dart';

class DesignEvaluator {
  const DesignEvaluator(this.templates);

  final Map<String, FindingTemplate> templates;

  Evaluation evaluate(Mission mission, Catalog catalog, SystemDesign design, SimResult sim) {
    final r = ResolvedDesign.of(catalog, design);
    final st = sim.wiring;
    final m = sim.metrics;
    final c = r.controller;
    final s = r.sensor;
    final a = r.actuator;
    final k = r.comm;
    final p = r.power;
    final lg = design.logic;
    final req = mission.requirements;
    final site = mission.site;
    final band = mission.band;
    final halfBand = band.half;
    final unit = mission.unit;
    final dec = mission.decimals;
    final f = <Finding>[];

    String val(double v) => '${fmtNum(v, dec)} $unit';
    String valFine(double v) => '${fmtCompact(v, maxDecimals: math.max(dec, 2))} $unit';

    void add(String code, Dimension dim, Severity sev, [Map<String, String> params = const {}]) {
      final t = templates[code];
      final all = <String, String>{
        'sensor': s.name,
        'controller': c.name,
        'actuator': a.name,
        'comm': k.name,
        'power': p.name,
        'variable': mission.variableLabel.toLowerCase(),
        ...params,
      };
      f.add(Finding(
        code: code,
        dimension: dim,
        severity: sev,
        title: t == null ? code : FindingTemplate.fill(t.title, all),
        message: t == null ? '' : FindingTemplate.fill(t.message, all),
        fix: t == null ? '' : FindingTemplate.fill(t.fix, all),
        lessonId: t?.lessonId ?? '',
      ));
    }

    bool hasProblem(Dimension d) =>
        f.any((x) => x.dimension == d && (x.severity == Severity.critical || x.severity == Severity.warning));

    // ---------------- arquitectura ----------------
    if (!st.controllerAlive) {
      add('A01_controller_supply', Dimension.arquitectura, Severity.critical,
          {'options': c.supplyOptions.map(fmtVolts).join(' o ')});
    }
    if (st.commNeedsModule) {
      add('A02_external_radio', Dimension.arquitectura, Severity.suggestion,
          {'cost': k.moduleCostPen.round().toString()});
    }
    if (lg.firmware == FirmwareStyle.rtos && !c.rtosCapable) {
      add('A03_rtos_ram', Dimension.arquitectura, Severity.warning, {'ram': '${c.ramKb} KB'});
    }
    if (c.isLinux && req.requiresLatch) {
      add('A04_linux_realtime', Dimension.arquitectura, Severity.warning);
    }
    if (p.mains && !req.mainsAvailable) {
      add('A07_no_mains', Dimension.arquitectura, Severity.critical);
    }
    if (req.minAutonomyDays > 0 && p.batteryWh > 0) {
      final aut = m.autonomyDays ?? 0.0;
      if (aut < req.minAutonomyDays) {
        add('A05_autonomy', Dimension.arquitectura, Severity.critical, {
          'energy': fmtNum(m.energyWhDay, 1),
          'battery': fmtCompact(p.batteryWh, maxDecimals: 1),
          'value': fmtNum(aut, 1),
          'limit': fmtCompact(req.minAutonomyDays),
        });
      } else {
        add('P05_autonomy_ok', Dimension.arquitectura, Severity.positive,
            {'value': aut >= 999 ? 'indefinidos' : fmtNum(aut, 1)});
      }
    }
    if (st.costPen > req.budgetPen) {
      add('A06_budget', Dimension.arquitectura, Severity.critical,
          {'value': st.costPen.round().toString(), 'limit': req.budgetPen.round().toString()});
    }
    if (lg.lowPower && !c.supportsDeepSleep) {
      add('A09_no_deep_sleep', Dimension.arquitectura, Severity.warning);
    }
    if (c.isLinux && !req.needsLinux) {
      add('A08_oversized', Dimension.arquitectura, Severity.suggestion);
    }

    // ---------------- sensores ----------------
    if (!st.sensorMeasuresVar) {
      add('S01_wrong_variable', Dimension.sensores, Severity.critical,
          {'measures': s.measures.map(measureLabel).join(' y ')});
    } else {
      if (s.rangeMin > mission.sensorRangeMin || s.rangeMax < mission.sensorRangeMax) {
        add('S02_range', Dimension.sensores, Severity.critical, {
          'sensorRange': '${fmtCompact(s.rangeMin)} a ${fmtCompact(s.rangeMax)} $unit',
          'needed': '${fmtCompact(mission.sensorRangeMin)} a ${fmtCompact(mission.sensorRangeMax)} $unit',
        });
      }
      if (s.accuracy > halfBand) {
        add('S03_accuracy', Dimension.sensores, Severity.critical,
            {'value': valFine(s.accuracy), 'limit': valFine(halfBand)});
      } else if (s.accuracy > halfBand * 0.6) {
        add('S03_accuracy_marginal', Dimension.sensores, Severity.warning,
            {'value': valFine(s.accuracy), 'limit': valFine(halfBand)});
      }
      if (!st.sensorPowered) {
        add('S04_supply', Dimension.sensores, Severity.critical, {
          'supply': _same(s.supplyMin, s.supplyMax)
              ? fmtVolts(s.supplyMin)
              : '${fmtCompact(s.supplyMin, maxDecimals: 1)} a ${fmtVolts(s.supplyMax)}',
          'rails': fmtRails(p.rails),
        });
      }
      if (st.noAdc) {
        add('S05_no_adc', Dimension.sensores, Severity.critical);
      }
      if (st.overrange) {
        add('S06_overrange', Dimension.sensores, Severity.critical, {
          'value': fmtCompact(math.min(s.outputMaxV, st.sensorSupplyV ?? 0.0), maxDecimals: 1),
          'limit': fmtCompact(c.adcVref, maxDecimals: 1),
        });
      }
      if (st.levelMismatch == 'high_to_low') {
        add('S07_level_5v_to_3v3', Dimension.sensores, Severity.critical);
      } else if (st.levelMismatch == 'low_to_high') {
        add('S07_level_3v3_to_5v', Dimension.sensores, Severity.critical);
      }
      if (s.isAnalog && !st.noAdc && st.effRes + st.adcNoise > halfBand / 4) {
        add('S08_adc_resolution', Dimension.sensores, Severity.warning,
            {'value': valFine(st.effRes + st.adcNoise)});
      }
      if (lg.samplingS < s.minIntervalS - 1e-9) {
        add('S09_min_interval', Dimension.sensores, Severity.warning,
            {'value': fmtCompact(lg.samplingS), 'limit': fmtCompact(s.minIntervalS)});
      }
      if (const ['humid', 'industrial', 'outdoor'].contains(mission.environment) && !s.sealed) {
        add('S10_not_sealed', Dimension.sensores, Severity.warning, {'environment': mission.environmentLabel});
      }
      if (s.driftPerDay > 0 && mission.horizonS >= 86400) {
        add('S11_drift', Dimension.sensores, Severity.warning, {'value': valFine(s.driftPerDay)});
      }
      if (mission.signalFreqHz > 0 && st.attenuation < 1.0) {
        add('S12_bandwidth', Dimension.sensores, Severity.critical, {
          'value': fmtCompact(s.bandwidthHz),
          'limit': fmtCompact(mission.signalFreqHz),
          'pct': (st.attenuation * 100).round().toString(),
        });
      }
      if (!hasProblem(Dimension.sensores)) {
        add('P01_sensor_ok', Dimension.sensores, Severity.positive);
      }
    }

    // ---------------- actuadores ----------------
    if (st.effectSign == 0) {
      add('C01_no_effect', Dimension.actuadores, Severity.critical);
    } else if (st.effectSign != mission.direction) {
      add('C02_wrong_direction', Dimension.actuadores, Severity.critical,
          {'direction': mission.direction > 0 ? 'aumentar' : 'reducir'});
    }
    if (st.gpioOver) {
      add('C03_gpio_overcurrent', Dimension.actuadores, Severity.critical,
          {'value': (a.loadA * 1000).round().toString(), 'limit': c.gpioMaxMa.round().toString()});
    }
    if (!st.loadVOk) {
      add('C04_load_voltage', Dimension.actuadores, Severity.critical, {'value': fmtCompact(a.loadV, maxDecimals: 1)});
    }
    if (st.brownout) {
      add('C05_power_capacity', Dimension.actuadores, Severity.critical,
          {'value': fmtCompact(a.loadA, maxDecimals: 1), 'limit': fmtCompact(p.maxA, maxDecimals: 1)});
    }
    if (st.relayPwm) {
      add('C06_relay_pwm', Dimension.actuadores, Severity.critical, {'algorithm': lg.algorithm.label.toLowerCase()});
    }
    if (a.driver == 'mosfet_std') {
      add('C07_mosfet_gate', Dimension.actuadores, Severity.warning, {'value': (st.gateFactor * 100).round().toString()});
    }
    if (a.maxSwitchesPerHour > 0 && m.switchesPerHour > a.maxSwitchesPerHour) {
      add('C08_switch_rate', Dimension.actuadores, a.switchLimitCritical ? Severity.critical : Severity.warning, {
        'value': fmtNum(m.switchesPerHour, 0),
        'limit': fmtCompact(a.maxSwitchesPerHour),
      });
    }
    if (!st.driverSupplyOk) {
      add('C09_driver_supply', Dimension.actuadores, Severity.critical);
    }
    if (st.effectSign == mission.direction && m.saturationPct > 90 && m.timeInBandPct < req.minTimeInBandPct) {
      add('C10_undersized', Dimension.actuadores, Severity.warning, {'value': fmtNum(m.saturationPct, 0)});
    }
    if (!hasProblem(Dimension.actuadores)) {
      add('P02_actuator_ok', Dimension.actuadores, Severity.positive);
    }

    // ---------------- comunicación ----------------
    final tech = k.tech;
    if (req.remoteAlarm && tech == 'none') {
      add('K01_no_remote', Dimension.comunicacion, Severity.critical);
    }
    if (tech != 'none' && !st.infraOk) {
      add('K02_infra_missing', Dimension.comunicacion, Severity.critical,
          {'infra': infraLabel(k.infra), 'site': site.description});
    }
    if (tech != 'none' && st.infraOk && !st.rangeOk) {
      add('K03_out_of_range', Dimension.comunicacion, Severity.critical,
          {'value': fmtCompact(site.distanceM), 'limit': fmtCompact(k.rangeM)});
    }
    if (st.commOk && st.commMinInterval > 0 && lg.reportS < st.commMinInterval - 1e-9) {
      add('K04_duty_cycle', Dimension.comunicacion, Severity.critical,
          {'value': fmtCompact(lg.reportS), 'limit': fmtCompact(st.commMinInterval)});
    }
    if (st.commOk && (site.linkPenalty[tech] ?? 0) > 0) {
      add('K06_hostile_link', Dimension.comunicacion, Severity.warning, {'value': (st.loss * 100).round().toString()});
    }
    if (st.commOk && !hasProblem(Dimension.comunicacion)) {
      add('P06_link_ok', Dimension.comunicacion, Severity.positive);
    }

    // ---------------- IoT ----------------
    final deliveryParams = {'value': fmtNum(m.deliveredPct, 0), 'limit': fmtCompact(req.minDeliveryPct)};
    if (st.commOk) {
      if (m.deliveredPct < req.minDeliveryPct) {
        add('I01_delivery', Dimension.iot, Severity.critical, deliveryParams);
      }
      if (lg.reportS > req.reportEveryS + 1e-9) {
        add('I02_report_slow', Dimension.iot, Severity.warning,
            {'value': fmtCompact(lg.reportS), 'limit': fmtCompact(req.reportEveryS)});
      }
      final hasOutage = mission.events.any((e) => e.type == EventType.linkOutage);
      if (!lg.retry && (st.loss > 0.02 || hasOutage)) {
        add('I03_no_retry', Dimension.iot, Severity.warning, {'value': m.lost.toString()});
      }
      if (lg.retry && m.deliveredPct >= req.minDeliveryPct) {
        add('P03_retry_ok', Dimension.iot, Severity.positive, {'value': fmtNum(m.deliveredPct, 0)});
      }
      if (st.monthlyPen > 0) {
        add('I04_monthly_cost', Dimension.iot, Severity.suggestion, {'value': st.monthlyPen.round().toString()});
      }
      if (lg.reportS < req.reportEveryS / 4.0) {
        add('I06_report_too_often', Dimension.iot, Severity.suggestion,
            {'value': fmtCompact(lg.reportS), 'limit': fmtCompact(req.reportEveryS)});
      }
    } else if (tech != 'none' || req.remoteAlarm) {
      add('I01_delivery', Dimension.iot, Severity.critical, deliveryParams);
    }

    // ---------------- lógica ----------------
    if (!(band.low <= lg.setpoint && lg.setpoint <= band.high)) {
      add('L02_setpoint_outside', Dimension.logica, Severity.critical,
          {'value': val(lg.setpoint), 'low': val(band.low), 'high': val(band.high)});
    }
    if (m.timeInBandPct < req.minTimeInBandPct) {
      add('L01_time_in_band', Dimension.logica, Severity.critical,
          {'value': fmtNum(m.timeInBandPct, 1), 'limit': fmtCompact(req.minTimeInBandPct)});
    }
    if (lg.algorithm == ControlAlgorithm.onoff) {
      add('L03_no_hysteresis', Dimension.logica, Severity.suggestion);
    }
    if (lg.algorithm == ControlAlgorithm.hysteresis && lg.hysteresis > band.width + 1e-9) {
      add('L04_hysteresis_wide', Dimension.logica, Severity.warning,
          {'value': valFine(lg.hysteresis), 'limit': valFine(band.width)});
    }
    if (lg.samplingS > mission.logic.maxGoodSamplingS + 1e-9) {
      add('L05_sampling_slow', Dimension.logica, Severity.warning,
          {'value': fmtCompact(lg.samplingS), 'limit': fmtCompact(mission.logic.maxGoodSamplingS)});
    }
    if (req.requiresLatch && lg.algorithm != ControlAlgorithm.trip) {
      add('L06_no_latch', Dimension.logica, Severity.critical);
    }
    if (req.requiresLatch && lg.algorithm == ControlAlgorithm.trip) {
      add('P04_latch_ok', Dimension.logica, Severity.positive);
    }
    if (lg.firmware == FirmwareStyle.blocking && (s.convTimeS >= 0.2 || (st.commOk && st.commLatency >= 1.0))) {
      add('L07_blocking', Dimension.logica, Severity.warning, {'value': fmtCompact(m.stallS, maxDecimals: 0)});
    }
    final lat = m.alarmLatencyS;
    if (lat != null && lat > req.maxAlarmLatencyS) {
      add('L08_alarm_latency', Dimension.logica, Severity.critical,
          {
            'value': lat.isInfinite
                ? 'La alerta nunca llegó.'
                : 'La alerta llegó ${fmtDuration(lat)} después de que la variable cruzara el umbral.',
            'limit': fmtCompact(req.maxAlarmLatencyS),
          });
    }
    final act = m.actionLatencyS;
    if (act != null && act > req.maxActionLatencyS) {
      add('L10_action_latency', Dimension.logica, Severity.critical,
          {
            'value': act.isInfinite
                ? 'El motor nunca se detuvo.'
                : 'El motor se detuvo ${fmtDuration(act)} después de entrar en la zona peligrosa.',
            'limit': fmtCompact(req.maxActionLatencyS),
          });
    }
    if (m.falseAlarms > 0) {
      add('L09_false_alarms', Dimension.logica, Severity.warning, {'value': m.falseAlarms.toString()});
    }
    if (st.sleepPwmLoss) {
      add('L11_sleep_pwm', Dimension.logica, Severity.warning, {'algorithm': lg.algorithm.label.toLowerCase()});
    }

    // ---------------- puntajes ----------------
    final scores = <Dimension, int>{};
    for (final d in Dimension.values) {
      final pen = f.where((x) => x.dimension == d).fold<int>(0, (acc, x) => acc + x.severity.penalty);
      scores[d] = math.max(0, 100 - pen);
    }
    final total = scores.values.fold<int>(0, (acc, v) => acc + v);
    final overall = roundHalfEven(total / Dimension.values.length).toInt();
    final passed = !f.any((x) => x.severity == Severity.critical);

    f.sort((x, y) {
      final bySev = x.severity.index.compareTo(y.severity.index);
      if (bySev != 0) return bySev;
      return x.dimension.index.compareTo(y.dimension.index);
    });

    return Evaluation(
      findings: f,
      scores: scores,
      overall: overall,
      passed: passed,
      requirements: _requirements(mission, sim),
    );
  }

  List<RequirementCheck> _requirements(Mission mission, SimResult sim) {
    final m = sim.metrics;
    final req = mission.requirements;
    final out = <RequirementCheck>[
      RequirementCheck(
        label: 'Tiempo dentro de la banda',
        target: '≥ ${fmtCompact(req.minTimeInBandPct)} %',
        achieved: fmtPct(m.timeInBandPct, 1),
        met: m.timeInBandPct >= req.minTimeInBandPct,
      ),
    ];
    final lat = m.alarmLatencyS;
    out.add(RequirementCheck(
      label: 'Alerta remota: ${mission.alarm.label.toLowerCase()}',
      target: '≤ ${fmtDuration(req.maxAlarmLatencyS)}',
      achieved: lat == null ? 'No hizo falta' : fmtDuration(lat),
      met: lat == null || lat <= req.maxAlarmLatencyS,
    ));
    if (req.maxActionLatencyS > 0) {
      final act = m.actionLatencyS;
      out.add(RequirementCheck(
        label: 'Tiempo de parada',
        target: '≤ ${fmtDuration(req.maxActionLatencyS)}',
        achieved: act == null ? 'Actuó antes del umbral' : fmtDuration(act),
        met: act == null || act <= req.maxActionLatencyS,
      ));
    }
    out.add(RequirementCheck(
      label: 'Reportes entregados',
      target: '≥ ${fmtCompact(req.minDeliveryPct)} %',
      achieved: '${m.delivered} de ${m.expected} (${fmtPct(m.deliveredPct)})',
      met: sim.wiring.commOk && m.deliveredPct >= req.minDeliveryPct,
    ));
    if (req.minAutonomyDays > 0) {
      final aut = m.autonomyDays;
      out.add(RequirementCheck(
        label: 'Autonomía sin sol',
        target: '≥ ${fmtCompact(req.minAutonomyDays)} días',
        achieved: aut == null ? 'Sin batería' : '${fmtNum(aut, 1)} días',
        met: aut != null && aut >= req.minAutonomyDays,
      ));
    }
    out.add(RequirementCheck(
      label: 'Presupuesto',
      target: '≤ ${fmtPen(req.budgetPen)}',
      achieved: fmtPen(m.costPen),
      met: m.costPen <= req.budgetPen,
    ));
    return out;
  }
}

bool _same(double a, double b) => (a - b).abs() < 1e-6;
