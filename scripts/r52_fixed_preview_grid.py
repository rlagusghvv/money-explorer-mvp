#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets/minimi/normalized"
OUT = ROOT / "artifacts/minimi_alignment_samples/r52_fixed_preview_grid.png"

CANVAS = 512
PREVIEW = 184
TOP_CLIP_BOTTOM_Y = 442

ANCHOR_BY_ID = {
    "base_body": (256, 256),
    "hair_basic_black": (256, 164),
    "hair_brown_wave": (256, 164),
    "hair_pink_bob": (256, 164),
    "hair_blue_short": (256, 164),
    "hair_blonde": (256, 164),
    "top_green_hoodie": (256, 258),
    "top_blue_jersey": (256, 258),
    "top_orange_knit": (256, 258),
    "top_purple_zipup": (256, 258),
    "top_white_shirt": (256, 258),
    "acc_cap": (256, 182),
    "acc_headphone": (256, 182),
    "acc_glass": (256, 206),
    "acc_star_pin": (256, 206),
}

TARGET_BY_CATEGORY = {
    "hair": (256, 164),
    "top": (256, 258),
    "accessory": (256, 206),
}

SCALE_BY_ID = {
    "base_body": 1.0,
    "hair_basic_black": 1.03,
    "hair_brown_wave": 1.03,
    "hair_pink_bob": 1.03,
    "hair_blue_short": 1.03,
    "hair_blonde": 1.03,
    "top_green_hoodie": 1.0,
    "top_blue_jersey": 1.0,
    "top_orange_knit": 1.0,
    "top_purple_zipup": 1.0,
    "top_white_shirt": 1.0,
    "acc_cap": 1.0,
    "acc_headphone": 1.0,
    "acc_glass": 1.0,
    "acc_star_pin": 1.0,
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


def offset_of(category: str, item_id: str) -> tuple[int, int]:
    tx, ty = TARGET_BY_CATEGORY[category]
    ix, iy = ANCHOR_BY_ID[item_id]
    return tx - ix, ty - iy


def with_top_clip(layer: Image.Image) -> Image.Image:
    alpha = layer.split()[-1]
    clip = Image.new("L", (CANVAS, CANVAS), 0)
    ImageDraw.Draw(clip).rectangle((0, 0, CANVAS, TOP_CLIP_BOTTOM_Y), fill=255)
    alpha = ImageChops.multiply(alpha, clip)
    out = layer.copy()
    out.putalpha(alpha)
    return out


def transformed(layer: Image.Image, scale: float) -> Image.Image:
    if abs(scale - 1.0) < 1e-6:
        return layer
    w, h = layer.size
    nw = max(1, int(round(w * scale)))
    nh = max(1, int(round(h * scale)))
    resized = layer.resize((nw, nh), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(resized, dest=((w - nw) // 2, (h - nh) // 2))
    return out


def compose(hair: str, top: str, acc: str) -> Image.Image:
    layers = [(None, "base_body"), ("top", top), ("hair", hair)]
    if acc != "acc_none":
        layers.append(("accessory", acc))
    layers.sort(key=lambda x: Z.get(x[1], 99))

    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    for category, item_id in layers:
        p = ASSET_DIR / f"{item_id}.png"
        if not p.exists():
            continue
        layer = Image.open(p).convert("RGBA")
        layer = transformed(layer, SCALE_BY_ID.get(item_id, 1.0))
        if category == "top":
            layer = with_top_clip(layer)
        dx, dy = (0, 0) if category is None else offset_of(category, item_id)
        out.alpha_composite(layer, dest=(dx, dy))
    return out


def main() -> None:
    cols, rows = 3, 3
    pad = 20
    card_w, card_h = 260, 310
    label_h = 42
    width = pad + cols * (card_w + pad)
    height = pad + rows * (card_h + pad)
    sheet = Image.new("RGBA", (width, height), (246, 250, 255, 255))
    d = ImageDraw.Draw(sheet)

    for i, (hair, top, acc) in enumerate(COMBOS):
        c, r = i % cols, i // cols
        x = pad + c * (card_w + pad)
        y = pad + r * (card_h + pad)
        d.rounded_rectangle((x, y, x + card_w, y + card_h), radius=18, fill=(255, 255, 255, 255), outline=(214, 224, 238, 255), width=2)
        label = f"{hair.replace('hair_', '')} / {top.replace('top_', '')} / {acc.replace('acc_', '')}"
        d.text((x + 10, y + 12), label, fill=(45, 58, 77, 255))

        comp = compose(hair, top, acc).resize((PREVIEW, PREVIEW), Image.Resampling.LANCZOS)
        sheet.alpha_composite(comp, dest=(x + (card_w - PREVIEW) // 2, y + label_h + 28))

        clip_y = int(round((TOP_CLIP_BOTTOM_Y / CANVAS) * PREVIEW))
        px = x + (card_w - PREVIEW) // 2
        py = y + label_h + 28
        d.line((px, py + clip_y, px + PREVIEW, py + clip_y), fill=(70, 190, 90, 180), width=2)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUT)
    print(OUT)


if __name__ == "__main__":
    main()
