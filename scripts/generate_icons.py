#!/usr/bin/env python3
"""
generate_icons.py — Regenerate AppIcon PNGs from a 1024x1024 source or template.

Produces:
  - Improved light-mode icons (pale mint → saturated #50C4A4)
  - New dark-mode icons  (dark bg, light sage, mid-green mint)

Usage:
  python3 scripts/generate_icons.py

Requires: Pillow (pip install pillow)
"""

import numpy as np
from PIL import Image
import os

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(REPO_ROOT, "EyePostureReminder/AppIcon.xcassets/AppIcon.appiconset")

# ── Original palette (light icon source) ────────────────────────────────────
ORIG_BG   = np.array([248, 244, 236], dtype=float)  # #F8F4EC
ORIG_SAGE = np.array([ 47, 111,  94], dtype=float)  # #2F6F5E
ORIG_MINT = np.array([238, 246, 241], dtype=float)  # #EEF6F1

# ── Target palettes ──────────────────────────────────────────────────────────
# Light-improved: keep bg + sage, replace barely-visible mint with #50C4A4
LIGHT_BG   = ORIG_BG.copy()
LIGHT_SAGE = ORIG_SAGE.copy()
LIGHT_MINT = np.array([ 80, 196, 164], dtype=float)  # #50C4A4

# Dark: deep-forest background; in dark mode the halves swap luminance —
# the sage half maps to the lighter #8ED2B1 (matches primaryRest dark),
# the mint/yang half maps to mid-green #2A6A52 (matches LogoYangMint dark).
# Contrast: sage vs mint 3.7:1, sage vs bg 10.4:1.
DARK_BG   = np.array([ 16,  23,  20], dtype=float)  # #101714
DARK_SAGE = np.array([142, 210, 177], dtype=float)  # #8ED2B1
DARK_MINT = np.array([ 42, 106,  82], dtype=float)  # #2A6A52

# ── Sizes required ───────────────────────────────────────────────────────────
SIZES = [40, 58, 60, 80, 87, 120, 180, 1024]


def remap_colors(img: Image.Image,
                 old: tuple, new: tuple) -> Image.Image:
    """
    Remap three palette colors in *img*, preserving anti-aliased blends.

    old / new are each (bg_arr, sage_arr, mint_arr) tuples of shape-(3,) arrays.
    """
    src = np.array(img.convert("RGB"), dtype=float)
    h, w, _ = src.shape
    flat = src.reshape(-1, 3)

    old_mat = np.stack(old, axis=0)   # (3, 3) — rows = colors
    new_mat = np.stack(new, axis=0)   # (3, 3)

    # Solve A @ w = px for barycentric weights w (sum-to-one constraint added).
    A = np.vstack([old_mat.T, np.ones((1, 3))])   # (4, 3)
    Apinv = np.linalg.pinv(A)                      # (3, 4)

    b = np.hstack([flat, np.ones((flat.shape[0], 1))])  # (N, 4)
    weights = b @ Apinv.T                               # (N, 3)

    # Clamp to [0,1] and renorm so edge/AA pixels stay smooth.
    weights = np.clip(weights, 0.0, None)
    w_sum = weights.sum(axis=1, keepdims=True)
    w_sum = np.where(w_sum < 1e-9, 1.0, w_sum)
    weights /= w_sum

    result = weights @ new_mat
    result = np.clip(result, 0, 255).reshape(h, w, 3).astype(np.uint8)
    return Image.fromarray(result, "RGB")


def make_icon_set(src_path: str, suffix: str,
                  old_palette: tuple, new_palette: tuple) -> None:
    """Generate all icon sizes for a given palette remap."""
    src = Image.open(src_path).convert("RGB")
    print(f"  Remapping colors for '{suffix}' icons…")
    remapped_1024 = remap_colors(src, old_palette, new_palette)

    for size in SIZES:
        if size == 1024:
            out = remapped_1024
        else:
            out = remapped_1024.resize((size, size), Image.LANCZOS)

        filename = f"AppIcon{suffix}-{size}.png"
        out_path = os.path.join(ICON_DIR, filename)
        out.save(out_path, "PNG", optimize=True)
        print(f"    ✓ {filename}")


def main():
    src_path = os.path.join(ICON_DIR, "AppIcon-1024.png")
    if not os.path.exists(src_path):
        raise FileNotFoundError(f"Source icon not found: {src_path}")

    print("Generating light-improved icons…")
    make_icon_set(
        src_path, suffix="",
        old_palette=(ORIG_BG, ORIG_SAGE, ORIG_MINT),
        new_palette=(LIGHT_BG, LIGHT_SAGE, LIGHT_MINT),
    )

    print("Generating dark-mode icons…")
    make_icon_set(
        src_path, suffix="-Dark",
        old_palette=(ORIG_BG, ORIG_SAGE, ORIG_MINT),
        new_palette=(DARK_BG, DARK_SAGE, DARK_MINT),
    )

    print("Done.")


if __name__ == "__main__":
    main()
