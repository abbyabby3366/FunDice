"""Die geometry shared by the SVG and PNG renderers so that every die in the app is drawn identically.

A die lives in a 120 x 120 box and fills it edge to edge, so rings and clips drawn by Flutter with an 18 %
radius line up with the artwork. Layers, bottom to top: shade (the visible bottom thickness), edge, face, pips.
"""

from dataclasses import dataclass

from . import palette
from .svg_kit import circle, group, num, path, place, rect, stroke

BOX = 120
RADIUS = 21.6
SHADE = 6
EDGE = 2
PIP_RADIUS = 9.5
ONE_PIP_RADIUS = 12.5
PIP_STEP = 27

FACE_HEIGHT = BOX - SHADE
CENTRE = (BOX / 2, FACE_HEIGHT / 2)

# Pip positions as (column, row) on a 3 x 3 grid.
PIP_GRID = {
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)],
}


@dataclass(frozen=True)
class Material:
    face: str
    edge: str
    shade: str
    pip: str
    one_pip: str


IVORY = Material(palette.DIE_FACE, palette.DIE_EDGE, palette.DIE_EDGE, palette.PIP, palette.PIP_RED)
GOLDEN = Material(palette.GOLD, palette.GOLD_DARK, palette.GOLD_DARK, palette.PIP, palette.PIP)


def pips(value: int, material: Material) -> list[tuple[float, float, float, str]]:
    """Pips of a face as (x, y, radius, colour); the single pip is larger and red on ivory dice."""
    if value == 1:
        return [(*CENTRE, ONE_PIP_RADIUS, material.one_pip)]
    return [
        (CENTRE[0] + (col - 1) * PIP_STEP, CENTRE[1] + (row - 1) * PIP_STEP, PIP_RADIUS, material.pip)
        for col, row in PIP_GRID[value]
    ]


def body_shapes(material: Material) -> list[str]:
    shapes = [rect(0, 0, BOX, BOX, rx=RADIUS, fill=material.shade)]
    if material.edge != material.shade:
        shapes.append(rect(0, 0, BOX, FACE_HEIGHT, rx=RADIUS, fill=material.edge))
    shapes.append(rect(EDGE, EDGE, BOX - 2 * EDGE, FACE_HEIGHT - 2 * EDGE, rx=RADIUS - EDGE, fill=material.face))
    return shapes


def face_shapes(value: int, material: Material = IVORY) -> list[str]:
    return body_shapes(material) + [circle(x, y, r, fill=color) for x, y, r, color in pips(value, material)]


def _diamond(radius: float) -> str:
    cx, cy = CENTRE
    return f"M{num(cx)} {num(cy - radius)}L{num(cx + radius)} {num(cy)}L{num(cx)} {num(cy + radius)}L{num(cx - radius)} {num(cy)}Z"


def hidden_shapes() -> list[str]:
    """Face-down die: emerald body, light rim and inner border, diamond emblem, no text.

    The rim keeps the silhouette readable on the green felt, where the body alone would melt into the table.
    """
    light = palette.PRIMARY_LIGHT
    return [
        rect(0, 0, BOX, BOX, rx=RADIUS, fill=palette.PRIMARY_DARK),
        rect(0, 0, BOX, FACE_HEIGHT, rx=RADIUS, fill=palette.PRIMARY),
        rect(1.5, 1.5, BOX - 3, FACE_HEIGHT - 3, rx=RADIUS - 1.5, fill="none", stroke=light, stroke_width=3, opacity=0.9),
        rect(15, 15, BOX - 30, FACE_HEIGHT - 30, rx=11, fill="none", stroke=light, stroke_width=2, opacity=0.6),
        path(_diamond(24), **stroke(light, 4, fill=light)),
        path(_diamond(10), fill=palette.PRIMARY),
    ]


def placed(shapes: list[str], cx: float, cy: float, size: float, angle: float = 0) -> str:
    """The die drawn centred on (cx, cy) with the given side length and clockwise tilt in degrees."""
    return group(shapes, transform=place(cx, cy, angle, size / BOX, (BOX / 2, BOX / 2)))
