#!/usr/bin/env python3
"""Verificación estática de imports para entornos sin SDK de Dart.

1. Cada import relativo apunta a un archivo existente.
2. Cada símbolo del proyecto usado en un archivo es visible desde él
   (declarado ahí, importado directamente o reexportado).
3. Cada import relativo aporta al menos un símbolo usado (imports sobrantes).
4. Los identificadores de Dart son ASCII (las tildes van en cadenas y comentarios).

No reemplaza a `flutter analyze`, que corre en CI, pero atrapa los errores
más frecuentes antes de subir el código.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = ["lib", "test"]


def strip_code(src):
    """Elimina comentarios y el texto de las cadenas, conservando interpolaciones."""
    out = []
    i = 0
    n = len(src)
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        if c in "'\"":
            raw = i > 0 and src[i - 1] == "r"
            triple = src.startswith(c * 3, i)
            q = c * 3 if triple else c
            i += len(q)
            while i < n and not src.startswith(q, i):
                if src[i] == "\\" and not raw:
                    i += 2
                    continue
                if not raw and src.startswith("${", i):
                    depth = 1
                    i += 2
                    start = i
                    while i < n and depth:
                        if src[i] == "{":
                            depth += 1
                        elif src[i] == "}":
                            depth -= 1
                        i += 1
                    out.append(" " + strip_code(src[start:i - 1]) + " ")
                    continue
                if not raw and src[i] == "$" and i + 1 < n and (src[i + 1].isalpha() or src[i + 1] == "_"):
                    m = re.match(r"\$([A-Za-z_]\w*)", src[i:])
                    out.append(" " + m.group(1) + " ")
                    i += len(m.group(0))
                    continue
                i += 1
            i += len(q)
            out.append(" '' ")
            continue
        out.append(c)
        i += 1
    return "".join(out)


DECL_RE = [
    re.compile(r"^(?:abstract\s+|sealed\s+|final\s+|base\s+|interface\s+)*(?:class|enum|mixin|typedef)\s+([A-Za-z_]\w*)", re.M),
    re.compile(r"^extension\s+([A-Za-z_]\w*)\s+on", re.M),
    re.compile(r"^(?:final|const|var|late\s+final)\s+(?:[\w<>?,\s]+\s+)?([A-Za-z_]\w*)\s*=", re.M),
    re.compile(r"^(?!(?:import|export|part|library|return|if|for|while|switch|class|enum|abstract|final|const|var)\b)"
               r"[A-Za-z_][\w<>?,\s\.\(\)]*?\s+([a-z_]\w*)\s*(?:<[^>]*>)?\(", re.M),
    re.compile(r"^(?:Future|void|String|int|double|bool|List|Map|Set|Color|IconData|Widget)[\w<>?,\s]*\s+([a-z_]\w*)\s*\(", re.M),
]


def files():
    for d in DIRS:
        for dp, _, fs in os.walk(os.path.join(ROOT, d)):
            for f in fs:
                if f.endswith(".dart"):
                    yield os.path.normpath(os.path.join(dp, f))


def resolve(frm, uri):
    if uri.startswith("package:electroboard/"):
        return os.path.normpath(os.path.join(ROOT, "lib", uri[len("package:electroboard/"):]))
    if uri.startswith("package:") or uri.startswith("dart:"):
        return None
    return os.path.normpath(os.path.join(os.path.dirname(frm), uri))


all_files = list(files())
raw = {f: open(f, encoding="utf-8").read() for f in all_files}
code = {f: strip_code(s) for f, s in raw.items()}
decls = {}
for f, s in raw.items():
    names = set()
    for rx in DECL_RE:
        for m in rx.finditer(strip_code(s)):
            names.add(m.group(1))
    decls[f] = {n for n in names if n not in {"main", "build", "if", "for", "switch", "while", "return"}}

imports = {}
exports = {}
errors = []
for f, s in raw.items():
    imports[f] = []
    exports[f] = []
    for m in re.finditer(r"^(import|export)\s+'([^']+)'(?:\s+(?:as\s+(\w+)|show\s+([\w,\s]+)|hide\s+[\w,\s]+))*;", s, re.M):
        kind, uri = m.group(1), m.group(2)
        target = resolve(f, uri)
        if target is None:
            continue
        if not os.path.exists(target):
            errors.append(f"{os.path.relpath(f, ROOT)}: {kind} inexistente '{uri}'")
            continue
        (imports if kind == "import" else exports)[f].append(target)


def visible(f, seen=None):
    """Archivos cuyos símbolos son visibles desde f por import directo + reexportaciones."""
    out = set()
    stack = list(imports[f])
    while stack:
        t = stack.pop()
        if t in out:
            continue
        out.add(t)
        stack.extend(exports.get(t, []))
    return out


def exported_closure(t):
    out = {t}
    stack = list(exports.get(t, []))
    while stack:
        x = stack.pop()
        if x in out:
            continue
        out.add(x)
        stack.extend(exports.get(x, []))
    return out


owner = {}
for f, names in decls.items():
    for n in names:
        owner.setdefault(n, set()).add(f)

# Métodos y campos comunes con nombres que coinciden con funciones de nivel superior.
MEMBER_LIKE = set()
for f, s in code.items():
    for m in re.finditer(r"\.\s*([A-Za-z_]\w*)", s):
        MEMBER_LIKE.add(m.group(1))

for f in all_files:
    vis = visible(f) | {f}
    tokens = set(re.findall(r"(?<![\w.$])([A-Za-z_]\w*)", code[f]))
    local_decl = decls[f]
    for tok in tokens:
        if tok not in owner or tok in local_decl:
            continue
        if not (owner[tok] & vis):
            # tolera nombres que en este archivo son parámetros o miembros (minúscula y ambigua)
            if tok[0].islower():
                pattern = re.compile(r"(?<![\w.])" + tok + r"\s*\(")
                if not pattern.search(code[f]):
                    continue
            errors.append(f"{os.path.relpath(f, ROOT)}: usa '{tok}' sin importar {sorted(os.path.relpath(o, ROOT) for o in owner[tok])}")
    # imports sobrantes
    for t in imports[f]:
        provided = set()
        for x in exported_closure(t):
            provided |= decls[x]
        if not (provided & tokens):
            errors.append(f"{os.path.relpath(f, ROOT)}: import sin uso '{os.path.relpath(t, os.path.dirname(f))}'")
    # identificadores ASCII
    for m in re.finditer(r"[A-Za-z_\w]*[áéíóúñÁÉÍÓÚÑ][\w]*", code[f]):
        errors.append(f"{os.path.relpath(f, ROOT)}: identificador no ASCII '{m.group(0)}'")

if errors:
    print("Problemas encontrados:")
    for e in sorted(set(errors)):
        print(" -", e)
    sys.exit(1)
print(f"Imports correctos en {len(all_files)} archivos ({sum(len(v) for v in decls.values())} símbolos del proyecto).")
