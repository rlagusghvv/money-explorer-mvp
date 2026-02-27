#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from typing import Dict

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "assets/minimi/generated"
NORM_DIR = ROOT / "assets/minimi/normalized"
TPL_DIR = ROOT / "assets/minimi/template"
ART_DIR = ROOT / "artifacts/minimi_alignment_samples"
DOC_PATH = ROOT / "docs/r51_top_template.md"

NORM_SIZE = 512
TOP_IDS = [
    "top_green_hoodie",
    "top_blue_jersey",
    "top_orange_knit",
    "top_purple_zipup",
    "top_white_shirt",
]

OLD_CANVAS = (160.0, 242.0)
SCALE = NORM_SIZE / OLD_CANVAS[1]
X_CENTER_OLD = OLD_CANVAS[0] / 2.0
X_CENTER_NEW = NORM_SIZE / 2.0
TOP_STYLE_SIZE = (146.0, 110.0)
TOP_STYLE_ANCHOR = (0.5, 0.63)


def old_to_new(x_old: float, y_old: float) -> tuple[float, float]:
    x_new = ((x_old - X_CENTER_OLD) * SCALE) + X_CENTER_NEW
    y_new = y_old * SCALE
    return x_new, y_new


def normalize_from_generated(path: Path) -> Image.Image:
    src = Image.open(path).convert("RGBA")
    target_w = max(1, int(round(TOP_STYLE_SIZE[0] * SCALE)))
    target_h = max(1, int(round(TOP_STYLE_SIZE[1] * SCALE)))
    layer = src.resize((target_w, target_h), Image.Resampling.LANCZOS)

    anchor_old = (OLD_CANVAS[0] * TOP_STYLE_ANCHOR[0], OLD_CANVAS[1] * TOP_STYLE_ANCHOR[1])
    anchor_new = old_to_new(*anchor_old)
    left = int(round(anchor_new[0] - (target_w / 2.0)))
    top = int(round(anchor_new[1] - (target_h / 2.0)))

    out = Image.new("RGBA", (NORM_SIZE, NORM_SIZE), (0, 0, 0, 0))
    out.alpha_composite(layer, dest=(left, top))
    return out


def build_torso_template(base_body: Image.Image) -> Image.Image:
    alpha = base_body.split()[-1]
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("base_body alpha is empty")

    l, t, r, b = bbox
    w = r - l
    h = b - t

    torso_rect = (
        int(l + w * 0.06),
        int(t + h * 0.40),
        int(r - w * 0.06),
        int(t + h * 0.86),
    )

    template_alpha = Image.new("L", (NORM_SIZE, NORM_SIZE), 0)
    draw = ImageDraw.Draw(template_alpha)
    draw.rounded_rectangle(torso_rect, radius=28, fill=255)

    # body 영역 밖은 제거해서 "body 기준 torso 템플릿"으로 고정
    template_alpha = Image.composite(template_alpha, Image.new("L", (NORM_SIZE, NORM_SIZE), 0), alpha)

    template = Image.new("RGBA", (NORM_SIZE, NORM_SIZE), (0, 0, 0, 0))
    template.putalpha(template_alpha)
    return template


def retarget_to_template(top_img: Image.Image, template: Image.Image) -> Image.Image:
    top_alpha = top_img.split()[-1]
    ta = template.split()[-1]
    b_top = top_alpha.getbbox()
    b_tpl = ta.getbbox()
    if b_top is None or b_tpl is None:
        return top_img

    bw, bh = b_top[2] - b_top[0], b_top[3] - b_top[1]
    tw, th = b_tpl[2] - b_tpl[0], b_tpl[3] - b_tpl[1]

    scale = min((tw * 0.97) / max(1, bw), (th * 0.93) / max(1, bh))

    resized = top_img.resize(
        (max(1, int(round(NORM_SIZE * scale))), max(1, int(round(NORM_SIZE * scale)))),
        Image.Resampling.LANCZOS,
    )
    ra = resized.split()[-1]
    rb = ra.getbbox()
    if rb is None:
        return top_img

    # torso 템플릿 중앙 + 목선 여유(상단 +6px)
    target_cx = (b_tpl[0] + b_tpl[2]) // 2
    target_top = b_tpl[1] + 6

    offset_x = int(round(target_cx - (rb[0] + rb[2]) / 2))
    offset_y = int(round(target_top - rb[1]))

    out = Image.new("RGBA", (NORM_SIZE, NORM_SIZE), (0, 0, 0, 0))
    out.alpha_composite(resized, dest=(offset_x, offset_y))

    # template 내부로 강제 클리핑
    out_arr = out.split()
    clipped_alpha = ImageChops.multiply(out_arr[-1], ta)
    out.putalpha(clipped_alpha)
    return out


def render_character(top_id: str, hair_id: str = "hair_basic_black") -> Image.Image:
    base = Image.open(NORM_DIR / "base_body.png").convert("RGBA")
    hair = Image.open(NORM_DIR / f"{hair_id}.png").convert("RGBA")
    top = Image.open(NORM_DIR / f"{top_id}.png").convert("RGBA")

    canvas = Image.new("RGBA", (NORM_SIZE, NORM_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(base)
    canvas.alpha_composite(top)
    canvas.alpha_composite(hair)
    return canvas


def save_before_after(before: Dict[str, Image.Image]) -> Path:
    ART_DIR.mkdir(parents=True, exist_ok=True)
    cell_w, cell_h = 220, 220
    pad = 20
    label_h = 30
    rows = len(TOP_IDS)
    width = pad * 4 + cell_w * 2
    height = pad * (rows + 1) + rows * (cell_h + label_h)
    sheet = Image.new("RGBA", (width, height), (248, 250, 255, 255))
    d = ImageDraw.Draw(sheet)

    for i, top_id in enumerate(TOP_IDS):
        y = pad + i * (cell_h + label_h + pad)
        d.text((pad, y), top_id.replace("top_", ""), fill=(40, 48, 60, 255))

        b = before[top_id].resize((cell_w, cell_h), Image.Resampling.LANCZOS)
        a = render_character(top_id).resize((cell_w, cell_h), Image.Resampling.LANCZOS)

        bx = pad
        ax = pad * 3 + cell_w
        by = y + label_h
        d.rectangle((bx - 1, by - 1, bx + cell_w + 1, by + cell_h + 1), outline=(210, 218, 235, 255), width=2)
        d.rectangle((ax - 1, by - 1, ax + cell_w + 1, by + cell_h + 1), outline=(160, 198, 160, 255), width=2)
        d.text((bx + 6, by + 6), "before", fill=(90, 95, 110, 255))
        d.text((ax + 6, by + 6), "after", fill=(48, 112, 63, 255))
        sheet.alpha_composite(b, dest=(bx, by))
        sheet.alpha_composite(a, dest=(ax, by))

    out = ART_DIR / "r51_top_before_after.png"
    sheet.save(out)
    return out


def save_preview() -> Path:
    ART_DIR.mkdir(parents=True, exist_ok=True)
    cell = 220
    pad = 20
    label_h = 28
    cols = len(TOP_IDS)
    width = pad * (cols + 1) + cell * cols
    height = pad * 2 + label_h + cell
    sheet = Image.new("RGBA", (width, height), (255, 255, 255, 255))
    d = ImageDraw.Draw(sheet)

    for i, top_id in enumerate(TOP_IDS):
        x = pad + i * (cell + pad)
        y = pad
        d.text((x, y), top_id.replace("top_", ""), fill=(50, 56, 68, 255))
        preview = render_character(top_id).resize((cell, cell), Image.Resampling.LANCZOS)
        sheet.alpha_composite(preview, dest=(x, y + label_h))

    out = ART_DIR / "r51_top_preview.png"
    sheet.save(out)
    return out


def write_doc(template_bbox: tuple[int, int, int, int], tops: list[str]) -> None:
    DOC_PATH.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# r51 상의 템플릿 재생성",
        "",
        "- 기준: `assets/minimi/normalized/base_body.png` 알파 실루엣에서 torso 영역만 추출",
        "- 템플릿: `assets/minimi/template/top_torso_template.png`",
        "- 방법: torso 라운드 마스크 내부에 top 파츠를 리타겟(중심 정렬 + 목선 기준 상단 고정) 후 템플릿 외부는 클리핑",
        f"- 템플릿 bbox(512 기준): `{template_bbox}`",
        f"- 교체 대상(top 5): {', '.join(tops)}",
    ]
    DOC_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    from PIL import ImageChops

    base = Image.open(NORM_DIR / "base_body.png").convert("RGBA")
    template = build_torso_template(base)
    ta = template.split()[-1]
    tpl_bbox = ta.getbbox()

    TPL_DIR.mkdir(parents=True, exist_ok=True)
    template_path = TPL_DIR / "top_torso_template.png"
    template.save(template_path)

    before = {}
    for top_id in TOP_IDS:
        before[top_id] = render_character(top_id)

    for top_id in TOP_IDS:
        src = SRC_DIR / f"{top_id}.png"
        norm = normalize_from_generated(src)
        # local scope ImageChops import
        top_alpha = norm.split()[-1]
        clipped_alpha = ImageChops.multiply(top_alpha, ta)
        norm.putalpha(clipped_alpha)

        b = norm.split()[-1].getbbox()
        if b and tpl_bbox:
            bw, bh = b[2] - b[0], b[3] - b[1]
            tw, th = tpl_bbox[2] - tpl_bbox[0], tpl_bbox[3] - tpl_bbox[1]
            scale = min((tw * 0.97) / max(1, bw), (th * 0.93) / max(1, bh))
            resized = norm.resize((max(1, int(round(NORM_SIZE * scale))), max(1, int(round(NORM_SIZE * scale)))), Image.Resampling.LANCZOS)
            rb = resized.split()[-1].getbbox()
            if rb:
                target_cx = (tpl_bbox[0] + tpl_bbox[2]) // 2
                target_top = tpl_bbox[1] + 6
                ox = int(round(target_cx - (rb[0] + rb[2]) / 2))
                oy = int(round(target_top - rb[1]))
                out = Image.new("RGBA", (NORM_SIZE, NORM_SIZE), (0, 0, 0, 0))
                out.alpha_composite(resized, dest=(ox, oy))
                final_alpha = ImageChops.multiply(out.split()[-1], ta)
                out.putalpha(final_alpha)
                norm = out

        norm.save(NORM_DIR / f"{top_id}.png")

    before_after = save_before_after(before)
    preview = save_preview()
    write_doc(tpl_bbox if tpl_bbox else (0, 0, 0, 0), TOP_IDS)

    print(f"template: {template_path}")
    print(f"before_after: {before_after}")
    print(f"preview: {preview}")
    print(f"doc: {DOC_PATH}")


if __name__ == "__main__":
    main()
