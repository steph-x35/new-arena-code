#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Baskin Academy launcher icon — orange disc (brand #FF9900).

icon.png / icon_192  : disc + logo, for launchers that show the bitmap whole
icon_fg_432          : adaptive FOREGROUND = the art alone (transparent),
                       sized to sit inside the 66% safe zone
icon_bg_432          : adaptive BACKGROUND = solid brand orange
"""
from PIL import Image, ImageDraw

ART = "/home/user/logo_transparent.png"
OUT = "/home/user/baskin_academy"
ORANGE = (255, 153, 0, 255)


def fit(art, box, frac):
    s = min(box * frac / art.width, box * frac / art.height)
    a = art.resize((max(1, int(art.width * s)), max(1, int(art.height * s))), Image.LANCZOS)
    c = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    c.paste(a, ((box - a.width) // 2, (box - a.height) // 2), a)
    return c


def disc(box, frac):
    layer = Image.new("RGBA", (box, box), (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse([0, 0, box - 1, box - 1], fill=ORANGE)
    return Image.alpha_composite(layer, fit(art, box, frac))


art = Image.open(ART).convert("RGBA")
print("art", art.size)

disc(256, 0.70).save(OUT + "/icon.png")
disc(192, 0.70).save(OUT + "/assets/icon_192.png")
disc(432, 0.70).save("/home/user/icon_preview_disc.png")

fit(art, 432, 0.58).save(OUT + "/assets/icon_fg_432.png")
Image.new("RGBA", (432, 432), ORANGE).save(OUT + "/assets/icon_bg_432.png")

# what the launcher shows for the adaptive icon (circle mask, 432 canvas)
base = Image.new("RGBA", (432, 432), ORANGE)
comp = Image.alpha_composite(base, fit(art, 432, 0.58))
mask = Image.new("L", (432, 432), 0)
ImageDraw.Draw(mask).ellipse([6, 6, 425, 425], fill=255)
prev = Image.new("RGBA", (432, 432), (30, 32, 38, 255))
prev.paste(comp, (0, 0), mask)
prev.save("/home/user/icon_preview_adaptive.png")
print("icons written")
