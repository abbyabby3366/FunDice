"""Minimal SVG writer.

Only plain shapes, paths, groups and transforms are emitted. That is the subset flutter_svg renders
reliably: no filters, masks, CSS or fonts.
"""

import math

Point = tuple[float, float]


def num(value: float) -> str:
    """Compact number: at most two decimals, no trailing zeros."""
    text = f"{value:.2f}".rstrip("0").rstrip(".")
    return "0" if text in ("", "-0") else text


def _attrs(attrs: dict) -> str:
    parts = []
    for key, value in attrs.items():
        if value is None:
            continue
        text = num(value) if isinstance(value, (int, float)) else str(value)
        parts.append(f'{key.replace("_", "-")}="{text}"')
    return " ".join(parts)


def _element(tag: str, **attrs) -> str:
    return f"<{tag} {_attrs(attrs)}/>"


def stroke(color: str, width: float, fill: str = "none") -> dict:
    """Rounded outline style; unpack into a shape: `path(d, **stroke(GOLD, 4))`."""
    return {
        "fill": fill,
        "stroke": color,
        "stroke_width": width,
        "stroke_linecap": "round",
        "stroke_linejoin": "round",
    }


def rect(x: float, y: float, width: float, height: float, rx: float | None = None, **style) -> str:
    return _element("rect", x=x, y=y, width=width, height=height, rx=rx, **style)


def circle(cx: float, cy: float, r: float, **style) -> str:
    return _element("circle", cx=cx, cy=cy, r=r, **style)


def ellipse(cx: float, cy: float, rx: float, ry: float, **style) -> str:
    return _element("ellipse", cx=cx, cy=cy, rx=rx, ry=ry, **style)


def path(d: str, **style) -> str:
    return _element("path", d=d, **style)


def line(x1: float, y1: float, x2: float, y2: float, **style) -> str:
    return _element("line", x1=x1, y1=y1, x2=x2, y2=y2, **style)


def group(children: list[str], **attrs) -> str:
    return f"<g {_attrs(attrs)}>" + "".join(children) + "</g>"


def place(cx: float, cy: float, angle: float = 0, scale: float = 1, pivot: Point = (0, 0)) -> str:
    """Transform that moves the local `pivot` to (cx, cy) after scaling and rotating around it."""
    return (
        f"translate({num(cx)} {num(cy)}) rotate({num(angle)}) scale({num(scale)}) "
        f"translate({num(-pivot[0])} {num(-pivot[1])})"
    )


def document(width: int, height: int, children: list[str]) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" '
        f'viewBox="0 0 {width} {height}">\n' + "\n".join(children) + "\n</svg>\n"
    )


def _fmt(point: Point) -> str:
    return f"{num(point[0])} {num(point[1])}"


def sparkle_path(cx: float, cy: float, r: float, pinch: float = 0.16) -> str:
    """Four-pointed star with softly concave sides; `pinch` moves the side control points off the centre."""
    c = r * pinch
    top, right, bottom, left = (cx, cy - r), (cx + r, cy), (cx, cy + r), (cx - r, cy)
    return (
        f"M{_fmt(top)}Q{_fmt((cx + c, cy - c))} {_fmt(right)}"
        f"Q{_fmt((cx + c, cy + c))} {_fmt(bottom)}"
        f"Q{_fmt((cx - c, cy + c))} {_fmt(left)}"
        f"Q{_fmt((cx - c, cy - c))} {_fmt(top)}Z"
    )


def sparkle(cx: float, cy: float, r: float, color: str, **style) -> str:
    return path(sparkle_path(cx, cy, r), fill=color, **style)


def star(cx: float, cy: float, r: float, color: str, inner: float = 0.5, tilt: float = 0) -> str:
    """Five-pointed star; the outline in the fill colour rounds the tips to keep the style friendly."""
    points = []
    for i in range(10):
        radius = r if i % 2 == 0 else r * inner
        angle = math.radians(-90 + tilt + i * 36)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    d = "M" + "L".join(_fmt(p) for p in points) + "Z"
    return path(d, fill=color, stroke=color, stroke_width=r * 0.22, stroke_linejoin="round")


def plus(cx: float, cy: float, size: float, color: str, width: float = 3) -> str:
    half = size / 2
    d = f"M{_fmt((cx - half, cy))}L{_fmt((cx + half, cy))}M{_fmt((cx, cy - half))}L{_fmt((cx, cy + half))}"
    return path(d, **stroke(color, width))


def pebble(top: Point, right: Point, bottom: Point, left: Point, roundness: float = 0.6) -> str:
    """Soft organic outline through four anchor points, with axis-aligned handles (0.55 = ellipse, 0.65 = rounder)."""
    (tx, ty), (rx, ry), (bx, by), (lx, ly) = top, right, bottom, left
    k = roundness
    return (
        f"M{_fmt(top)}"
        f"C{_fmt((tx + k * (rx - tx), ty))} {_fmt((rx, ry - k * (ry - ty)))} {_fmt(right)}"
        f"C{_fmt((rx, ry + k * (by - ry)))} {_fmt((bx + k * (rx - bx), by))} {_fmt(bottom)}"
        f"C{_fmt((bx - k * (bx - lx), by))} {_fmt((lx, ly + k * (by - ly)))} {_fmt(left)}"
        f"C{_fmt((lx, ly - k * (ly - ty)))} {_fmt((tx - k * (tx - lx), ty))} {_fmt(top)}Z"
    )
