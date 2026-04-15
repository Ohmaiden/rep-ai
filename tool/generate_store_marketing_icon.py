"""
Generate a modern iOS-style marketing icon from the existing store icon.

Uses the exact dumbbell artwork from store_assets/app_icon_512.png and
places it on a squircle-shaped blue gradient background (the same modern
Apple style as tool/generate_marketing_icon.py), so only the container
shape changes — the dumbbell itself stays identical.

Output: 1024x1024 PNG at store_assets/app_icon_ios_marketing.png.

Run with:  py tool/generate_store_marketing_icon.py
"""

from __future__ import annotations
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

REPO = Path(__file__).resolve().parents[1]
SRC_PATH = REPO / "store_assets" / "app_icon_512.png"
OUT_PATH = REPO / "store_assets" / "app_icon_ios_marketing.png"

OUT_SIZE = 1024
SUPERSAMPLE = 4
RENDER = OUT_SIZE * SUPERSAMPLE

TOP_COLOR = (59, 130, 246)        # #3B82F6
BOTTOM_COLOR = (29, 78, 216)      # #1D4ED8
SQUIRCLE_N = 5.0

# Whiteness extraction threshold: pixels whose min(R,G,B) is at or above
# DUMBBELL_HI count as fully opaque dumbbell. Pixels below DUMBBELL_LO count
# as fully transparent (pure background). Linear fade between.
DUMBBELL_LO = 60
DUMBBELL_HI = 235


def squircle_alpha(size: int, n: float) -> np.ndarray:
    xs = np.linspace(-1.0, 1.0, size)
    ys = np.linspace(-1.0, 1.0, size)
    x, y = np.meshgrid(xs, ys)
    d = np.power(np.abs(x), n) + np.power(np.abs(y), n)
    r = np.power(d, 1.0 / n)
    half_px = 1.0 / size
    alpha = np.clip((1.0 - r) / (2 * half_px), 0.0, 1.0)
    return (alpha * 255).astype(np.uint8)


def vertical_gradient(size: int, top_rgb, bottom_rgb) -> Image.Image:
    ts = np.linspace(0.0, 1.0, size)[:, None]
    top = np.array(top_rgb, dtype=np.float32)
    bot = np.array(bottom_rgb, dtype=np.float32)
    row = top + (bot - top) * ts
    arr = np.broadcast_to(row[:, None, :], (size, size, 3)).astype(np.uint8)
    return Image.fromarray(arr, "RGB")


def top_highlight(size: int) -> Image.Image:
    cx, cy = size / 2, -size * 0.35
    radius = size * 1.25
    xs = np.arange(size, dtype=np.float32)
    ys = np.arange(size, dtype=np.float32)
    x, y = np.meshgrid(xs, ys)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    t = np.clip(1.0 - d / radius, 0.0, 1.0) ** 2
    alpha = (t * 36).astype(np.uint8)
    white = np.ones((size, size, 3), dtype=np.uint8) * 255
    rgba = np.dstack([white, alpha])
    return Image.fromarray(rgba, "RGBA")


def extract_dumbbell(src: Image.Image, size: int) -> Image.Image:
    """Scale `src` up to `size` and extract the white dumbbell as an RGBA
    layer (white fill, alpha = 'whiteness' of the source pixel)."""
    scaled = src.convert("RGB").resize((size, size), resample=Image.LANCZOS)
    arr = np.asarray(scaled, dtype=np.float32)
    whiteness = arr.min(axis=2)  # 255 where pure white, ~min(src) where blue
    t = np.clip((whiteness - DUMBBELL_LO) / (DUMBBELL_HI - DUMBBELL_LO), 0.0, 1.0)
    alpha = (t * 255).astype(np.uint8)
    white = np.full((size, size, 3), 255, dtype=np.uint8)
    rgba = np.dstack([white, alpha])
    return Image.fromarray(rgba, "RGBA")


def main():
    if not SRC_PATH.exists():
        raise SystemExit(f"source icon not found: {SRC_PATH}")
    src = Image.open(SRC_PATH)

    # 1. Blue gradient, masked to squircle
    bg = vertical_gradient(RENDER, TOP_COLOR, BOTTOM_COLOR).convert("RGBA")
    mask_arr = squircle_alpha(RENDER, SQUIRCLE_N)
    bg.putalpha(Image.fromarray(mask_arr, "L"))

    # 2. Subtle top highlight, clipped to the squircle
    hi = top_highlight(RENDER)
    hi_rgba = np.array(hi)
    hi_rgba[..., 3] = np.minimum(hi_rgba[..., 3], mask_arr)
    bg = Image.alpha_composite(bg, Image.fromarray(hi_rgba, "RGBA"))

    # 3. Dumbbell — extracted from the existing store icon, not re-drawn
    dumb = extract_dumbbell(src, RENDER)

    # 4. Soft drop shadow under the dumbbell, clipped to the squircle
    dumb_alpha = dumb.split()[3]
    shadow_src = Image.new("RGBA", (RENDER, RENDER), (0, 0, 0, 0))
    shadow_src.paste(Image.new("RGBA", (RENDER, RENDER), (0, 0, 0, 80)),
                     mask=dumb_alpha)
    shadow = shadow_src.filter(ImageFilter.GaussianBlur(radius=RENDER * 0.012))
    shadow_offset = Image.new("RGBA", (RENDER, RENDER), (0, 0, 0, 0))
    shadow_offset.paste(shadow, (0, int(RENDER * 0.008)))
    sh = np.array(shadow_offset)
    sh[..., 3] = np.minimum(sh[..., 3], mask_arr)
    bg = Image.alpha_composite(bg, Image.fromarray(sh, "RGBA"))

    # 5. Dumbbell on top, also clipped to the squircle so nothing spills out
    dumb_arr = np.array(dumb)
    dumb_arr[..., 3] = np.minimum(dumb_arr[..., 3], mask_arr)
    bg = Image.alpha_composite(bg, Image.fromarray(dumb_arr, "RGBA"))

    # 6. Downsample to 1024x1024
    out = bg.resize((OUT_SIZE, OUT_SIZE), resample=Image.LANCZOS)
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT_PATH, "PNG", optimize=True)
    print(f"wrote {OUT_PATH} ({OUT_SIZE}x{OUT_SIZE})")


if __name__ == "__main__":
    main()
