"""Generates every image asset of FunDice (SPEC section 7) from code, so the whole set stays consistent.

    python tools/generate_assets.py

Requires Python 3 and Pillow. The output goes to assets/images (SVG) and assets/app_icon (PNG).
"""

from pathlib import Path

from fundice_art import dice, illustrations
from fundice_art.svg_kit import document

ROOT = Path(__file__).resolve().parent.parent
IMAGES = ROOT / "assets" / "images"


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def write_dice() -> None:
    for value in range(1, 7):
        write(IMAGES / "dice" / f"die_{value}.svg", document(dice.BOX, dice.BOX, dice.face_shapes(value)))
    write(IMAGES / "dice" / "die_hidden.svg", document(dice.BOX, dice.BOX, dice.hidden_shapes()))


def write_illustrations() -> None:
    write(IMAGES / "logo.svg", illustrations.logo())
    for name in ("welcome", "searching", "trophy", "defeat", "offline"):
        write(IMAGES / "illustrations" / f"{name}.svg", getattr(illustrations, name)())


def main() -> None:
    write_dice()
    write_illustrations()


if __name__ == "__main__":
    main()
