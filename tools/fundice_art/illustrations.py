"""The five 240 x 180 illustrations: welcome, searching, trophy, defeat, offline.

All of them share one language: a soft mint pebble behind the subject, dice drawn exactly like die_N.svg,
gold sparkles as the only accent, rounded lines. No text.
"""

import math

from . import palette
from .dice import IVORY, face_shapes, placed
from .svg_kit import (
    circle,
    document,
    ellipse,
    num,
    path,
    pebble,
    plus,
    rect,
    sparkle,
    star,
    stroke,
)

WIDTH, HEIGHT = 240, 180
WHITE = palette.SURFACE


def _backdrop() -> list[str]:
    """Mint pebble with a lighter highlight in its upper left."""
    return [
        path(pebble((116, 22), (218, 84), (126, 164), (22, 98)), fill=palette.PRIMARY_LIGHT),
        path(pebble((88, 34), (132, 50), (96, 76), (46, 58)), fill=WHITE, fill_opacity=0.45),
    ]


def _shadow(cx: float, cy: float, rx: float, ry: float = 6) -> str:
    return ellipse(cx, cy, rx, ry, fill=palette.PRIMARY, fill_opacity=0.14)


def _die(value: int, cx: float, cy: float, size: float, angle: float = 0) -> str:
    return placed(face_shapes(value, IVORY), cx, cy, size, angle)


def _arc(cx: float, cy: float, r: float, start: float, end: float) -> str:
    """Circular arc from `start` to `end` degrees, clockwise on screen, 0 = east."""
    x1, y1 = cx + r * math.cos(math.radians(start)), cy + r * math.sin(math.radians(start))
    x2, y2 = cx + r * math.cos(math.radians(end)), cy + r * math.sin(math.radians(end))
    return f"M{num(x1)} {num(y1)}A{num(r)} {num(r)} 0 {int((end - start) % 360 > 180)} 1 {num(x2)} {num(y2)}"


def _line(x1: float, y1: float, x2: float, y2: float) -> str:
    return f"M{num(x1)} {num(y1)}L{num(x2)} {num(y2)}"


def _dot(x: float, y: float, r: float, color: str) -> str:
    return circle(x, y, r, fill=color)


def welcome() -> str:
    return document(WIDTH, HEIGHT, [
        *_backdrop(),
        _shadow(126, 154, 56),
        _die(3, 62, 70, 54, -22),
        _die(1, 184, 72, 56, 19),
        _die(5, 122, 110, 78, -9),
        sparkle(40, 40, 10, palette.GOLD),
        sparkle(206, 38, 13, palette.GOLD),
        sparkle(200, 138, 8, palette.GOLD),
        plus(150, 28, 10, palette.PRIMARY),
        plus(46, 138, 9, palette.GOLD),
        _dot(28, 104, 4, palette.PRIMARY),
        _dot(214, 104, 3.5, palette.GOLD),
    ])


def searching() -> str:
    lens, radius = (112, 90), 46
    unit = math.sqrt(0.5)

    def along_handle(distance: float) -> tuple[float, float]:
        return lens[0] + unit * distance, lens[1] + unit * distance

    return document(WIDTH, HEIGHT, [
        *_backdrop(),
        *(path(_arc(*lens, r, -55, -15), **stroke(palette.PRIMARY, 4), stroke_opacity=opacity)
          for r, opacity in ((58, 0.7), (68, 0.45), (78, 0.25))),
        circle(*lens, radius, fill=WHITE, fill_opacity=0.6),
        _die(4, *lens, 52, -8),
        circle(*lens, radius, fill="none", stroke=palette.PRIMARY, stroke_width=8),
        path(_arc(*lens, radius - 10, 205, 245), **stroke(WHITE, 4)),
        path(_line(*along_handle(radius + 3), *along_handle(radius + 16)), **stroke(palette.GOLD_DARK, 15)),
        path(_line(*along_handle(radius + 16), *along_handle(radius + 50)), **stroke(palette.GOLD, 13)),
        sparkle(200, 56, 11, palette.GOLD),
        plus(44, 56, 10, palette.PRIMARY),
        _dot(38, 118, 4, palette.PRIMARY),
        _dot(196, 128, 4, palette.GOLD),
    ])


def trophy() -> str:
    gold = palette.GOLD
    handle = {"fill": "none", "stroke": gold, "stroke_width": 8, "stroke_linecap": "round"}
    return document(WIDTH, HEIGHT, [
        *_backdrop(),
        _shadow(112, 148, 58),
        path("M84 56C60 52 56 86 90 92", **handle),
        path("M140 56C164 52 168 86 134 92", **handle),
        path("M82 46H142C142 82 130 102 112 106C94 102 82 82 82 46Z", fill=gold),
        path("M91 54C91 74 96 88 104 96", **stroke(palette.GOLD_LIGHT, 5), stroke_opacity=0.75),
        rect(78, 40, 68, 12, rx=6, fill=palette.GOLD_DARK),
        rect(104, 104, 16, 18, fill=palette.GOLD_DARK),
        rect(90, 120, 44, 10, rx=4, fill=gold),
        rect(80, 128, 64, 14, rx=5, fill=palette.GOLD_DARK),
        star(116, 70, 11, palette.GOLD_LIGHT),
        _shadow(166, 150, 26, 4),
        _die(6, 166, 124, 52, 12),
        star(112, 22, 10, gold),
        star(58, 44, 7, gold, tilt=-12),
        star(170, 44, 8, gold, tilt=14),
        sparkle(36, 84, 8, palette.GOLD),
        sparkle(204, 80, 10, palette.GOLD),
        _dot(204, 112, 3.5, palette.PRIMARY),
        _dot(44, 120, 4, palette.GOLD),
    ])


def defeat() -> str:
    pole_foot, pole_top = (152, 146), (160, 40)
    return document(WIDTH, HEIGHT, [
        *_backdrop(),
        _shadow(110, 150, 50),
        path(_line(*pole_foot, *pole_top), **stroke(palette.TEXT_MUTED, 4)),
        path("M160 48C172 42 182 56 198 50L194 76C180 82 172 68 158 74Z",
             fill=WHITE, stroke=palette.BORDER, stroke_width=2, stroke_linejoin="round"),
        _dot(*pole_top, 4.5, palette.GOLD),
        _die(2, 106, 106, 74, -20),
        sparkle(44, 46, 9, palette.GOLD),
        plus(40, 122, 10, palette.PRIMARY),
        _dot(204, 124, 4, palette.PRIMARY),
    ])


def offline() -> str:
    badge, badge_radius = (164, 62), 30
    glyph_origin = (badge[0], badge[1] + 10)
    slash = ((badge[0] - 17, badge[1] - 17), (badge[0] + 17, badge[1] + 17))
    return document(WIDTH, HEIGHT, [
        *_backdrop(),
        _shadow(106, 152, 46),
        _die(5, 104, 106, 80, -10),
        circle(badge[0], badge[1] + 3, badge_radius, fill=palette.PRIMARY, fill_opacity=0.18),
        circle(*badge, badge_radius, fill=WHITE, stroke=palette.BORDER, stroke_width=2),
        *(path(_arc(*glyph_origin, r, -135, -45), **stroke(palette.TEXT_MUTED, 4.5)) for r in (8, 15, 22)),
        _dot(*glyph_origin, 3.5, palette.TEXT_MUTED),
        path(_line(*slash[0], *slash[1]), **stroke(WHITE, 11)),
        path(_line(*slash[0], *slash[1]), **stroke(palette.DANGER, 5)),
        sparkle(40, 44, 9, palette.GOLD),
        sparkle(206, 126, 8, palette.GOLD),
        plus(198, 98, 9, palette.PRIMARY),
        _dot(34, 124, 4, palette.PRIMARY),
    ])


def logo() -> str:
    return document(120, 120, [
        placed(face_shapes(5, IVORY), 44, 46, 56, -14),
        placed(face_shapes(3, IVORY), 74, 76, 60, 10),
        sparkle(98, 24, 11, palette.GOLD),
    ])
