# Skill: Icon Palette Remap (Pillow + NumPy)

## When to use
Need to regenerate app icon PNGs with different colours (e.g. light→dark mode, rebrand) without re-exporting from a design tool.

## How it works
Express each source pixel as a barycentric blend of N palette colours, then re-map to N new colours. Anti-aliased edge pixels blend smoothly because they're naturally interpolated between the palette entries.

## Template

```python
import numpy as np
from PIL import Image

def remap_colors(img: Image.Image, old: tuple, new: tuple) -> Image.Image:
    """
    old / new: tuples of (N,) shape-3 numpy arrays (one per palette colour).
    Preserves anti-aliasing via barycentric decomposition.
    """
    src = np.array(img.convert("RGB"), dtype=float)
    h, w, _ = src.shape
    flat = src.reshape(-1, 3)
    old_mat = np.stack(old, axis=0)   # (N, 3)
    new_mat = np.stack(new, axis=0)

    A = np.vstack([old_mat.T, np.ones((1, len(old)))])  # (4, N)
    Apinv = np.linalg.pinv(A)                            # (N, 4)
    b = np.hstack([flat, np.ones((flat.shape[0], 1))])  # (P, 4)
    weights = b @ Apinv.T                                # (P, N)
    weights = np.clip(weights, 0, None)
    weights /= weights.sum(axis=1, keepdims=True).clip(1e-9, None)

    result = weights @ new_mat
    result = np.clip(result, 0, 255).reshape(h, w, 3).astype(np.uint8)
    return Image.fromarray(result, "RGB")
```

## iOS 18 adaptive icon entries (Contents.json)
```json
{
  "filename": "AppIcon-180.png",
  "idiom": "iphone", "scale": "3x", "size": "60x60"
},
{
  "appearances": [{"appearance": "luminosity", "value": "dark"}],
  "filename": "AppIcon-Dark-180.png",
  "idiom": "iphone", "scale": "3x", "size": "60x60"
}
```
Add a sibling entry with `appearances` for every existing size slot. Fallback to default on iOS < 18.

## Contrast targets for dark icon
- Each half vs app bg: ≥ 3:1  
- Two halves vs each other: ≥ 3:1  

## Gotchas
- `*.png` is gitignored in this repo — use `git add -f` to force-track icon PNGs.
- `swift build` on macOS will always fail with `no such module 'UIKit'`; validate icon JSON with `python3 -c "import json; json.load(...)"` instead.
