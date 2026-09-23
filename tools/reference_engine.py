#!/usr/bin/env python3
"""Motor de referencia de ElectroBoard.

Implementación independiente en Python del simulador y del evaluador que la
aplicación ejecuta en Dart (lib/domain/engine y lib/domain/evaluator). Lee los
mismos archivos JSON de assets/data. Sirve para:

  * calibrar las misiones (el diseño de referencia aprueba, los errores típicos fallan);
  * producir los valores esperados que protegen las pruebas de Dart.

Uso:  python3 tools/reference_engine.py            (informe de todas las misiones)
      python3 tools/reference_engine.py --json     (valores en JSON)
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "assets", "data")

INF = float("inf")
PENALTY = {"critical": 45, "warning": 15, "suggestion": 5, "positive": 0}
DIMENSIONS = ["arquitectura", "sensores", "actuadores", "comunicacion", "iot", "logica"]


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)


class Rng:
    """LCG idéntico al de Dart (lib/domain/engine/lcg_random.dart)."""

    def __init__(self, seed):
        self.state = seed & 0x7FFFFFFF

    def next(self):
        self.state = (self.state * 1103515245 + 12345) & 0x7FFFFFFF
        return self.state / 2147483647.0


def by_id(items):
    return {i["id"]: i for i in items}


# --------------------------------------------------------------------------
# Preparación: qué rieles hay, cómo queda conectado cada bloque
# --------------------------------------------------------------------------

def prepare(mission, design, cat):
    c = by_id(cat["controllers"])[design["controllerId"]]
    s = by_id(cat["sensors"])[design["sensorId"]]
    a = by_id(cat["actuators"])[design["actuatorId"]]
    k = by_id(cat["comms"])[design["commId"]]
    p = by_id(cat["power"])[design["powerId"]]
    lg = design["logic"]
    var = mission["variable"]
    rails = list(p["rails"])
    cond = bool(design.get("conditioning", False))

    st = {}
    st["controllerAlive"] = any(v in rails for v in c["supplyOptions"])
    st["controllerV"] = 5.0 if (5.0 in rails and 5.0 in c["supplyOptions"]) else 3.3

    # --- sensor: riel de alimentación elegido ---
    supply = None
    cands = [c["logicV"]] + sorted(rails, reverse=True)
    for v in cands:
        if v in rails and s["supplyMin"] - 1e-9 <= v <= s["supplyMax"] + 1e-9:
            supply = v
            break
    st["sensorSupplyV"] = supply
    st["sensorPowered"] = supply is not None
    st["sensorMeasuresVar"] = var in s["measures"]
    sensor_logic = s["logicV"] if s["logicV"] > 0 else (supply or 0)
    st["sensorLogicV"] = sensor_logic
    st["sensorDead"] = (not st["sensorPowered"]) or (not st["sensorMeasuresVar"]) or (not st["controllerAlive"])
    st["intermittent"] = 0.0
    st["noAdc"] = False
    st["overrange"] = False
    st["satCap"] = None
    eff_res = s["resolution"]
    adc_noise = 0.0
    if s["interface"] == "analog":
        if c["adcBits"] == 0:
            st["noAdc"] = True
            st["sensorDead"] = True
        else:
            out_max = min(s["outputMaxV"], supply or 0)
            lsb_v = c["adcVref"] / (2 ** c["adcBits"])
            lsb_units = lsb_v / s["sensitivity"]
            if out_max > c["adcVref"] + 1e-9:
                if cond:
                    lsb_units *= out_max / c["adcVref"]
                else:
                    st["overrange"] = True
                    st["satCap"] = s["rangeMin"] + (c["adcVref"] - s["offsetV"]) / s["sensitivity"]
            eff_res = max(s["resolution"], lsb_units)
            adc_noise = c["adcErrorLsb"] * lsb_units
    else:
        if (not st["sensorDead"]) and sensor_logic > 3.4 and c["logicV"] < 3.4 and not c["fiveVTolerant"] and not cond:
            st["intermittent"] = 0.4
            st["levelMismatch"] = "high_to_low"
        elif (not st["sensorDead"]) and sensor_logic < 3.4 and c["logicV"] > 3.4 and not s["fiveVTolerant"] and not cond:
            st["intermittent"] = 0.2
            st["levelMismatch"] = "low_to_high"
    st["effRes"] = eff_res
    st["noiseAmp"] = s["accuracy"] * 0.5 + adc_noise
    st["bias"] = s["accuracy"] * 0.4
    st["adcNoise"] = adc_noise
    att = 1.0
    if mission.get("signalFreqHz", 0) > 0:
        bw = s.get("bandwidthHz", 0)
        att = 1.0 if bw >= mission["signalFreqHz"] else (bw / mission["signalFreqHz"] if bw > 0 else 0.0)
    st["attenuation"] = att
    drift = s["driftPerDay"] * (0.5 if lg.get("lowPower") else 1.0)
    st["sensorDriftPerDay"] = drift

    # --- actuador ---
    eff = a["effects"].get(var, 0.0)
    st["effectSign"] = 0 if eff == 0 else (1 if eff > 0 else -1)
    st["effect"] = eff
    st["loadVOk"] = a["loadV"] == 0 or a["loadV"] in rails
    st["driverSupplyOk"] = a["driverSupplyV"] == 0 or a["driverSupplyV"] in rails
    gate = 1.0
    if a["driver"] == "mosfet_std":
        gate = 0.25 if c["logicV"] < 3.4 else 0.6
    st["gateFactor"] = gate
    st["gpioOver"] = a["driver"] == "gpio" and a["loadA"] * 1000 > c["gpioMaxMa"]
    st["brownout"] = a["loadV"] > 0 and st["loadVOk"] and a["loadA"] > p["maxA"] + 1e-9
    st["relayLike"] = a["driver"] in ("relay",)
    st["relayPwm"] = st["relayLike"] and lg["algorithm"] in ("proportional", "pid")
    continuous = lg["algorithm"] in ("proportional", "pid")
    st["sleepPwmLoss"] = bool(lg.get("lowPower")) and c["supportsDeepSleep"] and continuous and not st["relayLike"]
    base = 1.0
    if not st["loadVOk"] or not st["driverSupplyOk"] or st["brownout"] or not st["controllerAlive"]:
        base = 0.0
    st["actBase"] = base * gate * (0.1 if st["sleepPwmLoss"] else 1.0)

    # --- comunicación ---
    site = mission["site"]
    tech = k["tech"]
    st["commTech"] = tech
    st["commNeedsModule"] = tech not in ("none", "usb") and (k["builtInKey"] == "" or k["builtInKey"] not in c["builtInComms"])
    infra_ok = tech == "none" or k["infra"] in site["infra"]
    range_ok = tech == "none" or site["distanceM"] <= k["rangeM"]
    st["infraOk"] = infra_ok
    st["rangeOk"] = range_ok
    st["commOk"] = tech != "none" and infra_ok and range_ok and st["controllerAlive"]
    loss = k["lossBase"] + site.get("linkPenalty", {}).get(tech, 0.0)
    if range_ok and k["rangeM"] > 0:
        loss += 0.3 * (site["distanceM"] / k["rangeM"]) ** 2
    st["loss"] = min(loss, 0.95)
    st["commLatency"] = k["latencyS"]
    st["commMinInterval"] = k["minIntervalS"]

    # --- costos ---
    cost = c["costPen"] + s["costPen"] + a["costPen"] + p["costPen"]
    if st["commNeedsModule"]:
        cost += k["moduleCostPen"]
    if cond:
        cost += 4
    st["costPen"] = cost
    st["monthlyPen"] = k["monthlyPen"]
    return c, s, a, k, p, st


# --------------------------------------------------------------------------
# Simulación en el tiempo
# --------------------------------------------------------------------------

def events_at(mission, t):
    amb = 0.0
    dist = 0.0
    act_out = False
    link_out = False
    for e in mission["events"]:
        if e["atS"] <= t < e["atS"] + e["durS"]:
            ramp = e.get("rampS", 0)
            w = 1.0 if ramp <= 0 else min(1.0, (t - e["atS"]) / ramp)
            if e["type"] == "disturbance":
                dist += e["value"] * w
            elif e["type"] == "ambient_step":
                amb += e["value"] * w
            elif e["type"] == "actuator_outage":
                act_out = True
            elif e["type"] == "link_outage":
                link_out = True
    return amb, dist, act_out, link_out


def link_outage_end(mission, t):
    end = t
    for e in mission["events"]:
        if e["type"] == "link_outage" and e["atS"] <= t < e["atS"] + e["durS"]:
            end = max(end, e["atS"] + e["durS"])
    return end


def simulate(mission, design, cat):
    c, s, a, k, p, st = prepare(mission, design, cat)
    lg = design["logic"]
    pl = mission["plant"]
    var_dir = mission["direction"]
    dt = mission["dtS"]
    horizon = mission["horizonS"]
    n = int(round(horizon / dt))
    rng = Rng(mission["seed"])
    band_lo, band_hi = mission["band"]["low"], mission["band"]["high"]
    half_band = (band_hi - band_lo) / 2.0
    alarm = mission["alarm"]
    thr = alarm["threshold"]
    alarm_up = alarm["dir"] == "up"
    algo = lg["algorithm"]
    sp = lg["setpoint"]
    hyst = lg.get("hysteresis", 0.0)
    kp, ki, kd = lg.get("kp", 0.0), lg.get("ki", 0.0), lg.get("kd", 0.0)
    samp = lg["samplingS"]
    report = lg["reportS"]
    blocking = lg["firmware"] == "blocking"
    retry = bool(lg.get("retry"))

    x = pl["x0"]
    y = x
    u_cmd = 0.0
    hyst_on = False
    latched = False
    integ = 0.0
    prev_e = None
    last_valid = None
    last_read_t = -INF
    next_sample = 0.0
    next_report = report
    last_sent = -INF
    pin_damaged = False
    resets = 0
    prev_on = False
    switches = 0
    alarm_active = False
    true_cross_t = None
    episodes = []  # [inicio, fin, entregada_en, cruce_real_durante]
    action_t = None
    false_alarms = 0
    alarms_sent = 0
    pending = []  # (deliver_at, kind)
    delivered = 0
    lost = 0
    suppressed = 0
    sent = 0
    in_band = 0
    counted = 0
    max_dev = 0.0
    sat = 0
    err_sq = 0.0
    err_n = 0
    act_on_time = 0.0
    u_sum = 0.0
    stall_total = 0.0
    record_every = max(1, n // 600)
    series = {"t": [], "x": [], "m": [], "u": []}
    events_log = []
    m_disp = None

    for i in range(n):
        t = i * dt
        amb_add, dist, act_out, link_out = events_at(mission, t)
        amb = pl["ambient"] + pl["ambientAmp"] * math.sin(2 * math.pi * t / pl["periodS"]) + amb_add
        drift = pl["drift"] * (1 + pl["driftAmp"] * math.sin(2 * math.pi * t / pl["periodS"])) + dist

        # ---------------- instante de muestreo ----------------
        if t >= next_sample - 1e-9:
            r_noise = rng.next()
            r_inv = rng.next()
            m = None
            if st["controllerAlive"] and not st["sensorDead"]:
                if r_inv < st["intermittent"]:
                    m = None
                elif last_valid is not None and (t - last_read_t) < s["minIntervalS"] - 1e-9:
                    m = last_valid
                else:
                    v = y * st["attenuation"] + st["bias"] + (2 * r_noise - 1) * st["noiseAmp"]
                    v += st["sensorDriftPerDay"] * t / 86400.0
                    if st["effRes"] > 0:
                        v = round(v / st["effRes"]) * st["effRes"]
                    v = max(s["rangeMin"], min(s["rangeMax"], v))
                    if st["satCap"] is not None:
                        v = min(v, st["satCap"])
                    m = v
                    last_valid = v
                    last_read_t = t
            if m is not None:
                m_disp = m
                err_sq += (m - x) ** 2
                err_n += 1
                e = var_dir * (sp - m)
                if algo == "onoff":
                    u_cmd = 1.0 if e > 0 else 0.0
                elif algo == "hysteresis":
                    if e > hyst / 2:
                        hyst_on = True
                    elif e < -hyst / 2:
                        hyst_on = False
                    u_cmd = 1.0 if hyst_on else 0.0
                elif algo == "proportional":
                    u_cmd = max(0.0, min(1.0, kp * e))
                elif algo == "pid":
                    integ += e * samp
                    if ki > 0:
                        integ = max(-1.0 / ki, min(1.0 / ki, integ))
                    de = 0.0 if prev_e is None else (e - prev_e) / samp
                    prev_e = e
                    u_cmd = max(0.0, min(1.0, kp * e + ki * integ + kd * de))
                elif algo == "trip":
                    if e > 0:
                        latched = True
                    u_cmd = 1.0 if latched else 0.0
                # alarma
                cond = (m > thr) if alarm_up else (m < thr)
                clear = (m < thr - 0.2 * half_band) if alarm_up else (m > thr + 0.2 * half_band)
                armed = t >= mission["settleS"]
                if cond and not alarm_active and armed:
                    alarm_active = True
                    alarms_sent += 1
                    episodes.append([t, None, None, False, INF])
                    ep = len(episodes) - 1
                    if st["commOk"]:
                        r_loss = rng.next()
                        if link_out:
                            if retry:
                                pending.append((link_outage_end(mission, t) + st["commLatency"], "alarm", ep))
                        elif r_loss < st["loss"]:
                            if retry:
                                pending.append((t + st["commLatency"] + 30.0, "alarm", ep))
                        else:
                            pending.append((t + st["commLatency"], "alarm", ep))
                    events_log.append({"t": t, "kind": "alarm"})
                elif clear and alarm_active:
                    alarm_active = False
                    episodes[-1][1] = t
            else:
                # sin lectura válida: el firmware apaga el actuador (falla segura)
                if algo != "trip":
                    u_cmd = 0.0
            stall = s["convTimeS"] if blocking else 0.0
            if blocking and st["commOk"] and t >= next_report - 1e-9:
                stall += st["commLatency"]
            stall_total += stall
            next_sample = t + samp + stall

        # ---------------- reportes periódicos ----------------
        if t >= next_report - 1e-9:
            next_report += report
            if st["commOk"]:
                if st["commMinInterval"] > 0 and (t - last_sent) < st["commMinInterval"] - 1e-9:
                    suppressed += 1
                else:
                    sent += 1
                    last_sent = t
                    r_loss = rng.next()
                    if link_out:
                        if retry:
                            pending.append((link_outage_end(mission, t) + st["commLatency"], "report", -1))
                        else:
                            lost += 1
                    elif r_loss < st["loss"]:
                        if retry:
                            pending.append((t + st["commLatency"] + 30.0, "report", -1))
                        else:
                            lost += 1
                    else:
                        pending.append((t + st["commLatency"], "report", -1))

        # entrega de mensajes pendientes
        if pending:
            keep = []
            for (at, kind, ep) in pending:
                if at <= t + 1e-9:
                    if kind == "report":
                        delivered += 1
                    elif episodes[ep][2] is None:
                        episodes[ep][2] = t
                else:
                    keep.append((at, kind, ep))
            pending = keep

        # ---------------- actuador efectivo ----------------
        u = u_cmd
        if st["relayLike"]:
            u = 1.0 if u >= 0.5 else 0.0
        factor = st["actBase"]
        if act_out:
            factor = 0.0
        if st["gpioOver"]:
            if u > 0 and not pin_damaged:
                pin_damaged = True
                events_log.append({"t": t, "kind": "pin_damage"})
            if pin_damaged:
                factor = 0.0
        on = u > 0.5 if st["relayLike"] else u > 0.05
        if on and not prev_on:
            if st["relayLike"]:
                switches += 1
            if st["brownout"]:
                resets += 1
        prev_on = on
        u_eff = u * factor
        u_sum += u_eff

        # ---------------- planta ----------------
        relax = (amb - x) / pl["tauS"] if pl["tauS"] > 0 else 0.0
        dx = relax + drift + pl["gain"] * st["effect"] * u_eff
        x += dx * dt
        x = max(pl["minX"], min(pl["maxX"], x))
        tau_s = max(s["timeConstantS"], 1e-6)
        y += (x - y) * (1 - math.exp(-dt / tau_s))

        beyond = ((x > thr) if alarm_up else (x < thr)) and t >= mission["settleS"]
        if beyond and true_cross_t is None:
            true_cross_t = t
        if beyond and alarm_active:
            episodes[-1][3] = True
        if alarm_active and episodes:
            gap = (thr - x) if alarm_up else (x - thr)
            episodes[-1][4] = min(episodes[-1][4], gap)
        if true_cross_t is not None and action_t is None and u_eff > 0.5 and mission["requirements"].get("maxActionLatencyS", 0) > 0:
            action_t = t

        if t >= mission["settleS"]:
            counted += 1
            if band_lo <= x <= band_hi:
                in_band += 1
            dev = max(band_lo - x, x - band_hi, 0.0)
            max_dev = max(max_dev, dev)
            if u_cmd >= 0.99:
                sat += 1
            act_on_time += u_eff * dt

        if i % record_every == 0:
            series["t"].append(t)
            series["x"].append(x)
            series["m"].append(m_disp)
            series["u"].append(u_eff)

    # ---------------- métricas ----------------
    hours = horizon / 3600.0
    req = mission["requirements"]
    expected = max(1, math.ceil(horizon / req["reportEveryS"] - 1e-9) - 1)
    delivered_pct = 100.0 * min(1.0, delivered / expected) if expected > 0 else 0.0
    false_margin = 0.1 * (band_hi - band_lo)
    false_alarms = sum(1 for ep in episodes if not ep[3] and ep[4] > false_margin)
    if true_cross_t is None:
        alarm_latency = None
    else:
        alarm_latency = INF
        for ep in episodes:
            if (ep[1] is None or ep[1] >= true_cross_t) and ep[2] is not None:
                alarm_latency = max(ep[2], true_cross_t) - true_cross_t
                break
    if req.get("maxActionLatencyS", 0) > 0:
        if true_cross_t is None:
            action_latency = None
        elif action_t is None:
            action_latency = INF
        else:
            action_latency = action_t - true_cross_t
    else:
        action_latency = None

    # energía (Wh/día)
    lp = bool(lg.get("lowPower")) and c["supportsDeepSleep"]
    active_s = 0.05 + s["convTimeS"]
    if lp:
        f = min(1.0, active_s / samp)
        ctrl_ma = f * c["activeMa"] + (1 - f) * c["sleepMa"]
        sensor_ma = s["currentMa"] * max(f, 0.02)
        comm_idle_ma = 0.0
    else:
        ctrl_ma = c["activeMa"]
        sensor_ma = s["currentMa"]
        comm_idle_ma = k["idleMa"] if k["tech"] != "none" else 0.0
    v = st["controllerV"]
    base_w = (ctrl_ma + sensor_ma + comm_idle_ma) / 1000.0 * v / 0.85
    msgs_day = (86400.0 / report) if k["tech"] != "none" else 0.0
    if st["commMinInterval"] > 0:
        msgs_day = min(msgs_day, 86400.0 / st["commMinInterval"])
    tx_wh_day = msgs_day * (k["txJ"] + (k["wakeJ"] if lp else 0.0)) / 3600.0
    load_w = (a["loadV"] * a["loadA"]) if a["loadV"] > 0 else 0.0
    counted_s = max(1.0, (horizon - mission["settleS"]))
    act_wh_day = load_w * (act_on_time / counted_s) * 24.0
    energy_wh_day = base_w * 24.0 + tx_wh_day + act_wh_day
    autonomy = None
    if p["batteryWh"] > 0:
        autonomy = p["batteryWh"] / energy_wh_day if energy_wh_day > 0 else 999.0

    metrics = {
        "timeInBandPct": 100.0 * in_band / max(1, counted),
        "maxDeviation": max_dev,
        "switchesPerHour": switches / hours,
        "alarmLatencyS": alarm_latency,
        "actionLatencyS": action_latency,
        "falseAlarms": false_alarms,
        "alarmsSent": alarms_sent,
        "deliveredPct": delivered_pct,
        "delivered": delivered,
        "expected": expected,
        "lost": lost,
        "suppressed": suppressed,
        "energyWhDay": energy_wh_day,
        "autonomyDays": autonomy,
        "costPen": st["costPen"],
        "monthlyPen": st["monthlyPen"],
        "rmsError": math.sqrt(err_sq / err_n) if err_n else None,
        "saturationPct": 100.0 * sat / max(1, counted),
        "resets": resets,
        "pinDamaged": pin_damaged,
        "stallS": stall_total,
        "validReadings": err_n,
    }
    return {"setup": st, "metrics": metrics, "series": series, "events": events_log}


# --------------------------------------------------------------------------
# Evaluador de diseño (reglas deterministas)
# --------------------------------------------------------------------------

def evaluate(mission, design, cat, sim=None):
    if sim is None:
        sim = simulate(mission, design, cat)
    c, s, a, k, p, st = prepare(mission, design, cat)
    m = sim["metrics"]
    lg = design["logic"]
    req = mission["requirements"]
    site = mission["site"]
    F = []

    def add(code, dim, sev):
        F.append({"code": code, "dim": dim, "sev": sev})

    half_band = (mission["band"]["high"] - mission["band"]["low"]) / 2.0

    # ---- arquitectura ----
    if not st["controllerAlive"]:
        add("A01_controller_supply", "arquitectura", "critical")
    if st["commNeedsModule"]:
        add("A02_external_radio", "arquitectura", "suggestion")
    if lg["firmware"] == "rtos" and not c["rtosCapable"]:
        add("A03_rtos_ram", "arquitectura", "warning")
    if c["isLinux"] and req.get("requiresLatch"):
        add("A04_linux_realtime", "arquitectura", "warning")
    if p["mains"] and not req["mainsAvailable"]:
        add("A07_no_mains", "arquitectura", "critical")
    if req["minAutonomyDays"] > 0 and p["batteryWh"] > 0:
        if m["autonomyDays"] < req["minAutonomyDays"]:
            add("A05_autonomy", "arquitectura", "critical")
        else:
            add("P05_autonomy_ok", "arquitectura", "positive")
    if st["costPen"] > req["budgetPen"]:
        add("A06_budget", "arquitectura", "critical")
    if lg.get("lowPower") and not c["supportsDeepSleep"]:
        add("A09_no_deep_sleep", "arquitectura", "warning")
    if c["isLinux"] and not req.get("needsLinux"):
        add("A08_oversized", "arquitectura", "suggestion")

    # ---- sensores ----
    if not st["sensorMeasuresVar"]:
        add("S01_wrong_variable", "sensores", "critical")
    else:
        rng = mission["sensorRange"]
        if s["rangeMin"] > rng["min"] or s["rangeMax"] < rng["max"]:
            add("S02_range", "sensores", "critical")
        if s["accuracy"] > half_band:
            add("S03_accuracy", "sensores", "critical")
        elif s["accuracy"] > half_band * 0.6:
            add("S03_accuracy_marginal", "sensores", "warning")
        if not st["sensorPowered"]:
            add("S04_supply", "sensores", "critical")
        if st["noAdc"]:
            add("S05_no_adc", "sensores", "critical")
        if st["overrange"]:
            add("S06_overrange", "sensores", "critical")
        if st.get("levelMismatch") == "high_to_low":
            add("S07_level_5v_to_3v3", "sensores", "critical")
        elif st.get("levelMismatch") == "low_to_high":
            add("S07_level_3v3_to_5v", "sensores", "critical")
        if s["interface"] == "analog" and not st["noAdc"] and st["effRes"] + st["adcNoise"] > half_band / 4:
            add("S08_adc_resolution", "sensores", "warning")
        if lg["samplingS"] < s["minIntervalS"] - 1e-9:
            add("S09_min_interval", "sensores", "warning")
        if mission["environment"] in ("humid", "industrial", "outdoor") and not s["sealed"]:
            add("S10_not_sealed", "sensores", "warning")
        if s["driftPerDay"] > 0 and mission["horizonS"] >= 86400:
            add("S11_drift", "sensores", "warning")
        if mission.get("signalFreqHz", 0) > 0 and st["attenuation"] < 1.0:
            add("S12_bandwidth", "sensores", "critical")
        if not any(f["dim"] == "sensores" and f["sev"] in ("critical", "warning") for f in F):
            add("P01_sensor_ok", "sensores", "positive")

    # ---- actuadores ----
    if st["effectSign"] == 0:
        add("C01_no_effect", "actuadores", "critical")
    elif st["effectSign"] != mission["direction"]:
        add("C02_wrong_direction", "actuadores", "critical")
    if st["gpioOver"]:
        add("C03_gpio_overcurrent", "actuadores", "critical")
    if not st["loadVOk"]:
        add("C04_load_voltage", "actuadores", "critical")
    if st["brownout"]:
        add("C05_power_capacity", "actuadores", "critical")
    if st["relayPwm"]:
        add("C06_relay_pwm", "actuadores", "critical")
    if a["driver"] == "mosfet_std":
        add("C07_mosfet_gate", "actuadores", "warning")
    if a["maxSwitchesPerHour"] > 0 and m["switchesPerHour"] > a["maxSwitchesPerHour"]:
        add("C08_switch_rate", "actuadores", "critical" if a["switchLimitCritical"] else "warning")
    if not st["driverSupplyOk"]:
        add("C09_driver_supply", "actuadores", "critical")
    if st["effectSign"] == mission["direction"] and m["saturationPct"] > 90 and m["timeInBandPct"] < req["minTimeInBandPct"]:
        add("C10_undersized", "actuadores", "warning")
    if not any(f["dim"] == "actuadores" and f["sev"] in ("critical", "warning") for f in F):
        add("P02_actuator_ok", "actuadores", "positive")

    # ---- comunicación ----
    tech = k["tech"]
    if req["remoteAlarm"] and tech == "none":
        add("K01_no_remote", "comunicacion", "critical")
    if tech != "none" and not st["infraOk"]:
        add("K02_infra_missing", "comunicacion", "critical")
    if tech != "none" and st["infraOk"] and not st["rangeOk"]:
        add("K03_out_of_range", "comunicacion", "critical")
    if st["commOk"] and st["commMinInterval"] > 0 and lg["reportS"] < st["commMinInterval"] - 1e-9:
        add("K04_duty_cycle", "comunicacion", "critical")
    if st["commOk"] and site.get("linkPenalty", {}).get(tech, 0) > 0:
        add("K06_hostile_link", "comunicacion", "warning")
    if st["commOk"] and not any(f["dim"] == "comunicacion" and f["sev"] in ("critical", "warning") for f in F):
        add("P06_link_ok", "comunicacion", "positive")

    # ---- IoT ----
    if st["commOk"]:
        if m["deliveredPct"] < req["minDeliveryPct"]:
            add("I01_delivery", "iot", "critical")
        if lg["reportS"] > req["reportEveryS"] + 1e-9:
            add("I02_report_slow", "iot", "warning")
        if not lg.get("retry") and (st["loss"] > 0.02 or any(e["type"] == "link_outage" for e in mission["events"])):
            add("I03_no_retry", "iot", "warning")
        if lg.get("retry") and m["deliveredPct"] >= req["minDeliveryPct"]:
            add("P03_retry_ok", "iot", "positive")
        if st["monthlyPen"] > 0:
            add("I04_monthly_cost", "iot", "suggestion")
        if lg["reportS"] < req["reportEveryS"] / 4.0:
            add("I06_report_too_often", "iot", "suggestion")
    elif tech != "none" or req["remoteAlarm"]:
        add("I01_delivery", "iot", "critical")

    # ---- lógica ----
    band = mission["band"]
    if not (band["low"] <= lg["setpoint"] <= band["high"]):
        add("L02_setpoint_outside", "logica", "critical")
    if m["timeInBandPct"] < req["minTimeInBandPct"]:
        add("L01_time_in_band", "logica", "critical")
    if lg["algorithm"] == "onoff":
        add("L03_no_hysteresis", "logica", "suggestion")
    if lg["algorithm"] == "hysteresis" and lg.get("hysteresis", 0) > (band["high"] - band["low"]) + 1e-9:
        add("L04_hysteresis_wide", "logica", "warning")
    if lg["samplingS"] > mission["logic"]["maxGoodSamplingS"] + 1e-9:
        add("L05_sampling_slow", "logica", "warning")
    if req.get("requiresLatch") and lg["algorithm"] != "trip":
        add("L06_no_latch", "logica", "critical")
    if req.get("requiresLatch") and lg["algorithm"] == "trip":
        add("P04_latch_ok", "logica", "positive")
    if lg["firmware"] == "blocking" and (s["convTimeS"] >= 0.2 or (st["commOk"] and st["commLatency"] >= 1.0)):
        add("L07_blocking", "logica", "warning")
    lat = m["alarmLatencyS"]
    if lat is not None and lat > req["maxAlarmLatencyS"]:
        add("L08_alarm_latency", "logica", "critical")
    if m["actionLatencyS"] is not None and m["actionLatencyS"] > req["maxActionLatencyS"]:
        add("L10_action_latency", "logica", "critical")
    if m["falseAlarms"] > 0:
        add("L09_false_alarms", "logica", "warning")
    if st["sleepPwmLoss"]:
        add("L11_sleep_pwm", "logica", "warning")

    # ---- puntajes ----
    scores = {}
    for d in DIMENSIONS:
        pen = sum(PENALTY[f["sev"]] for f in F if f["dim"] == d)
        scores[d] = max(0, 100 - pen)
    overall = round(sum(scores.values()) / len(DIMENSIONS))
    criticals = [f for f in F if f["sev"] == "critical"]
    passed = len(criticals) == 0
    return {"findings": F, "scores": scores, "overall": overall, "passed": passed, "metrics": m}


# --------------------------------------------------------------------------

SIM_CODES = {"L01_time_in_band", "L08_alarm_latency", "L10_action_latency", "I01_delivery", "A05_autonomy", "C08_switch_rate"}


def robust(mission, design, cat, ev):
    """True si ninguna métrica simulada queda cerca de su umbral."""
    m = ev["metrics"]
    req = mission["requirements"]
    _, _, a, _, _, st = prepare(mission, design, cat)

    def far(v, lim, margin):
        return v is None or math.isinf(v) or abs(v - lim) >= margin

    checks = [far(m["timeInBandPct"], req["minTimeInBandPct"], 1.5)]
    if st["commOk"]:
        checks.append(far(m["deliveredPct"], req["minDeliveryPct"], 1.5))
    checks.append(far(m["alarmLatencyS"], req["maxAlarmLatencyS"], 0.1 * req["maxAlarmLatencyS"]))
    if req.get("maxActionLatencyS", 0) > 0:
        checks.append(far(m["actionLatencyS"], req["maxActionLatencyS"], 0.1 * req["maxActionLatencyS"]))
    if a["maxSwitchesPerHour"] > 0:
        checks.append(far(m["switchesPerHour"], a["maxSwitchesPerHour"], 0.1 * a["maxSwitchesPerHour"]))
    if req["minAutonomyDays"] > 0 and m["autonomyDays"] is not None:
        checks.append(far(m["autonomyDays"], req["minAutonomyDays"], 0.05 * req["minAutonomyDays"]))
    return all(checks)


def merged_design(mi, design):
    d = dict(mi["referenceDesign"])
    d.update({kk: vv for kk, vv in design.items() if kk != "logic"})
    d["logic"] = dict(mi["referenceDesign"]["logic"])
    d["logic"].update(design.get("logic", {}))
    return d


def write_fixture():
    cat = load("components.json")
    missions = load("missions.json")["missions"]
    cases = []
    for mi in missions:
        variants = [("reference", {})] + [(v["label"], v["design"]) for v in mi.get("calibration", [])]
        for label, design in variants:
            d = merged_design(mi, design)
            ev = evaluate(mi, d, cat)
            crit = sorted(f["code"] for f in ev["findings"] if f["sev"] == "critical")
            mm = ev["metrics"]
            cases.append({
                "mission": mi["id"],
                "label": label,
                "design": d,
                "robust": robust(mi, d, cat, ev),
                "passed": ev["passed"],
                "overall": ev["overall"],
                "critical": crit,
                "staticCritical": sorted(c for c in crit if c not in SIM_CODES),
                "timeInBandPct": round(mm["timeInBandPct"], 4),
                "costPen": mm["costPen"],
                "energyWhDay": round(mm["energyWhDay"], 4),
            })
    out = os.path.join(ROOT, "test", "fixtures", "reference_outcomes.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"generatedBy": "tools/reference_engine.py --fixture", "cases": cases}, f, ensure_ascii=False, indent=1)
    n_rob = sum(1 for c in cases if c["robust"])
    print(f"{len(cases)} casos escritos en test/fixtures/reference_outcomes.json ({n_rob} robustos).")
    bad = [c for c in cases if c["label"] == "reference" and not (c["passed"] and c["robust"])]
    for c in bad:
        print("  ATENCIÓN: la referencia de", c["mission"], "no es robusta o no aprueba")


def main():
    if "--fixture" in sys.argv:
        write_fixture()
        return
    cat = load("components.json")
    missions = load("missions.json")["missions"]
    as_json = "--json" in sys.argv
    out = {}
    for mi in missions:
        res = {}
        for label, design in [("reference", mi["referenceDesign"])] + [(v["label"], v["design"]) for v in mi.get("calibration", [])]:
            d = dict(mi["referenceDesign"])
            d.update({kk: vv for kk, vv in design.items() if kk != "logic"})
            d["logic"] = dict(mi["referenceDesign"]["logic"])
            d["logic"].update(design.get("logic", {}))
            ev = evaluate(mi, d, cat)
            res[label] = ev
        out[mi["id"]] = res
        if not as_json:
            print(f"\n=== {mi['id']} ===")
            for label, ev in res.items():
                mm = ev["metrics"]
                crit = [f["code"] for f in ev["findings"] if f["sev"] == "critical"]
                warn = [f["code"] for f in ev["findings"] if f["sev"] == "warning"]
                lat = mm["alarmLatencyS"]
                print(f"- {label:28s} pass={ev['passed']!s:5} score={ev['overall']:3d} TIB={mm['timeInBandPct']:.1f}% "
                      f"sw/h={mm['switchesPerHour']:.1f} lat={lat if lat is None else round(lat,1)} "
                      f"act={mm['actionLatencyS'] if mm['actionLatencyS'] is None else round(mm['actionLatencyS'],1)} "
                      f"del={mm['deliveredPct']:.1f}% E={mm['energyWhDay']:.1f}Wh/d aut={mm['autonomyDays'] if mm['autonomyDays'] is None else round(mm['autonomyDays'],1)} "
                      f"cost={mm['costPen']} rms={mm['rmsError'] if mm['rmsError'] is None else round(mm['rmsError'],3)}")
                print(f"    crit={crit}")
                print(f"    warn={warn}")
    if as_json:
        def clean(o):
            if isinstance(o, float) and math.isinf(o):
                return "inf"
            if isinstance(o, dict):
                return {kk: clean(vv) for kk, vv in o.items()}
            if isinstance(o, list):
                return [clean(vv) for vv in o]
            return o
        slim = {mid: {lab: {"passed": ev["passed"], "overall": ev["overall"],
                            "critical": sorted(f["code"] for f in ev["findings"] if f["sev"] == "critical"),
                            "metrics": {kk: ev["metrics"][kk] for kk in ("timeInBandPct", "switchesPerHour", "alarmLatencyS", "actionLatencyS", "deliveredPct", "energyWhDay", "autonomyDays", "costPen")}}
                      for lab, ev in r.items()} for mid, r in out.items()}
        print(json.dumps(clean(slim), indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
