"""
Generate a modern iOS-style marketing icon for Rep AI.

Reproduces the existing flat blue + white dumbbell concept, but in the
contemporary App Store style: squircle shape, rich blue gradient, subtle
top highlight for depth, and a crisp antialiased dumbbell glyph with a
faint drop shadow.

Output: 1024x1024 PNG at assets/images/app_icon_ios_marketing.png.

Run with:  py tool/generate_marketing_icon.py
"""

from __future__ import annotations
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT_SIZE = 1024
SUPERSAMPLE = 4                  # render at 4096px, downscale for AA
RENDER = OUT_SIZE * SUPERSAMPLE

# Modern-iOS blue gradient (roughly Tailwind blue-500 → blue-700, echoes the
# in-app accent #2563EB but with a richer top-to-bottom ramp).
TOP_COLOR = (59, 130, 246)        # #3B82F6
BOTTOM_COLOR = (29, 78, 216)      # #1D4ED8

# Squircle exponent — 5 is a good approximation of Apple's G2-continuous mask.
SQUIRCLE_N = 5.0

OUT_PATH = Path(__file__).resolve().parents[1] / "assets" / "images" / "app_icon_ios_marketing.png"


def squircle_alpha(size: int, n: float) -> np.ndarray:
    """Antialiased squircle alpha mask in range [0, 255]."""
    # Coordinate grid normalised to [-1, 1]
    xs = np.linspace(-1.0, 1.0, size)
    ys = np.linspace(-1.0, 1.0, size)
    x, y = np.meshgrid(xs, ys)
    # Signed distance-ish function: values < 1 are inside.
    d = np.power(np.abs(x), n) + np.power(np.abs(y), n)
    # Soft edge: fade from fully opaque to fully transparent across ~1 px.
    half_px = 1.0 / size
    # Convert `d` to an approximate signed distance by taking the n-th root.
    r = np.power(d, 1.0 / n)          # ≈ 1 on the squircle boundary
    alpha = np.clip((1.0 - r) / (2 * half_px), 0.0, 1.0)
    return (alpha * 255).astype(np.uint8)


def vertical_gradient(size: int, top_rgb, bottom_rgb) -> Image.Image:
    ts = np.linspace(0.0, 1.0, size)[:, None]              # (size, 1)
    top = np.array(top_rgb, dtype=np.float32)
    bot = np.array(bottom_rgb, dtype=np.float32)
    row = top + (bot - top) * ts                           # (size, 3)
    arr = np.broadcast_to(row[:, None, :], (size, size, 3)).astype(np.uint8)
    return Image.fromarray(arr, "RGB")


def top_highlight(size: int) -> Image.Image:
    """
    Subtle radial/linear top highlight to give the icon a touch of glassy
    depth (mirrors the gentle sheen on Apple's Fitness / Health icons).
    """
    # Radial centred well above the canvas, very soft.
    cx, cy = size / 2, -size * 0.35
    radius = size * 1.25
    xs = np.arange(size, dtype=np.float32)
    ys = np.arange(size, dtype=np.float32)
    x, y = np.meshgrid(xs, ys)
    d = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    t = np.clip(1.0 - d / radius, 0.0, 1.0) ** 2
    alpha = (t * 36).astype(np.uint8)                       # peak ~14% white
    white = np.ones((size, size, 3), dtype=np.uint8) * 255
    rgba = np.dstack([white, alpha])
    return Image.fromarray(rgba, "RGBA")


def rounded_rect(draw: ImageDraw.ImageDraw, xy, radius, fill):
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def draw_dumbbell(size: int) -> Image.Image:
    """
    White dumbbell on a transparent canvas, centred and ready to rotate.

    Horizontal layout (we rotate the whole layer afterwards):

        |=|===|=============|===|=|
        outer  inner  bar    inner outer
    """
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    cx = size / 2
    cy = size / 2

    # Tuning — all in units of `size` so this scales with SUPERSAMPLE.
    BAR_W = size * 0.40
    BAR_H = size * 0.095
    BAR_R = BAR_H * 0.5

    INNER_W = size * 0.072
    INNER_H = size * 0.285
    INNER_R = INNER_W * 0.32
    INNER_GAP_FROM_BAR = size * 0.018     # gap between bar end and inner plate

    OUTER_W = size * 0.062
    OUTER_H = size * 0.185
    OUTER_R = OUTER_W * 0.32
    OUTER_GAP = size * 0.022              # gap between inner and outer plates

    # Central bar
    rounded_rect(
        d,
        [cx - BAR_W / 2, cy - BAR_H / 2, cx + BAR_W / 2, cy + BAR_H / 2],
        radius=BAR_R,
        fill=(255, 255, 255, 255),
    )

    # Plates — mirrored left/right
    for sign in (-1, 1):
        bar_end_x = cx + sign * (BAR_W / 2)
        inner_cx = bar_end_x + sign * (INNER_GAP_FROM_BAR + INNER_W / 2)
        inner_xy = [
            inner_cx - INNER_W / 2, cy - INNER_H / 2,
            inner_cx + INNER_W / 2, cy + INNER_H / 2,
        ]
        rounded_rect(d, inner_xy, radius=INNER_R, fill=(255, 255, 255, 255))

        outer_cx = inner_cx + sign * (INNER_W / 2 + OUTER_GAP + OUTER_W / 2)
        outer_xy = [
            outer_cx - OUTER_W / 2, cy - OUTER_H / 2,
            outer_cx + OUTER_W / 2, cy + OUTER_H / 2,
        ]
        rounded_rect(d, outer_xy, radius=OUTER_R, fill=(255, 255, 255, 255))

    # Rotate the whole dumbbell -30° (clockwise) — matches the existing icon.
    # `expand=False` keeps the canvas centred on the original point.
    layer = layer.rotate(-30.0, resample=Image.BICUBIC, expand=False)
    return layer


def main():
    # Squircle-masked blue gradient background
    bg = vertical_gradient(RENDER, TOP_COLOR, BOTTOM_COLOR).convert("RGBA")
    mask_arr = squircle_alpha(RENDER, SQUIRCLE_N)
    bg.putalpha(Image.fromarray(mask_arr, "L"))

    # Top highlight (clipped to the squircle)
    hi = top_highlight(RENDER)
    # Clip highlight to the same squircle mask.
    hi_rgba = np.array(hi)
    hi_rgba[..., 3] = np.minimum(hi_rgba[..., 3], mask_arr)
    hi = Image.fromarray(hi_rgba, "RGBA")
    bg = Image.alpha_composite(bg, hi)

    # Dumbbell + soft drop shadow
    dumb = draw_dumbbell(RENDER)

    # Drop shadow: black silhouette of dumbbell, blurred + offset.
    shadow_src = Image.new("RGBA", (RENDER, RENDER), (0, 0, 0, 0))
    shadow_src.paste(Image.new("RGBA", (RENDER, RENDER), (0, 0, 0, 80)), mask=dumb.split()[3])
    shadow_blur = shadow_src.filter(ImageFilter.GaussianBlur(radius=RENDER * 0.012))
    # Offset the shadow slightly downward for a grounded feel.
    shadow_offset = Image.new("RGBA", (RENDER, RENDER), (0, 0, 0, 0))
    shadow_offset.paste(shadow_blur, (0, int(RENDER * 0.008)))
    # Clip shadow to the squircle so it doesn't extend past the icon edge.
    sh_rgba = np.array(shadow_offset)
    sh_rgba[..., 3] = np.minimum(sh_rgba[..., 3], mask_arr)
    shadow_offset = Image.fromarray(sh_rgba, "RGBA")

    bg = Image.alpha_composite(bg, shadow_offset)
    bg = Image.alpha_composite(bg, dumb)

    # Downsample to 1024x1024 with high-quality filter for crisp edges.
    out = bg.resize((OUT_SIZE, OUT_SIZE), resample=Image.LANCZOS)

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT_PATH, "PNG", optimize=True)
    print(f"wrote {OUT_PATH} ({OUT_SIZE}x{OUT_SIZE})")


if __name__ == "__main__":
    main()
