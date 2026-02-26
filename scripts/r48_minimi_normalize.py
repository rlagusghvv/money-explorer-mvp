#!/usr/bin/env python3
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "assets/minimi/generated"
OUT_DIR = ROOT / "assets/minimi/normalized"
DOCS_DIR = ROOT / "docs"

OLD_CANVAS = (160.0, 242.0)
NORM_SIZE = 512
SCALE = NORM_SIZE / OLD_CANVAS[1]
X_CENTER_OLD = OLD_CANVAS[0] / 2.0
X_CENTER_NEW = NORM_SIZE / 2.0


@dataclass(frozen=True)
class LegacyStyle:
    size: Tuple[float, float]
    anchor: Tuple[float, float]
    z: int


BODY_STYLE = LegacyStyle((154, 242), (0.5, 0.5), 1)
HAIR_STYLE = LegacyStyle((132, 94), (0.5, 0.23), 3)
TOP_STYLE = LegacyStyle((146, 110), (0.5, 0.63), 2)
ACC_STYLE_DEFAULT = LegacyStyle((128, 84), (0.5, 0.23), 4)
ACC_STYLE_BY_ID: Dict[str, LegacyStyle] = {
    "acc_cap": LegacyStyle((117, 87), (0.5, 0.17), 4),
    "acc_headphone": LegacyStyle((141, 87), (0.5, 0.23), 4),
    "acc_glass": LegacyStyle((139, 52), (0.5, 0.245), 5),
    "acc_round_glass": LegacyStyle((138, 62), (0.5, 0.245), 5),
    "acc_star_pin": LegacyStyle((105, 107), (0.62, 0.61), 5),
}


def style_for(name: str) -> LegacyStyle:
    if name == "base_body":
        return BODY_STYLE
    if name.startswith("hair_"):
        return HAIR_STYLE
    if name.startswith("top_"):
        return TOP_STYLE
    if name.startswith("acc_"):
        return ACC_STYLE_BY_ID.get(name, ACC_STYLE_DEFAULT)
    raise ValueError(f"Unknown part category: {name}")


def old_to_new(x_old: float, y_old: float) -> Tuple[float, float]:
    x_new = ((x_old - X_CENTER_OLD) * SCALE) + X_CENTER_NEW
    y_new = y_old * SCALE
    return x_new, y_new


def normalize_one(path: Path) -> Path:
    name = path.stem
    style = style_for(name)

    src = Image.open(path).convert("RGBA")
    target_w = max(1, int(round(style.size[0] * SCALE)))
    target_h = max(1, int(round(style.size[1] * SCALE)))
    layer = src.resize((target_w, target_h), Image.Resampling.LANCZOS)

    anchor_old = (OLD_CANVAS[0] * style.anchor[0], OLD_CANVAS[1] * style.anchor[1])
    anchor_new = old_to_new(*anchor_old)

    left = int(round(anchor_new[0] - (target_w / 2.0)))
    top = int(round(anchor_new[1] - (target_h / 2.0)))

    out = Image.new("RGBA", (NORM_SIZE, NORM_SIZE), (0, 0, 0, 0))
    out.alpha_composite(layer, dest=(left, top))

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out_path = OUT_DIR / path.name
    out.save(out_path)
    return out_path


def render_preview(hair: str, top: str, acc: str) -> Image.Image:
    canvas = Image.new("RGBA", (NORM_SIZE, NORM_SIZE), (0, 0, 0, 0))
    layers = ["base_body", hair, top]
    if acc != "acc_none":
        layers.append(acc)

    # z-order: body < top < hair < accessory
    def key(name: str) -> int:
        return style_for(name).z

    for name in sorted(layers, key=key):
        p = OUT_DIR / f"{name}.png"
        if p.exists():
            canvas.alpha_composite(Image.open(p).convert("RGBA"))
    return canvas


def build_preview_grid() -> Path:
    hairs = [
        "hair_basic_black",
        "hair_brown_wave",
        "hair_pink_bob",
        "hair_blue_short",
        "hair_blonde",
    ]
    tops = [
        "top_green_hoodie",
        "top_blue_jersey",
        "top_orange_knit",
        "top_purple_zipup",
        "top_white_shirt",
    ]
    accs = ["acc_none", "acc_cap", "acc_glass", "acc_headphone", "acc_star_pin"]

    combos = [(hairs[i], tops[i], accs[i]) for i in range(5)]

    cell = 280
    pad = 24
    label_h = 44
    cols = 5
    width = (cols * cell) + ((cols + 1) * pad)
    height = pad + label_h + cell + pad
    sheet = Image.new("RGBA", (width, height), (249, 251, 255, 255))
    draw = ImageDraw.Draw(sheet)

    for i, (hair, top, acc) in enumerate(combos):
        x = pad + i * (cell + pad)
        y = pad
        draw.rounded_rectangle((x, y, x + cell, y + label_h + cell), radius=16, fill=(255, 255, 255, 255), outline=(222, 227, 239, 255), width=2)
        label = f"{hair.replace('hair_', '')} / {top.replace('top_', '')} / {acc.replace('acc_', '')}"
        draw.text((x + 10, y + 12), label, fill=(52, 59, 74, 255))
        preview = render_preview(hair, top, acc).resize((cell - 24, cell - 24), Image.Resampling.LANCZOS)
        sheet.alpha_composite(preview, dest=(x + 12, y + label_h + 12))

    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    out_path = DOCS_DIR / "r48_minimi_preview_grid.png"
    sheet.save(out_path)
    return out_path


def main() -> None:
    candidates = sorted(SRC_DIR.glob("*.png"))
    for path in candidates:
        try:
            style_for(path.stem)
        except ValueError:
            continue
        normalize_one(path)
    grid = build_preview_grid()
    print(f"normalized: {OUT_DIR}")
    print(f"preview: {grid}")


if __name__ == "__main__":
    main()
