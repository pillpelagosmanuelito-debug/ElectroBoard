#!/usr/bin/env python3
"""Verifica que las llamadas a constructores del proyecto usen argumentos con
nombre existentes y que incluyan todos los parámetros `required`.

Complementa a check_imports.py cuando no se dispone del analizador de Dart.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from check_imports import ROOT, all_files, code  # noqa: E402


def matching(s, i, open_c, close_c):
    depth = 0
    for j in range(i, len(s)):
        if s[j] == open_c:
            depth += 1
        elif s[j] == close_c:
            depth -= 1
            if depth == 0:
                return j
    return -1


def split_top(s):
    parts, depth, cur = [], 0, []
    for ch in s:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        parts.append("".join(cur))
    return parts


ctors = {}  # nombre -> (named, required, positional_count)
for f in all_files:
    s = code[f]
    for m in re.finditer(r"\bclass\s+([A-Z]\w*)[^{]*\{", s):
        name = m.group(1)
        body_start = m.end() - 1
        body_end = matching(s, body_start, "{", "}")
        body = s[body_start:body_end]
        for cm in re.finditer(r"(?:const\s+)?\b" + name + r"\s*\(", body):
            # ignora usos que no sean declaraciones (factory, llamadas internas)
            before = body[max(0, cm.start() - 12):cm.start()]
            if "factory" in before or "return" in before or "=" in before[-3:]:
                continue
            p0 = cm.end() - 1
            p1 = matching(body, p0, "(", ")")
            params = body[p0 + 1:p1]
            named, required, positional = set(), set(), 0
            brace = params.find("{")
            pos_part = params if brace < 0 else params[:brace]
            positional = len([x for x in split_top(pos_part) if x.strip()])
            if brace >= 0:
                inner = params[brace + 1:params.rfind("}")]
                for p in split_top(inner):
                    p = p.strip()
                    if not p:
                        continue
                    mm = re.search(r"(?:this\.|super\.)?([A-Za-z_]\w*)\s*(?:=.*)?$", p)
                    if mm:
                        named.add(mm.group(1))
                        if p.startswith("required"):
                            required.add(mm.group(1))
            ctors[name] = (named, required, positional)
            break

errors = []
for f in all_files:
    s = code[f]
    for name, (named, required, positional) in ctors.items():
        for m in re.finditer(r"(?<![\w.])(?:const\s+)?" + name + r"\s*\(", s):
            ctx = s[max(0, m.start() - 30):m.start()]
            if re.search(r"(class|extends|implements|with|factory|new)\s*$", ctx):
                continue
            # evita la propia declaración del constructor
            line_start = s.rfind("\n", 0, m.start()) + 1
            line = s[line_start:m.start()]
            if line.strip() in ("", "const") and re.match(r"\s*(const\s+)?" + name + r"\s*\(\{?\s*(super\.key|required this|this\.)", s[m.start():m.start() + 80]):
                continue
            p0 = m.end() - 1
            p1 = matching(s, p0, "(", ")")
            after = s[p1 + 1:p1 + 40].lstrip()
            if line.strip() in ("", "const") and (after.startswith(":") or after.startswith("{")):
                continue  # es una declaración de constructor, no una llamada
            args = split_top(s[p0 + 1:p1])
            used = set()
            pos = 0
            for a in args:
                am = re.match(r"\s*([A-Za-z_]\w*)\s*:(?!:)", a)
                if am and not a.strip().startswith("'"):
                    used.add(am.group(1))
                elif a.strip():
                    pos += 1
            unknown = used - named - {"key"}
            missing = required - used
            rel = os.path.relpath(f, ROOT)
            if unknown:
                errors.append(f"{rel}: {name}(...) con argumentos inexistentes {sorted(unknown)}")
            if missing:
                errors.append(f"{rel}: {name}(...) sin parámetros requeridos {sorted(missing)}")
            if pos > positional:
                errors.append(f"{rel}: {name}(...) con {pos} argumentos posicionales y admite {positional}")

if errors:
    print("Problemas en llamadas a constructores:")
    for e in sorted(set(errors)):
        print(" -", e)
    sys.exit(1)
print(f"Constructores verificados: {len(ctors)} clases del proyecto.")
