#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets/minimi/normalized"
OUT = ROOT / "docs/r49_minimi_preview_grid.png"

CANVAS = 512
CATEGORY_OFFSET = {
    "hair": (0.0, -1.0),
    "top": (0.0, 0.5),
    "accessory": (0.0, 0.0),
}
ITEM_OFFSET = {
    "acc_glass": (0.0, -0.5),
    "acc_star_pin": (0.2, 0.0),
}

Z = {
    "base_body": 1,
    "top_green_hoodie": 2,
    "top_blue_jersey": 2,
    "top_orange_knit": 2,
    "top_purple_zipup": 2,
    "top_white_shirt": 2,
    "hair_basic_black": 3,
    "hair_brown_wave": 3,
    "hair_pink_bob": 3,
    "hair_blue_short": 3,
    "hair_blonde": 3,
    "acc_cap": 4,
    "acc_headphone": 4,
    "acc_glass": 5,
    "acc_star_pin": 5,
}

COMBOS = [
    ("hair_basic_black", "top_green_hoodie", "acc_none"),
    ("hair_brown_wave", "top_blue_jersey", "acc_cap"),
    ("hair_pink_bob", "top_orange_knit", "acc_glass"),
    ("hair_blue_short", "top_purple_zipup", "acc_headphone"),
    ("hair_blonde", "top_white_shirt", "acc_star_pin"),
    ("hair_basic_black", "top_white_shirt", "acc_glass"),
    ("hair_blonde", "top_green_hoodie", "acc_cap"),
    ("hair_pink_bob", "top_blue_jersey", "acc_none"),
    ("hair_brown_wave", "top_orange_knit", "acc_star_pin"),
]


def offset_of(category: str, item: str) -> tuple[int, int]:
    cx, cy = CATEGORY_OFFSET.get(category, (0.0, 0.0))
    ix, iy = ITEM_OFFSET.get(item, (0.0, 0.0))
    return int(round(cx + ix)), int(round(cy + iy))


def compose(hair: str, top: str, acc: str) -> Image.Image:
    layers = [("base", "base_body"), ("top", top), ("hair", hair)]
    if acc != "acc_none":
        layers.append(("accessory", acc))
    layers.sort(key=lambda x: Z.get(x[1], 99))

    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    for category, name in layers:
        p = ASSET_DIR / f"{name}.png"
        if not p.exists():
            continue
        layer = Image.open(p).convert("RGBA")
        dx, dy = offset_of(category, name)
        out.alpha_composite(layer, dest=(dx, dy))
    return out


def main() -> None:
    cell = 300
    cols = 3
    rows = 3
    pad = 20
    label_h = 38
    width = pad + cols * (cell + pad)
    height = pad + rows * (cell + label_h + pad)
    sheet = Image.new("RGBA", (width, height), (247, 250, 255, 255))
    draw = ImageDraw.Draw(sheet)

    for i, (hair, top, acc) in enumerate(COMBOS):
        c = i % cols
        r = i // cols
        x = pad + c * (cell + pad)
        y = pad + r * (cell + label_h + pad)
        draw.rounded_rectangle((x, y, x + cell, y + label_h + cell), radius=16, fill=(255, 255, 255, 255), outline=(220, 228, 240, 255), width=2)
        label = f"{hair.replace('hair_', '')}/{top.replace('top_', '')}/{acc.replace('acc_', '')}"
        draw.text((x + 10, y + 11), label, fill=(44, 56, 74, 255))
        preview = compose(hair, top, acc).resize((cell - 22, cell - 22), Image.Resampling.LANCZOS)
        sheet.alpha_composite(preview, (x + 11, y + label_h + 11))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
