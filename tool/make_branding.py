"""Generates PhoneProof launcher-icon + splash source images.

Emblem: a teal phone silhouette with a horizontal scan-line glow on a dark
radial-gradient canvas — the same "forensic scanner" motif used in-app.
Run from the project root:  python tool/make_branding.py
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "branding")
os.makedirs(OUT, exist_ok=True)

TEAL = (54, 226, 200)
C_CENTER = np.array([17, 32, 42])   # #11202A
C_EDGE = np.array([7, 9, 13])       # #07090D


def gradient_bg(size):
    y, x = np.ogrid[0:size, 0:size]
    cx, cy = size / 2, size * 0.42
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    t = np.clip(d / (size * 0.78), 0, 1)[..., None]
    rgb = (C_CENTER * (1 - t) + C_EDGE * t).astype("uint8")
    a = np.full((size, size, 1), 255, "uint8")
    return Image.fromarray(np.concatenate([rgb, a], axis=2), "RGBA")


def emblem(box):
    """Return an RGBA image (box x box) of the phone+scanline emblem."""
    S = 4
    s = box * S
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))

    pw, ph = int(s * 0.50), int(s * 0.82)
    x0, y0 = (s - pw) // 2, (s - ph) // 2
    x1, y1 = x0 + pw, y0 + ph
    rad = int(s * 0.135)
    sw = int(s * 0.044)
    midy = y0 + int(ph * 0.47)
    band = int(ph * 0.11)

    # --- glow layer (blurred) ---
    glow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.rounded_rectangle([x0, y0, x1, y1], radius=rad,
                         outline=TEAL + (150,), width=sw)
    gd.rectangle([x0 - sw, midy - band, x1 + sw, midy + band], fill=TEAL + (110,))
    glow = glow.filter(ImageFilter.GaussianBlur(s * 0.020))
    im = Image.alpha_composite(im, glow)

    # --- crisp layer ---
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([x0, y0, x1, y1], radius=rad, fill=TEAL + (20,))
    d.rounded_rectangle([x0, y0, x1, y1], radius=rad, outline=TEAL + (255,), width=sw)

    # camera notch
    nr = int(s * 0.020)
    ncx, ncy = s // 2, y0 + int(ph * 0.085)
    d.ellipse([ncx - nr, ncy - nr, ncx + nr, ncy + nr], fill=TEAL + (255,))

    # scan line
    lw = int(s * 0.018)
    d.line([x0 + sw, midy, x1 - sw, midy], fill=TEAL + (255,), width=lw)
    # bright nodes on the scan line
    for fx in (0.30, 0.5, 0.72):
        cx = int(x0 + pw * fx)
        d.ellipse([cx - lw, midy - lw, cx + lw, midy + lw], fill=(255, 255, 255, 235))

    return im.resize((box, box), Image.LANCZOS)


def paste_center(canvas, emb):
    cw = canvas.size[0]
    x = (cw - emb.size[0]) // 2
    y = (cw - emb.size[1]) // 2
    canvas.alpha_composite(emb, (x, y))
    return canvas


def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p)
    print("wrote", os.path.normpath(p))


# ---- Launcher icons ----
# Legacy / full-bleed icon: gradient bg + emblem.
full = gradient_bg(1024)
paste_center(full, emblem(700))
save(full, "ic_full.png")

# Adaptive background (gradient only).
save(gradient_bg(1024), "ic_bg.png")

# Adaptive foreground (transparent, emblem inside the 66% safe zone).
fore = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
paste_center(fore, emblem(610))
save(fore, "ic_fore.png")

# ---- Splash ----
# Legacy fullscreen splash logo (shown at native size, centered).
splash = Image.new("RGBA", (1152, 1152), (0, 0, 0, 0))
paste_center(splash, emblem(720))
save(splash, "splash_logo.png")

# Android 12 splash icon (masked to a circle -> extra padding).
a12 = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
paste_center(a12, emblem(520))
save(a12, "splash_logo_a12.png")

print("done")
