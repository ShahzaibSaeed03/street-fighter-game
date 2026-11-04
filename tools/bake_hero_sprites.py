#!/usr/bin/env python3
"""Bake orthographic top-down / portrait / side-view hero sprites.

Produces high-quality shaded PNGs that read as 3D-rendered sprites without
requiring Blender on the build machine. Output under assets/heroes/.
"""
from __future__ import annotations

import math
import os
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "heroes"
DEMO = Path(
    r"C:\Users\Lenovo\AppData\Local\Cursor\AgentStores"
    r"\cursor_agent_stores\bc-48639f76-0ccf-453b-ab26-427fc18e94d1\files"
    r"\media\heroes-3d"
)


@dataclass
class Palette:
    id: str
    name: str
    cape: tuple[int, int, int]
    cape_dark: tuple[int, int, int]
    plume: tuple[int, int, int]
    steel: tuple[int, int, int]
    steel_dark: tuple[int, int, int]
    gold: tuple[int, int, int]
    skin: tuple[int, int, int]
    hair: tuple[int, int, int]
    female: bool
    bulk: float  # body scale


HEROES = [
    Palette(
        "ayaan", "Jake",
        (168, 26, 38), (86, 12, 20), (200, 30, 40),
        (158, 168, 186), (70, 78, 96), (236, 188, 76),
        (224, 178, 140), (82, 52, 28), False, 1.0,
    ),
    Palette(
        "zara", "Maya",
        (40, 140, 88), (18, 72, 46), (70, 220, 130),
        (168, 176, 190), (74, 82, 98), (230, 196, 90),
        (158, 108, 78), (26, 16, 10), True, 0.94,
    ),
    Palette(
        "kabir", "Marcus",
        (36, 58, 150), (16, 28, 78), (70, 120, 255),
        (148, 160, 180), (62, 70, 90), (210, 176, 70),
        (132, 92, 66), (20, 16, 14), False, 1.08,
    ),
]


def _rgba(rgb, a=255):
    return (rgb[0], rgb[1], rgb[2], a)


def _lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _darken(rgb, amt):
    return tuple(max(0, int(c * (1.0 - amt))) for c in rgb)


def _lighten(rgb, amt):
    return tuple(min(255, int(c + (255 - c) * amt)) for c in rgb)


def soft_ellipse(img: Image.Image, cx, cy, rx, ry, color, soft=2.5):
    """Anti-aliased filled ellipse with soft edge via oversized blur."""
    pad = int(soft * 4) + 2
    w = int(rx * 2) + pad * 2
    h = int(ry * 2) + pad * 2
    layer = Image.new("RGBA", (max(w, 1), max(h, 1)), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.ellipse([pad, pad, pad + int(rx * 2), pad + int(ry * 2)], fill=color)
    if soft > 0:
        layer = layer.filter(ImageFilter.GaussianBlur(radius=soft))
    img.alpha_composite(layer, (int(cx - rx - pad), int(cy - ry - pad)))


def soft_poly(img: Image.Image, pts, color, soft=1.8):
    if len(pts) < 3:
        return
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)
    pad = int(soft * 4) + 2
    layer = Image.new("RGBA", (int(maxx - minx) + pad * 2 + 2, int(maxy - miny) + pad * 2 + 2), (0, 0, 0, 0))
    local = [(p[0] - minx + pad, p[1] - miny + pad) for p in pts]
    ImageDraw.Draw(layer).polygon(local, fill=color)
    if soft > 0:
        layer = layer.filter(ImageFilter.GaussianBlur(radius=soft))
    img.alpha_composite(layer, (int(minx - pad), int(miny - pad)))


def soft_line(img: Image.Image, a, b, color, width=3.0, soft=1.2):
    pad = int(max(width, soft) * 3) + 4
    xs = [a[0], b[0]]
    ys = [a[1], b[1]]
    minx, maxx = min(xs), max(xs)
    miny, maxy = min(ys), max(ys)
    layer = Image.new("RGBA", (int(maxx - minx) + pad * 2 + 2, int(maxy - miny) + pad * 2 + 2), (0, 0, 0, 0))
    ImageDraw.Draw(layer).line(
        [(a[0] - minx + pad, a[1] - miny + pad), (b[0] - minx + pad, b[1] - miny + pad)],
        fill=color, width=max(1, int(width)),
    )
    layer = layer.filter(ImageFilter.GaussianBlur(radius=soft))
    img.alpha_composite(layer, (int(minx - pad), int(miny - pad)))


def metal_disk(img, cx, cy, r, steel, steel_dark, highlight_dir=(-0.35, -0.55), rim=True):
    soft_ellipse(img, cx, cy, r + 1.6, r + 1.6, (12, 12, 18, 230), soft=1.4)
    soft_ellipse(img, cx, cy, r, r, _rgba(steel_dark, 255), soft=1.2)
    soft_ellipse(img, cx, cy, r * 0.86, r * 0.86, _rgba(steel, 255), soft=1.0)
    hx = cx + highlight_dir[0] * r * 0.35
    hy = cy + highlight_dir[1] * r * 0.35
    soft_ellipse(img, hx, hy, r * 0.42, r * 0.32, (255, 255, 255, 95), soft=2.2)
    soft_ellipse(img, hx - r * 0.1, hy - r * 0.15, r * 0.18, r * 0.14, (255, 255, 255, 140), soft=1.4)
    if rim:
        soft_ellipse(img, cx, cy - r * 0.55, r * 0.55, r * 0.18, (255, 255, 255, 55), soft=1.8)


def draw_topdown(p: Palette, frame: str = "idle", size: int = 256) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = size * 0.5
    cy = size * 0.52
    b = p.bulk
    # Forward is +X in game space; bake facing right so Godot can rotate.
    # Convert our draw space: +x right (forward), +y down (screen).

    walk = 0.0
    sword_a = -0.28
    squash_y = 1.0
    cape_extra = 0.0
    if frame == "walk_a":
        walk = 1.0
    elif frame == "walk_b":
        walk = -1.0
    elif frame == "attack":
        sword_a = -1.55
        cape_extra = 6.0
    elif frame == "dodge":
        squash_y = 0.78
        cape_extra = 10.0

    # Ground contact shadow (flattened)
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    soft_ellipse(shadow, cx + 3, cy + 14, 48 * b, 22 * b, (0, 0, 0, 90), soft=4.0)
    soft_ellipse(shadow, cx + 2, cy + 12, 36 * b, 16 * b, (0, 0, 0, 110), soft=3.0)
    img.alpha_composite(shadow)

    body = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    # Cape (behind)
    sway = walk * 5.0
    tail = cx - 52 * b - cape_extra
    soft_poly(body, [
        (cx - 2, cy - 28 * b), (cx - 2, cy + 28 * b),
        (tail, cy + 20 * b + sway), (tail - 10, cy), (tail, cy - 20 * b + sway),
    ], _rgba(p.cape_dark, 245), soft=2.4)
    soft_poly(body, [
        (cx - 4, cy - 18 * b), (cx - 4, cy + 18 * b),
        (tail + 12, cy + 12 * b + sway * 0.7), (tail + 6, cy), (tail + 12, cy - 12 * b + sway * 0.7),
    ], _rgba(p.cape, 250), soft=2.0)
    soft_line(body, (cx - 6, cy), (tail + 8, cy + sway * 0.3), _rgba(_darken(p.cape, 0.25), 180), 2.0, 1.0)
    soft_line(body, (cx - 6, cy - 10), (tail + 14, cy - 8 + sway * 0.5), (255, 255, 255, 40), 1.5, 1.2)

    if p.female:
        soft_poly(body, [
            (cx + 4, cy - 24 * b), (cx + 4, cy + 24 * b),
            (cx - 22 + sway * 0.3, cy + 30 * b), (cx - 22 + sway * 0.3, cy - 30 * b),
        ], _rgba(p.cape, 220), soft=2.2)

    # Boots
    step = walk * 10.0
    for sy, sstep in ((-14 * b, step), (14 * b, -step)):
        soft_ellipse(body, cx + sstep, cy + sy, 13 * b, 9 * b, (10, 10, 14, 230), soft=1.3)
        soft_ellipse(body, cx + sstep, cy + sy, 11.5 * b, 7.8 * b, _rgba(p.steel_dark, 255), soft=1.0)
        soft_ellipse(body, cx + sstep + 3, cy + sy - 1, 6.5 * b, 4.2 * b, _rgba(p.steel, 255), soft=0.9)
        soft_ellipse(body, cx + sstep + 4, cy + sy - 2.5, 4 * b, 1.6 * b, (255, 255, 255, 90), soft=1.0)

    # Shield arm (left / -y)
    shx, shy = cx + 16 * b, cy - 34 * b
    soft_line(body, (cx, cy - 26 * b), (shx, shy), (10, 10, 14, 230), 14 * b, 1.2)
    soft_line(body, (cx, cy - 26 * b), (shx, shy), _rgba(p.steel_dark, 255), 11 * b, 1.0)
    soft_ellipse(body, shx, shy, 15 * b, 22 * b, (10, 10, 14, 230), soft=1.4)
    soft_ellipse(body, shx, shy, 13.5 * b, 20 * b, _rgba(_darken(p.gold, 0.35), 255), soft=1.1)
    soft_ellipse(body, shx, shy, 11.5 * b, 17.5 * b, _rgba(_darken(p.cape, 0.2), 255), soft=1.0)
    soft_ellipse(body, shx + 3, shy - 4, 5.5 * b, 8 * b, (255, 255, 255, 45), soft=1.6)
    soft_line(body, (shx - 8 * b, shy), (shx + 8 * b, shy), (245, 245, 240, 230), 3.0, 0.8)
    soft_line(body, (shx, shy - 11 * b), (shx, shy + 11 * b), (245, 245, 240, 230), 3.0, 0.8)
    soft_ellipse(body, shx, shy, 5 * b, 5 * b, _rgba(p.gold, 255), soft=0.8)

    # Torso plate
    soft_ellipse(body, cx, cy, 26 * b, 34 * b, (10, 10, 14, 240), soft=1.6)
    soft_ellipse(body, cx, cy, 23.5 * b, 31 * b, _rgba(p.steel_dark, 255), soft=1.2)
    soft_ellipse(body, cx + 1, cy, 20.5 * b, 27.5 * b, _rgba(p.steel, 255), soft=1.0)
    soft_ellipse(body, cx - 7, cy + 8, 11 * b, 14 * b, (0, 0, 0, 55), soft=2.4)
    soft_ellipse(body, cx + 5, cy - 7, 10 * b, 13 * b, (255, 255, 255, 100), soft=2.5)
    # Tabard
    soft_poly(body, [
        (cx + 4, cy - 14 * b), (cx + 18 * b, cy - 14 * b), (cx + 20 * b, cy),
        (cx + 18 * b, cy + 14 * b), (cx + 4, cy + 14 * b),
    ], _rgba(p.cape, 240), soft=1.2)
    soft_line(body, (cx + 9, cy - 7), (cx + 9, cy + 7), _rgba(_lighten(p.cape, 0.15), 220), 2.5, 0.7)
    soft_line(body, (cx + 5, cy), (cx + 13, cy), _rgba(_lighten(p.cape, 0.15), 220), 2.5, 0.7)
    # Belt + gold rim
    soft_line(body, (cx - 16 * b, cy), (cx + 17 * b, cy), _rgba(p.gold, 240), 3.2, 0.8)
    soft_ellipse(body, cx + 3, cy, 3.2 * b, 3.2 * b, _rgba(p.gold, 255), soft=0.6)

    # Pauldrons
    for s in (-1.0, 1.0):
        pcx, pcy = cx - 2, cy + 30 * b * s
        metal_disk(body, pcx, pcy, 15.5 * b, p.steel, p.steel_dark)
        soft_ellipse(body, pcx + 3, pcy - 3, 5 * b, 4 * b, (255, 255, 255, 90), soft=1.4)
        soft_ellipse(body, pcx - 4, pcy + 3 * s, 2 * b, 2 * b, _rgba(p.gold, 255), soft=0.6)

    # Sword arm
    ang = sword_a
    hx = cx + 20 * b + math.cos(ang) * 8 * b
    hy = cy + 26 * b + math.sin(ang) * 8 * b
    soft_line(body, (cx, cy + 26 * b), (hx, hy), (10, 10, 14, 230), 13 * b, 1.1)
    soft_line(body, (cx, cy + 26 * b), (hx, hy), _rgba(p.steel_dark, 255), 10 * b, 0.9)
    soft_line(body, (cx, cy + 26 * b), (hx, hy), _rgba(p.steel, 255), 5.5 * b, 0.8)

    dx, dy = math.cos(ang), math.sin(ang)
    px, py = -dy, dx
    base = (hx + dx * 8, hy + dy * 8)
    tip = (hx + dx * 78 * b, hy + dy * 78 * b)
    # Blade outline + fill
    soft_poly(body, [
        (base[0] + px * 7, base[1] + py * 7), tip, (base[0] - px * 7, base[1] - py * 7),
    ], (10, 10, 14, 240), soft=1.3)
    soft_poly(body, [
        (base[0] + px * 5, base[1] + py * 5), tip, (base[0] - px * 5, base[1] - py * 5),
    ], _rgba((210, 220, 235), 255), soft=1.0)
    soft_poly(body, [
        (base[0] + px * 1.5, base[1] + py * 1.5), tip, (base[0] - px * 0.4, base[1] - py * 0.4),
    ], (255, 255, 255, 200), soft=0.9)
    soft_line(body, (base[0] + px * 14, base[1] + py * 14), (base[0] - px * 14, base[1] - py * 14),
              _rgba(p.gold, 255), 5.0, 0.8)
    soft_line(body, (hx - dx * 8, hy - dy * 8), base, (60, 35, 20, 255), 5.0, 0.7)
    soft_ellipse(body, hx - dx * 10, hy - dy * 10, 4.5 * b, 4.5 * b, _rgba(p.gold, 255), soft=0.7)
    metal_disk(body, hx, hy, 7 * b, p.steel, p.steel_dark, rim=False)

    if frame == "attack":
        trail = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        for i, alpha in enumerate((35, 55, 80)):
            a0 = ang + 0.35 + i * 0.25
            a1 = ang + 1.1 + i * 0.15
            for t in range(14):
                u = t / 13.0
                aa = a0 + (a1 - a0) * u
                rr = 58 * b + i * 3
                soft_ellipse(trail, hx + math.cos(aa) * rr, hy + math.sin(aa) * rr,
                             10 - i, 6 - i // 2, (255, 220, 140, alpha), soft=2.5)
        body.alpha_composite(trail)

    # Head / helm
    hcx, hcy = cx + 8 * b, cy
    if p.female:
        soft_ellipse(body, hcx - 8, hcy, 16 * b, 18 * b, _rgba(p.hair, 255), soft=1.8)
        soft_ellipse(body, hcx - 14, hcy - 10, 8 * b, 14 * b, _rgba(p.hair, 240), soft=1.6)
        soft_ellipse(body, hcx - 14, hcy + 10, 8 * b, 14 * b, _rgba(p.hair, 240), soft=1.6)

    # Plume
    soft_poly(body, [
        (hcx - 10, hcy - 6), (hcx - 10, hcy + 6),
        (hcx - 42 - sway * 0.4, hcy + 4 + sway * 0.3), (hcx - 48 - sway * 0.4, hcy - 2),
    ], _rgba(p.plume, 245), soft=1.8)
    soft_line(body, (hcx - 12, hcy), (hcx - 40 - sway * 0.3, hcy + sway * 0.2),
              _rgba(_lighten(p.plume, 0.35), 200), 2.0, 1.0)

    metal_disk(body, hcx, hcy, 20 * b, p.steel, p.steel_dark)
    soft_line(body, (hcx - 16 * b, hcy), (hcx + 16 * b, hcy), _rgba(p.gold, 230), 3.0, 0.7)
    soft_ellipse(body, hcx - 8, hcy - 11, 2.2 * b, 2.2 * b, _rgba(p.gold, 255), soft=0.5)
    soft_ellipse(body, hcx - 8, hcy + 11, 2.2 * b, 2.2 * b, _rgba(p.gold, 255), soft=0.5)
    # Visor
    soft_ellipse(body, hcx + 11 * b, hcy, 7 * b, 12 * b, (8, 8, 12, 255), soft=0.9)
    soft_ellipse(body, hcx + 11.5 * b, hcy, 5 * b, 9.5 * b, (4, 4, 8, 255), soft=0.6)
    soft_line(body, (hcx + 7 * b, hcy - 5), (hcx + 16 * b, hcy - 5), _rgba(p.steel_dark, 220), 2.0, 0.5)
    soft_line(body, (hcx + 7 * b, hcy + 5), (hcx + 16 * b, hcy + 5), _rgba(p.steel_dark, 220), 2.0, 0.5)
    soft_ellipse(body, hcx + 13 * b, hcy - 4.5, 2.0 * b, 2.0 * b, (180, 220, 255, 230), soft=0.7)
    soft_ellipse(body, hcx + 13 * b, hcy + 4.5, 2.0 * b, 2.0 * b, (180, 220, 255, 230), soft=0.7)

    if squash_y != 1.0:
        # Dodge squash baked into sprite
        nw, nh = body.size
        body = body.resize((nw, int(nh * squash_y)), Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.paste(body, (0, (size - body.size[1]) // 2))
        body = canvas

    img.alpha_composite(body)
    # Slight contrast / sharpen for "rendered" punch
    img = ImageEnhance.Contrast(img).enhance(1.08)
    img = img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=80, threshold=3))
    return img


def draw_portrait(p: Palette, size: int = 256) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Backdrop
    soft_ellipse(img, size * 0.5, size * 0.55, size * 0.46, size * 0.48, (28, 24, 38, 255), soft=3.0)
    soft_ellipse(img, size * 0.5, size * 0.55, size * 0.42, size * 0.44, (20, 17, 28, 255), soft=2.0)

    cx, cy = size * 0.5, size * 0.46
    # Shoulders / outfit
    soft_ellipse(img, cx, cy + 95, 90, 55, _rgba(p.cape, 255), soft=2.5)
    soft_ellipse(img, cx, cy + 78, 72, 40, _rgba(p.steel_dark, 255), soft=2.0)
    soft_ellipse(img, cx, cy + 70, 58, 28, _rgba(p.steel, 255), soft=1.6)
    soft_line(img, (cx - 40, cy + 58), (cx + 40, cy + 58), _rgba(p.gold, 230), 4, 1.0)

    # Neck
    soft_ellipse(img, cx, cy + 42, 18, 22, _rgba(p.skin, 255), soft=1.2)

    # Hair back
    if p.female:
        soft_ellipse(img, cx, cy + 20, 58, 70, _rgba(p.hair, 255), soft=2.5)
        soft_ellipse(img, cx - 48, cy + 30, 16, 48, _rgba(p.hair, 245), soft=2.0)
        soft_ellipse(img, cx + 48, cy + 30, 16, 48, _rgba(p.hair, 245), soft=2.0)
    else:
        soft_ellipse(img, cx, cy - 8, 54, 40, _rgba(p.hair, 255), soft=2.0)

    # Face
    soft_ellipse(img, cx, cy, 48, 56, (10, 8, 10, 200), soft=1.8)
    soft_ellipse(img, cx, cy, 45, 53, _rgba(p.skin, 255), soft=1.4)
    soft_ellipse(img, cx - 10, cy - 8, 18, 14, (255, 255, 255, 45), soft=2.5)
    soft_ellipse(img, cx + 8, cy + 18, 16, 12, _darken(p.skin, 0.12) + (80,), soft=2.2)

    # Hair front
    if p.female:
        soft_ellipse(img, cx, cy - 28, 52, 28, _rgba(p.hair, 255), soft=1.8)
    elif p.id == "kabir":
        # buzz / short dark
        soft_ellipse(img, cx, cy - 36, 46, 18, _rgba(p.hair, 230), soft=1.6)
        ImageDraw.Draw(img).arc([cx - 48, cy - 50, cx + 48, cy + 40], 200, 340, fill=_rgba(p.hair, 255), width=14)
    else:
        soft_ellipse(img, cx, cy - 26, 50, 28, _rgba(p.hair, 255), soft=1.6)

    # Eyes
    for sx in (-1.0, 1.0):
        ex, ey = cx + sx * 18, cy + 2
        soft_ellipse(img, ex, ey, 10, 7, (245, 245, 250, 255), soft=0.7)
        soft_ellipse(img, ex + sx * 1.5, ey + 0.5, 4.5, 4.5, (30, 20, 16, 255), soft=0.5)
        soft_ellipse(img, ex + sx * 0.5, ey - 1, 1.6, 1.6, (255, 255, 255, 220), soft=0.4)
        soft_line(img, (ex - 10, ey - 12), (ex + 10, ey - 14 + sx * 2), _rgba(p.hair, 240), 3.5, 0.8)

    # Nose / mouth
    soft_line(img, (cx, cy + 8), (cx - 3, cy + 22), _rgba(_darken(p.skin, 0.25), 200), 2.5, 0.7)
    ImageDraw.Draw(img).arc([cx - 14, cy + 22, cx + 14, cy + 42], 20, 160, fill=(120, 50, 50, 220), width=3)

    # Helm rim hint for Jake/Marcus
    if not p.female:
        soft_ellipse(img, cx, cy - 40, 40, 12, _rgba(p.steel, 180), soft=1.5)
        soft_line(img, (cx - 30, cy - 38), (cx + 30, cy - 38), _rgba(p.gold, 200), 2.5, 0.7)

    img = ImageEnhance.Contrast(img).enhance(1.1)
    img = img.filter(ImageFilter.UnsharpMask(radius=1.0, percent=70, threshold=2))
    return img


def draw_side(p: Palette, size=(160, 220)) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # Shadow
    soft_ellipse(img, w * 0.5, h - 12, 36, 8, (0, 0, 0, 100), soft=2.5)
    # Cape
    soft_poly(img, [
        (w * 0.48, 55), (w * 0.22, 100), (w * 0.18, 170), (w * 0.48, 150),
    ], _rgba(p.cape_dark, 245), soft=2.0)
    soft_poly(img, [
        (w * 0.48, 55), (w * 0.30, 95), (w * 0.28, 155), (w * 0.48, 140),
    ], _rgba(p.cape, 245), soft=1.6)
    # Legs
    soft_line(img, (w * 0.45, 140), (w * 0.38, h - 18), _rgba(p.steel_dark, 255), 10, 1.0)
    soft_line(img, (w * 0.55, 140), (w * 0.62, h - 18), _rgba(p.steel, 255), 10, 1.0)
    soft_line(img, (w * 0.34, h - 18), (w * 0.46, h - 18), (20, 16, 18, 255), 7, 0.8)
    soft_line(img, (w * 0.56, h - 18), (w * 0.70, h - 18), (20, 16, 18, 255), 7, 0.8)
    # Torso
    soft_ellipse(img, w * 0.52, 105, 22, 40, (10, 10, 14, 230), soft=1.4)
    soft_ellipse(img, w * 0.52, 105, 19, 36, _rgba(p.steel, 255), soft=1.1)
    soft_ellipse(img, w * 0.58, 100, 8, 28, _rgba(p.steel_dark, 200), soft=1.2)
    soft_ellipse(img, w * 0.48, 95, 8, 16, (255, 255, 255, 70), soft=2.0)
    soft_line(img, (w * 0.40, 130), (w * 0.64, 130), _rgba(p.gold, 240), 4, 0.8)
    soft_ellipse(img, w * 0.52, 72, 14, 10, _rgba(p.steel_dark, 255), soft=1.0)  # shoulder
    # Head
    if p.female:
        soft_ellipse(img, w * 0.50, 48, 18, 22, _rgba(p.hair, 255), soft=1.6)
    soft_ellipse(img, w * 0.54, 48, 14, 16, _rgba(p.skin, 255), soft=1.0)
    soft_ellipse(img, w * 0.54, 42, 15, 10, _rgba(p.steel, 230), soft=1.0)  # helm
    soft_ellipse(img, w * 0.58, 48, 2.2, 2.2, (20, 16, 14, 255), soft=0.4)
    soft_poly(img, [
        (w * 0.46, 34), (w * 0.42, 28), (w * 0.30, 22), (w * 0.36, 36),
    ], _rgba(p.plume, 245), soft=1.2)
    # Arm + sword
    soft_line(img, (w * 0.58, 85), (w * 0.78, 115), _rgba(p.steel, 255), 8, 0.9)
    soft_line(img, (w * 0.78, 115), (w * 0.90, 55), (220, 228, 240, 255), 4, 0.7)
    soft_line(img, (w * 0.74, 118), (w * 0.84, 112), _rgba(p.gold, 240), 3, 0.6)
    img = ImageEnhance.Contrast(img).enhance(1.08)
    return img


def sheet_row(images: list[Image.Image]) -> Image.Image:
    h = max(im.size[1] for im in images)
    w = sum(im.size[0] for im in images)
    sheet = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x = 0
    for im in images:
        sheet.alpha_composite(im, (x, (h - im.size[1]) // 2))
        x += im.size[0]
    return sheet


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    DEMO.mkdir(parents=True, exist_ok=True)
    frames = ("idle", "walk_a", "walk_b", "attack", "dodge")
    for p in HEROES:
        top_frames = []
        for fr in frames:
            im = draw_topdown(p, fr, 256)
            path = OUT / f"{p.id}_top_{fr}.png"
            im.save(path, "PNG")
            top_frames.append(im)
            print("wrote", path)

        sheet = sheet_row(top_frames)
        sp = OUT / f"{p.id}_top_sheet.png"
        sheet.save(sp, "PNG")

        portrait = draw_portrait(p, 256)
        pp = OUT / f"{p.id}_portrait.png"
        portrait.save(pp, "PNG")
        print("wrote", pp)

        side = draw_side(p)
        sd = OUT / f"{p.id}_side.png"
        side.save(sd, "PNG")
        print("wrote", sd)

        # Demo composites for the store media folder
        demo = Image.new("RGBA", (256 * 3 + 40, 280), (18, 16, 24, 255))
        demo.alpha_composite(top_frames[0], (10, 12))
        demo.alpha_composite(portrait, (276, 12))
        demo.alpha_composite(side.resize((160, 220), Image.Resampling.LANCZOS), (552, 30))
        dpath = DEMO / f"{p.id}_preview.png"
        demo.convert("RGB").save(dpath, "PNG")
        print("demo", dpath)

    # Comparison strip
    strip = Image.new("RGB", (256 * 3 + 32, 270), (16, 14, 22))
    for i, p in enumerate(HEROES):
        im = Image.open(OUT / f"{p.id}_top_idle.png")
        strip.paste(im.convert("RGBA"), (8 + i * 256, 8), im)
    strip.save(DEMO / "heroes_topdown_strip.png", "PNG")
    print("done ->", OUT)


if __name__ == "__main__":
    main()
