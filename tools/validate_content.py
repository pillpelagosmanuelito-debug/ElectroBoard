#!/usr/bin/env python3
"""Valida la integridad del contenido declarativo de ElectroBoard.

Revisa que todas las referencias cruzadas entre los JSON existan, que cada
código de hallazgo emitido por el motor tenga su texto y que las preguntas
de control estén bien formadas. Sale con código 1 si encuentra errores.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "assets", "data")
errors = []


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as f:
        return json.load(f)


cat = load("components.json")
missions = load("missions.json")["missions"]
modules = load("modules.json")["modules"]
findings = load("findings.json")["findings"]

ids = {k: {i["id"] for i in cat[k]} for k in ("controllers", "sensors", "actuators", "comms", "power")}
lessons = {l["id"]: l for m in modules for l in m["lessons"]}
pool_key = {"sensors": "sensors", "controllers": "controllers", "actuators": "actuators", "comms": "comms", "power": "power"}
design_key = {"sensorId": "sensors", "controllerId": "controllers", "actuatorId": "actuators", "commId": "comms", "powerId": "power"}
module_ids = {m["id"] for m in modules}

for kind, items in cat.items():
    if not isinstance(items, list):
        continue
    seen = set()
    for it in items:
        if it["id"] in seen:
            errors.append(f"id duplicado en {kind}: {it['id']}")
        seen.add(it["id"])
        if not re.fullmatch(r"[a-z0-9_]+", it["id"]):
            errors.append(f"id no ASCII en {kind}: {it['id']}")

for m in missions:
    mid = m["id"]
    for k, lst in m["pools"].items():
        for i in lst:
            if i not in ids[pool_key[k]]:
                errors.append(f"{mid}: {i} no existe en {k}")
    for l in m["lessonIds"]:
        if l not in lessons:
            errors.append(f"{mid}: lección {l} no existe")
    for mod in m["modules"]:
        if mod not in module_ids:
            errors.append(f"{mid}: módulo {mod} no existe")
    rd = m["referenceDesign"]
    for dk, pk in design_key.items():
        if rd[dk] not in m["pools"][pk]:
            errors.append(f"{mid}: el diseño de referencia usa {rd[dk]} fuera del catálogo de la misión")
    lg = m["logic"]
    for name in ("referenceDesign",):
        l = m[name]["logic"]
        if l["algorithm"] not in lg["algorithms"]:
            errors.append(f"{mid}: algoritmo de referencia no permitido")
        if l["samplingS"] not in lg["samplingOptions"]:
            errors.append(f"{mid}: muestreo de referencia fuera de las opciones")
        if l["reportS"] not in lg["reportOptions"]:
            errors.append(f"{mid}: reporte de referencia fuera de las opciones")
    dl = m["defaultLogic"]
    if dl["algorithm"] not in lg["algorithms"] or dl["samplingS"] not in lg["samplingOptions"] or dl["reportS"] not in lg["reportOptions"]:
        errors.append(f"{mid}: la lógica por defecto usa valores fuera de las opciones")
    if not (lg["setpointMin"] <= dl["setpoint"] <= lg["setpointMax"]):
        errors.append(f"{mid}: consigna por defecto fuera del deslizador")
    if m["band"]["low"] >= m["band"]["high"]:
        errors.append(f"{mid}: banda inválida")
    if len(m["hints"]) < 2:
        errors.append(f"{mid}: faltan pistas")
    if m["requirements"]["reportEveryS"] not in lg["reportOptions"]:
        errors.append(f"{mid}: el reporte requerido no es una opción seleccionable")

for l in lessons.values():
    c = l["check"]
    if not (0 <= c["answer"] < len(c["options"])):
        errors.append(f"lección {l['id']}: índice de respuesta inválido")
    if len(set(c["options"])) != len(c["options"]):
        errors.append(f"lección {l['id']}: opciones repetidas")

for code, f in findings.items():
    if f["lessonId"] not in lessons:
        errors.append(f"hallazgo {code}: lección {f['lessonId']} no existe")

# códigos emitidos por el motor de referencia y por el evaluador en Dart
engine_src = open(os.path.join(ROOT, "tools", "reference_engine.py"), encoding="utf-8").read()
codes = set(re.findall(r'add\("([A-Z]\d{2}_[a-z0-9_]+)"', engine_src))
for c in sorted(codes):
    if c not in findings:
        errors.append(f"el motor emite {c} y no tiene texto en findings.json")
dart_eval = os.path.join(ROOT, "lib", "domain", "evaluator", "design_evaluator.dart")
if os.path.exists(dart_eval):
    dsrc = open(dart_eval, encoding="utf-8").read()
    dcodes = set(re.findall(r"'([A-Z]\d{2}_[a-z0-9_]+)'", dsrc))
    for c in sorted(codes - dcodes):
        errors.append(f"el evaluador de Dart no implementa {c}")
    for c in sorted(dcodes - codes):
        errors.append(f"el evaluador de Dart emite {c}, ausente en el motor de referencia")

if errors:
    print("Errores de contenido:")
    for e in errors:
        print(" -", e)
    sys.exit(1)
print(f"Contenido válido: {len(missions)} misiones, {len(modules)} módulos, {len(lessons)} lecciones, "
      f"{len(findings)} hallazgos, {sum(len(v) for v in ids.values())} componentes, {len(codes)} códigos de regla.")
