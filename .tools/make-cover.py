#!/usr/bin/env python3
"""Generate a simple, thumbnail-legible EPUB cover.

    python3 make-cover.py "High Level Design" "Guide" out.png [accent_hex]

Big centered title, small kicker under it, flat colour band top+bottom so the
book is recognisable at Kindle-library thumbnail size. 1600x2560 (Kindle's
recommended 1.6:1).
"""
import sys
from PIL import Image, ImageDraw, ImageFont

W, H = 1600, 2560
BG = (250, 249, 246)
INK = (26, 28, 33)

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def wrap(draw, text, font, max_w):
    words, lines, cur = text.split(), [], ""
    for w in words:
        trial = f"{cur} {w}".strip()
        if draw.textlength(trial, font=font) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def main():
    title = sys.argv[1]
    kicker = sys.argv[2] if len(sys.argv) > 2 else ""
    out = sys.argv[3]
    accent = sys.argv[4] if len(sys.argv) > 4 else "#2f6f4f"
    accent = tuple(int(accent.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4))

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # colour bands top and bottom -- the part that survives a tiny thumbnail
    d.rectangle([0, 0, W, 190], fill=accent)
    d.rectangle([0, H - 190, W, H], fill=accent)

    margin = 150
    max_w = int((W - 2 * margin) * 0.94)   # keep a little air even for the widest word

    # fit the title: shrink font until it fits in <=3 lines within max_w
    size = 250
    while size > 90:
        f = ImageFont.truetype(FONT_BOLD, size)
        lines = wrap(d, title, f, max_w)
        if len(lines) <= 3 and all(d.textlength(ln, font=f) <= max_w for ln in lines):
            break
        size -= 8
    title_font = ImageFont.truetype(FONT_BOLD, size)
    lines = wrap(d, title, title_font, max_w)

    line_h = int(size * 1.18)
    block_h = line_h * len(lines)
    y = (H - block_h) // 2 - 40
    for ln in lines:
        w = d.textlength(ln, font=title_font)
        d.text(((W - w) / 2, y), ln, font=title_font, fill=INK)
        y += line_h

    # kicker under the title
    if kicker:
        kf = ImageFont.truetype(FONT_REG, 64)
        ku = kicker.upper()
        # letter-spacing
        spaced = "  ".join(ku)
        kw = d.textlength(spaced, font=kf)
        ky = y + 60
        d.text(((W - kw) / 2, ky), spaced, font=kf, fill=accent)
        # rule above kicker
        rw = min(max_w * 0.5, 520)
        d.rectangle([(W - rw) / 2, y + 24, (W + rw) / 2, y + 28], fill=accent)

    img.save(out, "PNG")
    print(f"wrote {out} ({size}px title, {len(lines)} lines)")


if __name__ == "__main__":
    main()
