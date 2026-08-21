#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
KRISTALL USTUN (beacon) — Blender render kadrlaridan o'yin uchun sprite-sheet yasaydi.

Manba:  assets/objects/piller/anim/pillar_0001..0096.png   (512x512, to'liq bir suzish tsikli)
Natija: assets/objects/pillar_anim.png        — 8x4 = 32 kadr, har biri 74x116
        assets/objects/pillar_anim_white.png  — hover konturi uchun oq siluet
        assets/objects/pillar_glow.png        — yerga tushadigan iliq nur (glow_pool.png dan)

Nega shunday:
  * Barcha kadrlar BITTA umumiy bbox bilan kesiladi — aks holda kadrlar orasida
    sprite "sakraydi" (har kadrning bboxi har xil, chunki tepa blok suzadi).
  * O'yin uslubi — chunky pixel-art. Shuning uchun avval o'yindagi haqiqiy
    o'lchamga (37x58) tushiramiz, keyin NEAREST bilan 2x kattalashtiramiz:
    piksellar 2x2 blok bo'ladi (boshqa asset'lar bilan bir xil uslub),
    lekin zoom qilinganda ham tiniq turadi.
  * Alfa premultiply qilinadi — aks holda kichraytirishda qora hoshiya chiqadi.

Ishga tushirish:  python tools/make_pillar_sheet.py
"""

import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow kerak:  pip install pillow")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_ANIM = os.path.join(ROOT, "assets", "objects", "piller", "anim")
SRC_GLOW = os.path.join(ROOT, "assets", "objects", "piller", "glow_pool.png")
OUT_DIR = os.path.join(ROOT, "assets", "objects")

FRAMES = 32          # 96 kadrdan har 3-chisi
COLS, ROWS = 8, 4
ART_W, ART_H = 37, 58    # o'yindagi haqiqiy piksel o'lchami
BLOCK = 2                # piksel blok kattaligi (chunky ko'rinish)
GLOW_W, GLOW_H = 180, 104


def smooth_resize(img, size):
    """Alfa premultiply bilan sifatli kichraytirish (qora hoshiyasiz)."""
    img = img.convert("RGBA")
    r, g, b, a = img.split()
    rm = Image.merge("RGB", (r, g, b))
    # premultiply
    prem = Image.new("RGB", img.size)
    pp, pa = prem.load(), a.load()
    src = rm.load()
    for y in range(img.height):
        for x in range(img.width):
            av = pa[x, y]
            if av == 0:
                pp[x, y] = (0, 0, 0)
            elif av == 255:
                pp[x, y] = src[x, y]
            else:
                cr, cg, cb = src[x, y]
                pp[x, y] = (cr * av // 255, cg * av // 255, cb * av // 255)
    prem = prem.resize(size, Image.LANCZOS)
    na = a.resize(size, Image.LANCZOS)
    # unpremultiply
    out = Image.new("RGBA", size)
    op, ip, ia = out.load(), prem.load(), na.load()
    for y in range(size[1]):
        for x in range(size[0]):
            av = ia[x, y]
            if av == 0:
                op[x, y] = (0, 0, 0, 0)
            else:
                cr, cg, cb = ip[x, y]
                op[x, y] = (min(255, cr * 255 // av),
                            min(255, cg * 255 // av),
                            min(255, cb * 255 // av), av)
    return out


def main():
    names = sorted(f for f in os.listdir(SRC_ANIM) if f.lower().endswith(".png"))
    if not names:
        sys.exit("Kadrlar topilmadi: " + SRC_ANIM)
    print("manba kadrlar:", len(names))

    # 1) BARCHA kadrlar uchun umumiy bbox (sprite sakramasligi uchun)
    union = None
    for n in names:
        with Image.open(os.path.join(SRC_ANIM, n)) as im:
            b = im.convert("RGBA").getbbox()
        if b is None:
            continue
        union = b if union is None else (min(union[0], b[0]), min(union[1], b[1]),
                                        max(union[2], b[2]), max(union[3], b[3]))
    print("umumiy bbox:", union, "->", (union[2] - union[0], union[3] - union[1]))

    # 2) 96 kadrdan FRAMES ta teng tanlab olamiz
    step = len(names) / float(FRAMES)
    picked = [names[int(i * step) % len(names)] for i in range(FRAMES)]

    fw, fh = ART_W * BLOCK, ART_H * BLOCK
    sheet = Image.new("RGBA", (COLS * fw, ROWS * fh), (0, 0, 0, 0))
    for i, n in enumerate(picked):
        with Image.open(os.path.join(SRC_ANIM, n)) as im:
            frame = im.convert("RGBA").crop(union)
        small = smooth_resize(frame, (ART_W, ART_H))
        big = small.resize((fw, fh), Image.NEAREST)
        sheet.paste(big, ((i % COLS) * fw, (i // COLS) * fh))
    out_sheet = os.path.join(OUT_DIR, "pillar_anim.png")
    sheet.save(out_sheet)
    print("yozildi:", out_sheet, sheet.size, "kadr:", (fw, fh))

    # 3) Oq siluet (hover konturi uchun) — o'yin ichida hisoblanmasin
    white = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    wp, sp = white.load(), sheet.load()
    for y in range(sheet.height):
        for x in range(sheet.width):
            av = sp[x, y][3]
            if av:
                wp[x, y] = (255, 255, 255, av)
    out_white = os.path.join(OUT_DIR, "pillar_anim_white.png")
    white.save(out_white)
    print("yozildi:", out_white)

    # 4) Yerga tushadigan nur (allaqachon chizilgan, faqat kesib kichraytiramiz)
    with Image.open(SRC_GLOW) as gim:
        gim = gim.convert("RGBA")
        gb = gim.getbbox()
        glow = smooth_resize(gim.crop(gb), (GLOW_W, GLOW_H))
    out_glow = os.path.join(OUT_DIR, "pillar_glow.png")
    glow.save(out_glow)
    print("yozildi:", out_glow, "manba bbox:", gb)

    # 5) main.gd uchun kerakli o'lchovlar
    src_w, src_h = union[2] - union[0], union[3] - union[1]
    gcx = (gb[0] + gb[2]) / 2.0 - union[0]          # nur markazi (kesilgan kadr ichida)
    gcy = (gb[1] + gb[3]) / 2.0 - union[1]
    print("--- main.gd uchun ---")
    print("kadr:", fw, "x", fh, " (manba", src_w, "x", src_h, ")")
    print("nur markazi kadr pastidan yuqoriga:", round((src_h - gcy) / src_h, 4), "* kadr balandligi")
    print("nur markazi kadr markazidan gorizontal:", round((gcx - src_w / 2.0) / src_w, 4))


if __name__ == "__main__":
    main()
