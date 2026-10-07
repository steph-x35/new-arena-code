#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Baskin logo -> clean transparent art (no white halo) for
(a) the app icon and (b) the centre-court crest.

Pipeline: flood-fill the white background away from the border, ramp the
alpha on the outermost ring of ink, then BLEED the nearest solid colour
outwards into the transparent pixels so a soft edge never shows white.
"""
from collections import Counter, deque
from PIL import Image, ImageDraw

SRC = "/home/user/uploads/image-1.png"
OUT = "/home/user/baskin_academy"


def load_clean(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()

    def white(p):
        return p[0] >= 232 and p[1] >= 232 and p[2] >= 232

    bg = bytearray(w * h)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if white(px[x, y]) and not bg[y * w + x]:
                bg[y * w + x] = 1
                dq.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if white(px[x, y]) and not bg[y * w + x]:
                bg[y * w + x] = 1
                dq.append((x, y))
    while dq:
        x, y = dq.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny * w + nx] and white(px[nx, ny]):
                bg[ny * w + nx] = 1
                dq.append((nx, ny))

    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            if bg[y * w + x]:
                ap[x, y] = 0
                continue
            touch = False
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and bg[ny * w + nx]:
                    touch = True
                    break
            if touch:
                v = min(px[x, y])          # dark ink keeps full opacity
                ap[x, y] = 255 if v <= 200 else max(0, min(255, int(255.0 * (255 - v) / 55.0)))

    rgba = im.convert("RGBA")
    rp = rgba.load()
    solid = bytearray(w * h)
    dq2 = deque()
    for y in range(h):
        for x in range(w):
            if ap[x, y] >= 250:
                solid[y * w + x] = 1
                dq2.append((x, y))
    while dq2:
        x, y = dq2.popleft()
        c = rp[x, y]
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not solid[ny * w + nx]:
                solid[ny * w + nx] = 1
                rp[nx, ny] = (c[0], c[1], c[2], rp[nx, ny][3])
                dq2.append((nx, ny))
    rgba.putalpha(alpha)
    return rgba


def fit(im, box, frac):
    """Scale the art into a box*box canvas occupying `frac` of it."""
    s = min(box * frac / im.width, box * frac / im.height)
    art = im.resize((max(1, int(im.width * s)), max(1, int(im.height * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    canvas.paste(art, ((box - art.width) // 2, (box - art.height) // 2), art)
    return canvas


def brand_orange(im):
    cnt = Counter()
    for p in im.convert("RGBA").getdata():
        if p[3] > 200 and p[0] > 200 and 90 < p[1] < 195 and p[2] < 90:
            cnt[p[:3]] += 1
    return cnt.most_common(1)[0][0] if cnt else (243, 146, 0)


full = load_clean(SRC)
art = full.crop(full.getbbox())
print("trimmed art:", art.size, "orange:", brand_orange(art))

art.save("/home/user/logo_transparent.png")
art.save(OUT + "/assets/logo_transparent.png")
fit(art, 512, 0.94).save(OUT + "/assets/center_logo.png")

for kind in ("clear", "disc", "white"):
    bg = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
    if kind == "disc":
        ImageDraw.Draw(bg).ellipse([0, 0, 431, 431], fill=brand_orange(art) + (255,))
    elif kind == "white":
        bg = Image.new("RGBA", (432, 432), (255, 255, 255, 255))
    Image.alpha_composite(bg, fit(art, 432, 0.80)).save("/home/user/icon_preview_%s.png" % kind)
print("done")
