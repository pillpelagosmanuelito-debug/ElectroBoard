// Simulador en el tiempo del sistema completo.
//
// Equivale a simulate() de tools/reference_engine.py. Integra la planta física
// con Euler explícito, modela el sensor (retardo, sesgo, ruido, cuantización,
// saturación), ejecuta la lógica de control en los instantes de muestreo,
// transmite reportes y alertas por el enlace y calcula el consumo diario.

import 'dart:math' as math;

import '../model/catalog.dart';
import '../model/design.dart';
import '../model/mission.dart';
import '../model/sim_result.dart';
import 'lcg_random.dart';
import 'wiring_analyzer.dart';

class _Episode {
  _Episode(this.start);

  final double start;
  double? end;
  double? deliveredAt;
  bool trueCross = false;
  double minGap = double.infinity;
}

class _Pending {
  const _Pending(this.at, this.isAlarm, this.episode);

  final double at;
  final bool isAlarm;
  final int episode;
}

class _EventState {
  const _EventState(this.ambient, this.disturbance, this.actuatorOut, this.linkOut);

  final double ambient;
  final double disturbance;
  final bool actuatorOut;
  final bool linkOut;
}

class SystemSimulator {
  const SystemSimulator({this.wiring = const WiringAnalyzer()});

  final WiringAnalyzer wiring;

  static const int targetPoints = 600;

  SimResult run(Mission mission, Catalog catalog, SystemDesign design) {
    final r = ResolvedDesign.of(catalog, design);
    final st = wiring.analyze(mission, r);
    return _simulate(mission, r, st);
  }

  _EventState _eventsAt(Mission mission, double t) {
    var amb = 0.0;
    var dist = 0.0;
    var actOut = false;
    var linkOut = false;
    for (final e in mission.events) {
      if (e.activeAt(t)) {
        final w = e.rampS <= 0 ? 1.0 : math.min(1.0, (t - e.atS) / e.rampS);
        switch (e.type) {
          case EventType.disturbance:
            dist += e.value * w;
          case EventType.ambientStep:
            amb += e.value * w;
          case EventType.actuatorOutage:
            actOut = true;
          case EventType.linkOutage:
            linkOut = true;
        }
      }
    }
    return _EventState(amb, dist, actOut, linkOut);
  }

  double _linkOutageEnd(Mission mission, double t) {
    var end = t;
    for (final e in mission.events) {
      if (e.type == EventType.linkOutage && e.activeAt(t)) {
        end = math.max(end, e.endS);
      }
    }
    return end;
  }

  SimResult _simulate(Mission mission, ResolvedDesign r, WiringSetup st) {
    final s = r.sensor;
    final c = r.controller;
    final a = r.actuator;
    final k = r.comm;
    final p = r.power;
    final lg = r.logic;
    final pl = mission.plant;
    final varDir = mission.direction.toDouble();
    final dt = mission.dtS;
    final horizon = mission.horizonS;
    final n = (horizon / dt).round();
    final rng = LcgRandom(mission.seed);
    final bandLo = mission.band.low;
    final bandHi = mission.band.high;
    final halfBand = (bandHi - bandLo) / 2.0;
    final thr = mission.alarm.threshold;
    final alarmUp = mission.alarm.up;
    final algo = lg.algorithm;
    final sp = lg.setpoint;
    final hyst = lg.hysteresis;
    final kp = lg.kp;
    final ki = lg.ki;
    final kd = lg.kd;
    final samp = lg.samplingS;
    final report = lg.reportS;
    final blocking = lg.firmware == FirmwareStyle.blocking;
    final retry = lg.retry;
    final settle = mission.settleS;
    final wantsAction = mission.requirements.maxActionLatencyS > 0;

    var x = pl.x0;
    var y = x;
    var uCmd = 0.0;
    var hystOn = false;
    var latched = false;
    var integ = 0.0;
    double? prevE;
    double? lastValid;
    var lastReadT = double.negativeInfinity;
    var nextSample = 0.0;
    var nextReport = report;
    var lastSent = double.negativeInfinity;
    var pinDamaged = false;
    var resets = 0;
    var prevOn = false;
    var switches = 0;
    var alarmActive = false;
    double? trueCrossT;
    final episodes = <_Episode>[];
    double? actionT;
    var alarmsSent = 0;
    var pending = <_Pending>[];
    var delivered = 0;
    var lost = 0;
    var suppressed = 0;
    var inBand = 0;
    var counted = 0;
    var maxDev = 0.0;
    var sat = 0;
    var errSq = 0.0;
    var errN = 0;
    var actOnTime = 0.0;
    var stallTotal = 0.0;
    final recordEvery = math.max(1, n ~/ targetPoints);
    final seriesT = <double>[];
    final seriesX = <double>[];
    final seriesM = <double?>[];
    final seriesU = <double>[];
    final eventsLog = <SimEvent>[];
    double? mDisp;
    final tauS = math.max(s.timeConstantS, 1e-6);

    for (var i = 0; i < n; i++) {
      final t = i * dt;
      final ev = _eventsAt(mission, t);
      final amb = pl.ambient + pl.ambientAmp * math.sin(2 * math.pi * t / pl.periodS) + ev.ambient;
      final drift = pl.drift * (1 + pl.driftAmp * math.sin(2 * math.pi * t / pl.periodS)) + ev.disturbance;

      // ---------------- instante de muestreo ----------------
      if (t >= nextSample - 1e-9) {
        final rNoise = rng.next();
        final rInv = rng.next();
        double? m;
        if (st.controllerAlive && !st.sensorDead) {
          if (rInv < st.intermittent) {
            m = null;
          } else if (lastValid != null && (t - lastReadT) < s.minIntervalS - 1e-9) {
            m = lastValid;
          } else {
            var v = y * st.attenuation + st.bias + (2 * rNoise - 1) * st.noiseAmp;
            v += st.sensorDriftPerDay * t / 86400.0;
            if (st.effRes > 0) {
              v = roundHalfEven(v / st.effRes) * st.effRes;
            }
            v = math.max(s.rangeMin, math.min(s.rangeMax, v));
            final cap = st.satCap;
            if (cap != null) {
              v = math.min(v, cap);
            }
            m = v;
            lastValid = v;
            lastReadT = t;
          }
        }
        if (m != null) {
          mDisp = m;
          errSq += (m - x) * (m - x);
          errN += 1;
          final e = varDir * (sp - m);
          switch (algo) {
            case ControlAlgorithm.onoff:
              uCmd = e > 0 ? 1.0 : 0.0;
            case ControlAlgorithm.hysteresis:
              if (e > hyst / 2) {
                hystOn = true;
              } else if (e < -hyst / 2) {
                hystOn = false;
              }
              uCmd = hystOn ? 1.0 : 0.0;
            case ControlAlgorithm.proportional:
              uCmd = math.max(0.0, math.min(1.0, kp * e));
            case ControlAlgorithm.pid:
              integ += e * samp;
              if (ki > 0) {
                integ = math.max(-1.0 / ki, math.min(1.0 / ki, integ));
              }
              final de = prevE == null ? 0.0 : (e - prevE) / samp;
              prevE = e;
              uCmd = math.max(0.0, math.min(1.0, kp * e + ki * integ + kd * de));
            case ControlAlgorithm.trip:
              if (e > 0) latched = true;
              uCmd = latched ? 1.0 : 0.0;
          }
          // alarma por evento
          final cond = alarmUp ? m > thr : m < thr;
          final clear = alarmUp ? m < thr - 0.2 * halfBand : m > thr + 0.2 * halfBand;
          final armed = t >= settle;
          if (cond && !alarmActive && armed) {
            alarmActive = true;
            alarmsSent += 1;
            episodes.add(_Episode(t));
            final ep = episodes.length - 1;
            if (st.commOk) {
              final rLoss = rng.next();
              if (ev.linkOut) {
                if (retry) {
                  pending.add(_Pending(_linkOutageEnd(mission, t) + st.commLatency, true, ep));
                }
              } else if (rLoss < st.loss) {
                if (retry) {
                  pending.add(_Pending(t + st.commLatency + 30.0, true, ep));
                }
              } else {
                pending.add(_Pending(t + st.commLatency, true, ep));
              }
            }
            eventsLog.add(SimEvent(t, SimEventKind.alarm));
          } else if (clear && alarmActive) {
            alarmActive = false;
            episodes.last.end = t;
          }
        } else {
          // sin lectura válida: el firmware apaga el actuador (falla segura)
          if (algo != ControlAlgorithm.trip) {
            uCmd = 0.0;
          }
        }
        var stall = blocking ? s.convTimeS : 0.0;
        if (blocking && st.commOk && t >= nextReport - 1e-9) {
          stall += st.commLatency;
        }
        stallTotal += stall;
        nextSample = t + samp + stall;
      }

      // ---------------- reportes periódicos ----------------
      if (t >= nextReport - 1e-9) {
        nextReport += report;
        if (st.commOk) {
          if (st.commMinInterval > 0 && (t - lastSent) < st.commMinInterval - 1e-9) {
            suppressed += 1;
          } else {
            lastSent = t;
            final rLoss = rng.next();
            if (ev.linkOut) {
              if (retry) {
                pending.add(_Pending(_linkOutageEnd(mission, t) + st.commLatency, false, -1));
              } else {
                lost += 1;
              }
            } else if (rLoss < st.loss) {
              if (retry) {
                pending.add(_Pending(t + st.commLatency + 30.0, false, -1));
              } else {
                lost += 1;
              }
            } else {
              pending.add(_Pending(t + st.commLatency, false, -1));
            }
          }
        }
      }

      // entrega de mensajes pendientes
      if (pending.isNotEmpty) {
        final keep = <_Pending>[];
        for (final msg in pending) {
          if (msg.at <= t + 1e-9) {
            if (!msg.isAlarm) {
              delivered += 1;
            } else if (episodes[msg.episode].deliveredAt == null) {
              episodes[msg.episode].deliveredAt = t;
            }
          } else {
            keep.add(msg);
          }
        }
        pending = keep;
      }

      // ---------------- actuador efectivo ----------------
      var u = uCmd;
      if (st.relayLike) {
        u = u >= 0.5 ? 1.0 : 0.0;
      }
      var factor = st.actBase;
      if (ev.actuatorOut) factor = 0.0;
      if (st.gpioOver) {
        if (u > 0 && !pinDamaged) {
          pinDamaged = true;
          eventsLog.add(SimEvent(t, SimEventKind.pinDamage));
        }
        if (pinDamaged) factor = 0.0;
      }
      final on = st.relayLike ? u > 0.5 : u > 0.05;
      if (on && !prevOn) {
        if (st.relayLike) switches += 1;
        if (st.brownout) resets += 1;
      }
      prevOn = on;
      final uEff = u * factor;

      // ---------------- planta ----------------
      final relax = pl.tauS > 0 ? (amb - x) / pl.tauS : 0.0;
      final dx = relax + drift + pl.gain * st.effect * uEff;
      x += dx * dt;
      x = math.max(pl.minX, math.min(pl.maxX, x));
      y += (x - y) * (1 - math.exp(-dt / tauS));

      final beyond = (alarmUp ? x > thr : x < thr) && t >= settle;
      if (beyond && trueCrossT == null) {
        trueCrossT = t;
      }
      if (beyond && alarmActive) {
        episodes.last.trueCross = true;
      }
      if (alarmActive && episodes.isNotEmpty) {
        final gap = alarmUp ? thr - x : x - thr;
        episodes.last.minGap = math.min(episodes.last.minGap, gap);
      }
      if (trueCrossT != null && actionT == null && uEff > 0.5 && wantsAction) {
        actionT = t;
      }

      if (t >= settle) {
        counted += 1;
        if (x >= bandLo && x <= bandHi) inBand += 1;
        final dev = math.max(math.max(bandLo - x, x - bandHi), 0.0);
        maxDev = math.max(maxDev, dev);
        if (uCmd >= 0.99) sat += 1;
        actOnTime += uEff * dt;
      }

      if (i % recordEvery == 0) {
        seriesT.add(t);
        seriesX.add(x);
        seriesM.add(mDisp);
        seriesU.add(uEff);
      }
    }

    // ---------------- métricas ----------------
    final hours = horizon / 3600.0;
    final req = mission.requirements;
    final expected = math.max(1, (horizon / req.reportEveryS - 1e-9).ceil() - 1);
    final deliveredPct = 100.0 * math.min(1.0, delivered / expected);
    final falseMargin = 0.1 * (bandHi - bandLo);
    final falseAlarms = episodes.where((e) => !e.trueCross && e.minGap > falseMargin).length;

    double? alarmLatency;
    if (trueCrossT != null) {
      alarmLatency = double.infinity;
      for (final e in episodes) {
        final end = e.end;
        final at = e.deliveredAt;
        if ((end == null || end >= trueCrossT) && at != null) {
          alarmLatency = math.max(at, trueCrossT) - trueCrossT;
          break;
        }
      }
    }
    double? actionLatency;
    if (wantsAction && trueCrossT != null) {
      actionLatency = actionT == null ? double.infinity : actionT - trueCrossT;
    }

    // energía (Wh/día)
    final lp = lg.lowPower && c.supportsDeepSleep;
    final activeS = 0.05 + s.convTimeS;
    double ctrlMa;
    double sensorMa;
    double commIdleMa;
    if (lp) {
      final f = math.min(1.0, activeS / samp);
      ctrlMa = f * c.activeMa + (1 - f) * c.sleepMa;
      sensorMa = s.currentMa * math.max(f, 0.02);
      commIdleMa = 0.0;
    } else {
      ctrlMa = c.activeMa;
      sensorMa = s.currentMa;
      commIdleMa = k.tech != 'none' ? k.idleMa : 0.0;
    }
    final baseW = (ctrlMa + sensorMa + commIdleMa) / 1000.0 * st.controllerV / 0.85;
    var msgsDay = k.tech != 'none' ? 86400.0 / report : 0.0;
    if (st.commMinInterval > 0) {
      msgsDay = math.min(msgsDay, 86400.0 / st.commMinInterval);
    }
    final txWhDay = msgsDay * (k.txJ + (lp ? k.wakeJ : 0.0)) / 3600.0;
    final loadW = a.loadV > 0 ? a.loadV * a.loadA : 0.0;
    final countedS = math.max(1.0, horizon - settle);
    final actWhDay = loadW * (actOnTime / countedS) * 24.0;
    final energyWhDay = baseW * 24.0 + txWhDay + actWhDay;
    double? autonomy;
    if (p.batteryWh > 0) {
      autonomy = energyWhDay > 0 ? p.batteryWh / energyWhDay : 999.0;
    }

    final metrics = SimMetrics(
      timeInBandPct: 100.0 * inBand / math.max(1, counted),
      maxDeviation: maxDev,
      switchesPerHour: switches / hours,
      alarmLatencyS: alarmLatency,
      actionLatencyS: actionLatency,
      falseAlarms: falseAlarms,
      alarmsSent: alarmsSent,
      deliveredPct: deliveredPct,
      delivered: delivered,
      expected: expected,
      lost: lost,
      suppressed: suppressed,
      energyWhDay: energyWhDay,
      autonomyDays: autonomy,
      costPen: st.costPen,
      monthlyPen: st.monthlyPen,
      rmsError: errN > 0 ? math.sqrt(errSq / errN) : null,
      saturationPct: 100.0 * sat / math.max(1, counted),
      resets: resets,
      pinDamaged: pinDamaged,
      stallS: stallTotal,
      validReadings: errN,
    );

    return SimResult(
      wiring: st,
      metrics: metrics,
      series: SimSeries(t: seriesT, x: seriesX, m: seriesM, u: seriesU),
      events: eventsLog,
    );
  }
}
