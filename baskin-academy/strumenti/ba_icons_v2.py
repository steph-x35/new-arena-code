#!/usr/bin/env python3
"""Batch 4 icons: the NEW app icon (with background) + the transparent logo
for the centre of the court.

  uploads/icon256_white-removebg-preview (1).png  -> icon WITH background
  uploads/icon256_white-removebg-preview.png      -> transparent logo

Outputs (all inside baskin_academy/):
  icon.png                 256  project icon (with background)
  assets/icon_192.png      192  launcher icon (with background)
  assets/icon_bg_432.png   432  adaptive background (soft gradient of the icon)
  assets/icon_fg_432.png   432  adaptive foreground (transparent logo, safe zone)
  assets/center_logo.png   512  centre-circle crest (transparent, trimmed)
"""
from PIL import Image, ImageFilter

BASE = "/home/user"
SRC_BG = f"{BASE}/uploads/icon256_white-removebg-preview (1).png"
SRC_TR = f"{BASE}/uploads/icon256_white-removebg-preview.png"
OUT = f"{BASE}/baskin_academy"

bg = Image.open(SRC_BG).convert("RGBA")
tr = Image.open(SRC_TR).convert("RGBA")


def square(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.LANCZOS)


# 1. project icon and launcher icon: the icon WITH its background
square(bg, 256).save(f"{OUT}/icon.png")
square(bg, 192).save(f"{OUT}/assets/icon_192.png")

# 2. adaptive background: the same picture, blurred into a soft gradient so
#    the adaptive icon matches the flat icon's colours.
bgl = square(bg, 432).filter(ImageFilter.GaussianBlur(70))
bgl.save(f"{OUT}/assets/icon_bg_432.png")

# 3. adaptive foreground: transparent logo inside the safe zone. Android only
#    guarantees the middle 66% of the 108dp canvas, so the crest stays at ~58%.
bbox = tr.getchannel("A").getbbox()
crest = tr.crop(bbox)
canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0))
target = int(432 * 0.58)
scale = target / max(crest.size)
crest_r = crest.resize((max(1, int(crest.width * scale)), max(1, int(crest.height * scale))), Image.LANCZOS)
canvas.alpha_composite(crest_r, ((432 - crest_r.width) // 2, (432 - crest_r.height) // 2))
canvas.save(f"{OUT}/assets/icon_fg_432.png")

# 4. centre-of-court crest: transparent, trimmed, with a small margin
side = 512
margin = 26
fit = side - margin * 2
s = min(fit / crest.width, fit / crest.height)
crest_c = crest.resize((max(1, int(crest.width * s)), max(1, int(crest.height * s))), Image.LANCZOS)
court = Image.new("RGBA", (side, side), (0, 0, 0, 0))
court.alpha_composite(crest_c, ((side - crest_c.width) // 2, (side - crest_c.height) // 2))
court.save(f"{OUT}/assets/center_logo.png")

for f in ["icon.png", "assets/icon_192.png", "assets/icon_bg_432.png",
          "assets/icon_fg_432.png", "assets/center_logo.png"]:
    im = Image.open(f"{OUT}/{f}")
    a = im.convert("RGBA").getchannel("A")
    print(f"{f:26} {im.size} alpha0={a.histogram()[0]:6d} corner={im.convert('RGBA').getpixel((0,0))}")
print("ICONS: done")
