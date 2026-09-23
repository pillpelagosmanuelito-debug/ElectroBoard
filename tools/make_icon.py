#!/usr/bin/env python3
"""Genera el ícono de ElectroBoard (assets/icon/).

Motivo: un microcontrolador sobre máscara de soldadura verde, con pistas de
cobre hacia un sensor, una onda de osciloscopio en el chip y arcos de señal
inalámbrica. Representa la integración de hardware, software y comunicación.

Salidas:
  icon.png             1024×1024, fondo completo (ícono clásico y tiendas)
  icon_foreground.png  1024×1024, fondo transparente (ícono adaptable de Android)
  icon_preview.png     512×512, vista previa para la documentación
"""
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icon")
S = 4  # supermuestreo
N = 1024 * S

MASK = (10, 46, 34)
MASK_LIGHT = (18, 70, 51)
COPPER = (224, 153, 74)
COPPER_DARK = (156, 106, 53)
CHIP = (12, 22, 19)
CHIP_EDGE = (46, 92, 74)
SIGNAL = (83, 224, 201)
HOLE = (6, 31, 23)


def draw_motif(img, scale=1.0, offset=(0, 0)):
    d = ImageDraw.Draw(img)
    cx, cy = N / 2 + offset[0] * S, N / 2 + offset[1] * S

    def P(x, y):
        return (cx + x * scale * S, cy + y * scale * S)

    def w(v):
        return int(v * scale * S)

    # ---- pistas de cobre ----
    trace = w(30)
    paths = [
        [(-130, 40), (-250, 40), (-300, 90), (-300, 210)],      # hacia el sensor
        [(-40, 130), (-40, 250), (-90, 300), (-200, 300)],       # hacia el sensor (segunda línea)
        [(130, -60), (230, -60), (270, -100)],                   # hacia la antena
        [(60, 130), (60, 280)],                                  # hacia abajo
        [(130, 60), (290, 60), (290, 200)],                      # hacia el actuador
    ]
    for pts in paths:
        pp = [P(*p) for p in pts]
        d.line(pp, fill=COPPER, width=trace, joint="curve")
        for p in (pp[0], pp[-1]):
            r = trace * 0.5
            d.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=COPPER)

    # ---- pads y vías ----
    def via(x, y, r=34):
        p = P(x, y)
        d.ellipse([p[0] - w(r), p[1] - w(r), p[0] + w(r), p[1] + w(r)], fill=COPPER)
        d.ellipse([p[0] - w(r * 0.42), p[1] - w(r * 0.42), p[0] + w(r * 0.42), p[1] + w(r * 0.42)], fill=HOLE)

    via(60, 290)
    via(290, 210)

    # sensor: pastilla redonda con anillo
    sp = P(-300, 262)
    for r, col in ((92, COPPER), (70, MASK), (52, COPPER), (30, MASK_LIGHT)):
        d.ellipse([sp[0] - w(r), sp[1] - w(r), sp[0] + w(r), sp[1] + w(r)], fill=col)
    via(-200, 300, 28)

    # ---- chip ----
    half = 150
    pin_len, pin_w, pins = 44, 26, 5
    for i in range(pins):
        t = -half + (i + 0.5) * (2 * half / pins)
        for side in range(4):
            if side == 0:
                box = (t - pin_w / 2, -half - pin_len, t + pin_w / 2, -half + 6)
            elif side == 1:
                box = (t - pin_w / 2, half - 6, t + pin_w / 2, half + pin_len)
            elif side == 2:
                box = (-half - pin_len, t - pin_w / 2, -half + 6, t + pin_w / 2)
            else:
                box = (half - 6, t - pin_w / 2, half + pin_len, t + pin_w / 2)
            a, b = P(box[0], box[1]), P(box[2], box[3])
            d.rounded_rectangle([a, b], radius=w(5), fill=COPPER)
    a, b = P(-half, -half), P(half, half)
    d.rounded_rectangle([a, b], radius=w(26), fill=CHIP, outline=CHIP_EDGE, width=w(8))
    # marca del pin 1
    m = P(-half + 34, -half + 34)
    d.ellipse([m[0] - w(12), m[1] - w(12), m[0] + w(12), m[1] + w(12)], fill=CHIP_EDGE)

    # onda de osciloscopio (lectura del sensor → decisión)
    wave = []
    for k in range(0, 201):
        x = -110 + k * 1.1
        u = (x + 110) / 220
        if u < 0.28:
            y = 30
        elif u < 0.34:
            y = 30 - (u - 0.28) / 0.06 * 90
        elif u < 0.52:
            y = -60 + 10 * math.sin((u - 0.34) * 60)
        elif u < 0.58:
            y = -60 + (u - 0.52) / 0.06 * 90
        else:
            y = 30 - 22 * math.exp(-(u - 0.58) * 9) * math.cos((u - 0.58) * 45)
        wave.append(P(x, y + 10))
    d.line(wave, fill=SIGNAL, width=w(18), joint="curve")

    # ---- arcos de señal inalámbrica ----
    ax, ay = 300, -130
    for i, r in enumerate((70, 125, 180)):
        c = P(ax - 40, ay + 40)
        rr = w(r)
        d.arc([c[0] - rr, c[1] - rr, c[0] + rr, c[1] + rr], start=-90, end=0, fill=SIGNAL, width=w(24))
    dot = P(ax - 40, ay + 40)
    d.ellipse([dot[0] - w(22), dot[1] - w(22), dot[0] + w(22), dot[1] + w(22)], fill=SIGNAL)


def background():
    img = Image.new("RGB", (N, N), MASK)
    d = ImageDraw.Draw(img)
    # degradado suave
    for y in range(0, N, S * 4):
        t = y / N
        col = tuple(int(MASK_LIGHT[i] * (1 - t) + MASK[i] * t) for i in range(3))
        d.rectangle([0, y, N, y + S * 4], fill=col)
    # pistas tenues de fondo
    faint = (22, 84, 62)
    for k, y in enumerate(range(90, 1024, 118)):
        x0 = 40 + (k * 97) % 180
        d.line([(x0 * S, y * S), ((x0 + 170) * S, y * S), ((x0 + 210) * S, (y + 40) * S)], fill=faint, width=10 * S)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    full = background().convert("RGBA")
    draw_motif(full, scale=1.0)
    full = full.resize((1024, 1024), Image.LANCZOS)
    full.convert("RGB").save(os.path.join(OUT, "icon.png"))
    full.resize((512, 512), Image.LANCZOS).convert("RGB").save(os.path.join(OUT, "icon_preview.png"))

    # Ícono adaptable: el motivo cabe en el círculo seguro (66 dp de 108 dp, radio ≈ 313 px).
    fg = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    draw_motif(fg, scale=0.64)
    fg = fg.resize((1024, 1024), Image.LANCZOS)
    fg.save(os.path.join(OUT, "icon_foreground.png"))
    print("Íconos generados en", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
