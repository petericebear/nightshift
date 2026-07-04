#!/usr/bin/env python3
"""
Nightshift ad compositor.

Takes an AI-generated base visual and turns it into a platform-exact ad creative:
cover-crops to the target size, lays a legibility scrim, and overlays a crisp,
auto-fitted headline + subhead + optional CTA pill + logo, using brand colors from
DESIGN.md (passed in as flags by the ad-designer agent). Text and logo are rendered
deterministically here — the AI model only produces the imagery — so copy is always
sharp and on-brand.

Requires Pillow:  pip install pillow  (or: pip install pillow --break-system-packages)

Example:
  compose.py --base bg.png --out google_square.png --size 1200x1200 \
    --headline "Ship features while you sleep" \
    --subhead  "Autonomous builds, verified before you wake up." \
    --cta "Start free" --logo .context/brand-assets/logo/logo.png \
    --brand "#1D1D2B" --accent "#3B82F6" --text "#FFFFFF" --layout bottom
"""
import argparse
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
except ImportError:
    sys.stderr.write(
        "NIGHTSHIFT: Pillow is required. Install with:\n"
        "  pip install pillow  (or: pip install pillow --break-system-packages)\n"
    )
    sys.exit(3)


# ---- fonts -----------------------------------------------------------------
FONT_CANDIDATES_BOLD = [
    "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    "/System/Library/Fonts/HelveticaNeue.ttc",
    "/System/Library/Fonts/Helvetica.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "/Library/Fonts/Arial Bold.ttf",
]
FONT_CANDIDATES_REG = [
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/System/Library/Fonts/Helvetica.ttc",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "/Library/Fonts/Arial.ttf",
]


def _first_existing(paths):
    for p in paths:
        if p and os.path.exists(p):
            return p
    return None


def load_font(path, size, bold=True):
    candidates = ([path] if path else []) + (FONT_CANDIDATES_BOLD if bold else FONT_CANDIDATES_REG)
    fp = _first_existing(candidates)
    if fp:
        try:
            return ImageFont.truetype(fp, size=size)
        except Exception:
            pass
    return ImageFont.load_default()


def hex2rgb(h, alpha=None):
    h = (h or "#000000").lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    return (r, g, b, alpha) if alpha is not None else (r, g, b)


# ---- image helpers ---------------------------------------------------------
def cover_crop(img, w, h):
    """Scale to cover and center-crop to exactly w x h."""
    src_w, src_h = img.size
    scale = max(w / src_w, h / src_h)
    nw, nh = max(1, int(src_w * scale + 0.5)), max(1, int(src_h * scale + 0.5))
    img = img.resize((nw, nh), Image.LANCZOS)
    left, top = (nw - w) // 2, (nh - h) // 2
    return img.crop((left, top, left + w, top + h))


def gradient_bg(w, h, c1, c2):
    """Vertical gradient fallback when no base image is supplied."""
    base = Image.new("RGB", (w, h), c1)
    top = Image.new("RGB", (w, h), c2)
    mask = Image.new("L", (w, h))
    md = mask.load()
    for y in range(h):
        v = int(255 * (y / max(1, h - 1)))
        for x in range(w):
            md[x, y] = v
    return Image.composite(top, base, mask)


def scrim(w, h, color, layout):
    """Legibility gradient over the text region."""
    ov = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = ov.load()
    r, g, b = color[:3]
    max_a = 205
    for y in range(h):
        for x in range(w):
            if layout == "center":
                a = int(max_a * 0.7)
            elif layout == "top":
                t = 1 - (y / max(1, h - 1))
                a = int(max_a * max(0, t) ** 1.3)
            else:  # bottom (default)
                t = y / max(1, h - 1)
                a = int(max_a * max(0, t) ** 1.3)
            px[x, y] = (r, g, b, a)
    return ov


def wrap_fit(draw, text, font_path, max_w, max_h, start_size, min_size=14, bold=True, leading=1.12):
    """Shrink font until wrapped text fits within max_w x max_h. Returns (font, lines, line_h)."""
    words = text.split()
    size = start_size
    while size >= min_size:
        font = load_font(font_path, size, bold=bold)
        lines, cur = [], ""
        for wd in words:
            trial = (cur + " " + wd).strip()
            if draw.textlength(trial, font=font) <= max_w or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = wd
        if cur:
            lines.append(cur)
        bbox = font.getbbox("Ag")
        line_h = int((bbox[3] - bbox[1]) * leading) + 2
        if line_h * len(lines) <= max_h and all(draw.textlength(l, font=font) <= max_w for l in lines):
            return font, lines, line_h
        size -= 2
    font = load_font(font_path, min_size, bold=bold)
    return font, [text], min_size + 4


def draw_lines(draw, lines, x, y, font, line_h, fill):
    for ln in lines:
        draw.text((x, y), ln, font=font, fill=fill)
        y += line_h
    return y


def paste_logo(canvas, logo_path, box_w, pad, position="tl"):
    try:
        logo = Image.open(logo_path).convert("RGBA")
    except Exception:
        return
    ratio = box_w / logo.width
    logo = logo.resize((box_w, max(1, int(logo.height * ratio))), Image.LANCZOS)
    W, H = canvas.size
    if position == "tl":
        pos = (pad, pad)
    elif position == "tr":
        pos = (W - logo.width - pad, pad)
    else:
        pos = (pad, H - logo.height - pad)
    canvas.alpha_composite(logo, pos)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", help="base image; if omitted a brand gradient is used")
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", required=True, help="WxH, e.g. 1200x628")
    ap.add_argument("--headline", default="")
    ap.add_argument("--subhead", default="")
    ap.add_argument("--cta", default="")
    ap.add_argument("--logo", default="")
    ap.add_argument("--brand", default="#111827")
    ap.add_argument("--accent", default="#3B82F6")
    ap.add_argument("--text", default="#FFFFFF")
    ap.add_argument("--font", default="")
    ap.add_argument("--font-bold", dest="font_bold", default="")
    ap.add_argument("--layout", default="bottom", choices=["bottom", "top", "center"])
    ap.add_argument("--logo-pos", dest="logo_pos", default="tl", choices=["tl", "tr", "bl"])
    ap.add_argument("--badge", default="", help="small corner badge, e.g. '2/5' for carousel")
    args = ap.parse_args()

    w, h = (int(x) for x in args.size.lower().split("x"))
    brand = hex2rgb(args.brand)
    accent = hex2rgb(args.accent)
    text_c = hex2rgb(args.text)

    # 1) background
    if args.base and os.path.exists(args.base):
        bg = Image.open(args.base).convert("RGB")
        canvas = cover_crop(bg, w, h).convert("RGBA")
    else:
        c2 = tuple(min(255, int(c * 1.6) + 20) for c in brand)
        canvas = gradient_bg(w, h, brand, c2).convert("RGBA")

    # 2) legibility scrim
    if args.headline or args.subhead or args.cta:
        canvas.alpha_composite(scrim(w, h, brand, args.layout))

    draw = ImageDraw.Draw(canvas)
    pad = max(24, int(w * 0.055))
    content_w = w - 2 * pad

    # 3) text block
    fb = args.font_bold or args.font
    fr = args.font
    head_font, head_lines, head_lh = wrap_fit(
        draw, args.headline, fb, content_w, int(h * 0.42),
        start_size=max(28, int(h * 0.11)), bold=True) if args.headline else (None, [], 0)
    sub_font, sub_lines, sub_lh = wrap_fit(
        draw, args.subhead, fr, content_w, int(h * 0.24),
        start_size=max(18, int(h * 0.05)), bold=False) if args.subhead else (None, [], 0)

    head_block = head_lh * len(head_lines)
    sub_block = (sub_lh * len(sub_lines) + int(h * 0.02)) if sub_lines else 0
    cta_h = int(h * 0.085) if args.cta else 0
    total = head_block + sub_block + (cta_h + int(h * 0.02) if args.cta else 0)

    if args.layout == "center":
        y = (h - total) // 2
        tx = pad
    elif args.layout == "top":
        y = pad + (int(h * 0.14) if args.logo else 0)
        tx = pad
    else:  # bottom
        y = h - pad - total
        tx = pad

    if head_lines:
        y = draw_lines(draw, head_lines, tx, y, head_font, head_lh, text_c)
    if sub_lines:
        y += int(h * 0.02)
        soft = tuple(list(text_c[:3]) + [230]) if len(text_c) == 3 else text_c
        y = draw_lines(draw, sub_lines, tx, y, sub_font, sub_lh, soft)

    # 4) CTA pill
    if args.cta:
        y += int(h * 0.02)
        cf = load_font(fb, max(16, int(h * 0.038)), bold=True)
        tw = draw.textlength(args.cta, font=cf)
        bx0, by0 = tx, y
        bx1, by1 = int(tx + tw + pad * 1.2), int(y + cta_h)
        rad = (by1 - by0) // 2
        draw.rounded_rectangle([bx0, by0, bx1, by1], radius=rad, fill=accent)
        tb = cf.getbbox("Ag")
        ty = by0 + ((by1 - by0) - (tb[3] - tb[1])) // 2 - tb[1]
        draw.text((bx0 + (bx1 - bx0 - tw) / 2, ty), args.cta, font=cf, fill=(255, 255, 255))

    # 5) logo
    if args.logo and os.path.exists(args.logo):
        paste_logo(canvas, args.logo, int(w * 0.20), pad, position=args.logo_pos)

    # 6) carousel badge
    if args.badge:
        bf = load_font(fb, max(14, int(h * 0.03)), bold=True)
        bw = draw.textlength(args.badge, font=bf) + 18
        draw.rounded_rectangle([w - pad - bw, pad, w - pad, pad + int(h * 0.05)],
                               radius=8, fill=accent)
        draw.text((w - pad - bw + 9, pad + int(h * 0.012)), args.badge, font=bf, fill=(255, 255, 255))

    os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)
    canvas.convert("RGB").save(args.out, quality=92)
    print(args.out)


if __name__ == "__main__":
    main()
