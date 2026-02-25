#!/usr/bin/env python3
"""
Robust item-sheet slicer for variable layouts.
- Finds object clusters from a near-white background sheet
- Filters out text fragments/small noise
- Removes only border-connected background to keep inner whites
- Exports transparent 512x512 PNGs

Usage:
  python scripts/slice_item_sheet.py \
    --input /path/to/sheet.jpg \
    --out assets/miniroom/generated/raw \
    --prefix item_auto
"""

from __future__ import annotations
from dataclasses import dataclass
from pathlib import Path
from collections import deque
import argparse
import numpy as np
from PIL import Image


@dataclass
class Box:
    x1: int
    y1: int
    x2: int
    y2: int
    area: int

    @property
    def w(self) -> int:
        return self.x2 - self.x1 + 1

    @property
    def h(self) -> int:
        return self.y2 - self.y1 + 1


def connected_components(mask: np.ndarray, min_area: int) -> list[Box]:
    h, w = mask.shape
    vis = np.zeros_like(mask, dtype=bool)
    out: list[Box] = []
    for y in range(h):
        for x in range(w):
            if vis[y, x] or not mask[y, x]:
                continue
            q = deque([(y, x)])
            vis[y, x] = True
            minx = maxx = x
            miny = maxy = y
            area = 0
            while q:
                cy, cx = q.popleft()
                area += 1
                if cx < minx:
                    minx = cx
                if cx > maxx:
                    maxx = cx
                if cy < miny:
                    miny = cy
                if cy > maxy:
                    maxy = cy
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not vis[ny, nx]:
                        vis[ny, nx] = True
                        q.append((ny, nx))
            if area >= min_area:
                out.append(Box(minx, miny, maxx, maxy, area))
    return out


def merge_boxes(boxes: list[Box], gap: int = 10) -> list[Box]:
    # simple iterative merge on expanded intersection (for broken object parts)
    merged = boxes[:]
    changed = True
    while changed:
        changed = False
        nxt: list[Box] = []
        used = [False] * len(merged)
        for i, a in enumerate(merged):
            if used[i]:
                continue
            bx1, by1, bx2, by2, area = a.x1, a.y1, a.x2, a.y2, a.area
            used[i] = True
            for j, b in enumerate(merged):
                if used[j]:
                    continue
                ax1, ay1, ax2, ay2 = bx1 - gap, by1 - gap, bx2 + gap, by2 + gap
                if not (b.x2 < ax1 or b.x1 > ax2 or b.y2 < ay1 or b.y1 > ay2):
                    bx1 = min(bx1, b.x1)
                    by1 = min(by1, b.y1)
                    bx2 = max(bx2, b.x2)
                    by2 = max(by2, b.y2)
                    area += b.area
                    used[j] = True
                    changed = True
            nxt.append(Box(bx1, by1, bx2, by2, area))
        merged = nxt
    return merged


def remove_border_bg(rgba: Image.Image, threshold: int = 236) -> Image.Image:
    arr = np.array(rgba)
    rgb = arr[:, :, :3]
    alpha = arr[:, :, 3]
    h, w = alpha.shape

    bg = (rgb[:, :, 0] > threshold) & (rgb[:, :, 1] > threshold) & (rgb[:, :, 2] > threshold)
    vis = np.zeros((h, w), dtype=bool)
    q = deque()

    for x in range(w):
        if bg[0, x]:
            vis[0, x] = True
            q.append((0, x))
        if bg[h - 1, x] and not vis[h - 1, x]:
            vis[h - 1, x] = True
            q.append((h - 1, x))
    for y in range(h):
        if bg[y, 0] and not vis[y, 0]:
            vis[y, 0] = True
            q.append((y, 0))
        if bg[y, w - 1] and not vis[y, w - 1]:
            vis[y, w - 1] = True
            q.append((y, w - 1))

    while q:
        y, x = q.popleft()
        for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= ny < h and 0 <= nx < w and bg[ny, nx] and not vis[ny, nx]:
                vis[ny, nx] = True
                q.append((ny, nx))

    arr[vis, 3] = 0
    return Image.fromarray(arr, mode="RGBA")


def normalize_to_canvas(img: Image.Image, canvas: int = 512, content: int = 440) -> Image.Image:
    bbox = img.getbbox()
    if bbox:
        x1, y1, x2, y2 = bbox
        pad = 6
        img = img.crop((max(0, x1 - pad), max(0, y1 - pad), min(img.width, x2 + pad), min(img.height, y2 + pad)))
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    img.thumbnail((content, content), Image.Resampling.LANCZOS)
    ox = (canvas - img.width) // 2
    oy = (canvas - img.height) // 2
    out.paste(img, (ox, oy), img)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--prefix", default="item_auto")
    ap.add_argument("--min-area", type=int, default=700)
    ap.add_argument("--min-w", type=int, default=40)
    ap.add_argument("--min-h", type=int, default=40)
    args = ap.parse_args()

    src = Image.open(args.input).convert("RGB")
    arr = np.array(src)
    # foreground mask: anything not near-white
    mask = np.any(arr < 240, axis=2)

    comps = connected_components(mask, min_area=args.min_area)
    comps = merge_boxes(comps, gap=10)
    # remove text-like tiny fragments
    comps = [c for c in comps if c.w >= args.min_w and c.h >= args.min_h]
    comps.sort(key=lambda c: (c.y1, c.x1))

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    for i, c in enumerate(comps, start=1):
        crop = src.crop((c.x1, c.y1, c.x2 + 1, c.y2 + 1)).convert("RGBA")
        cut = remove_border_bg(crop)
        fin = normalize_to_canvas(cut)
        fin.save(out_dir / f"{args.prefix}_{i:02d}.png")

    print(f"exported {len(comps)} objects to {out_dir}")


if __name__ == "__main__":
    main()
