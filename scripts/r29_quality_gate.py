#!/usr/bin/env python3
from PIL import Image
from pathlib import Path

ALPHA_THRESHOLD = 40
ASSET = Path('assets/miniroom/generated/item_teddy_bear.png')


def draw_rect_for_contain(visual_rect, img_w, img_h):
    left, top, width, height = visual_rect
    image_aspect = img_w / img_h
    view_aspect = width / height
    if image_aspect > view_aspect:
        draw_w = width
        draw_h = draw_w / image_aspect
        draw_l = left
        draw_t = top + ((height - draw_h) / 2)
    else:
        draw_h = height
        draw_w = draw_h * image_aspect
        draw_t = top
        draw_l = left + ((width - draw_w) / 2)
    return (draw_l, draw_t, draw_w, draw_h)


def world_to_pixel(world_pt, visual_rect, img_w, img_h):
    wx, wy = world_pt
    dl, dt, dw, dh = draw_rect_for_contain(visual_rect, img_w, img_h)
    if not (dl <= wx <= dl + dw and dt <= wy <= dt + dh):
        return None
    lx = (wx - dl) / dw
    ly = (wy - dt) / dh
    if lx < 0 or lx > 1 or ly < 0 or ly > 1:
        return None
    px = max(0, min(img_w - 1, round(lx * (img_w - 1))))
    py = max(0, min(img_h - 1, round(ly * (img_h - 1))))
    return px, py


def pixel_to_world(px, py, visual_rect, img_w, img_h):
    dl, dt, dw, dh = draw_rect_for_contain(visual_rect, img_w, img_h)
    wx = dl + (px / (img_w - 1)) * dw
    wy = dt + (py / (img_h - 1)) * dh
    return wx, wy


def hit_test(world_pt, visual_rect, alpha, img_w, img_h):
    mapped = world_to_pixel(world_pt, visual_rect, img_w, img_h)
    if mapped is None:
        return False
    px, py = mapped
    return alpha[py * img_w + px] > ALPHA_THRESHOLD


def sample_points(alpha, img_w, img_h, want_opaque=True, n=20):
    pts = []
    step_y = max(1, img_h // 40)
    step_x = max(1, img_w // 40)
    for y in range(0, img_h, step_y):
        for x in range(0, img_w, step_x):
            a = alpha[y * img_w + x]
            ok = a > ALPHA_THRESHOLD if want_opaque else a <= ALPHA_THRESHOLD
            if ok:
                pts.append((x, y))
                if len(pts) == n:
                    return pts
    return pts


def main():
    img = Image.open(ASSET).convert('RGBA')
    img_w, img_h = img.size
    rgba = list(img.getdata())
    alpha = [a for _, _, _, a in rgba]

    visual_rect = (0.0, 0.0, 68.0, 68.0)

    transparent_pixels = sample_points(alpha, img_w, img_h, want_opaque=False, n=20)
    opaque_pixels = sample_points(alpha, img_w, img_h, want_opaque=True, n=20)

    if len(transparent_pixels) < 20 or len(opaque_pixels) < 20:
        raise SystemExit('Not enough sample points for quality gate')

    transparent_hits = 0
    for px, py in transparent_pixels:
        world = pixel_to_world(px, py, visual_rect, img_w, img_h)
        if hit_test(world, visual_rect, alpha, img_w, img_h):
            transparent_hits += 1

    opaque_hits = 0
    for px, py in opaque_pixels:
        world = pixel_to_world(px, py, visual_rect, img_w, img_h)
        if hit_test(world, visual_rect, alpha, img_w, img_h):
            opaque_hits += 1

    print(f'transparent_points=20 transparent_hits={transparent_hits}')
    print(f'opaque_points=20 opaque_hits={opaque_hits}')


if __name__ == '__main__':
    main()
