#!/usr/bin/env python3
"""Measures an app icon's mark against the Warhound sizing brief.

    python3 tools/measure_icon.py path/to/icon-1024.png [more.png ...]

The mark is every pixel that is clearly brighter than the dark tile (or, on a transparent icon,
every opaque pixel). Reports the mark's span (the wider of its width and height, as a share of the
canvas), its stroke width (its most common thickness), and how far
its centre sits from the canvas centre. Targets: span 74% ±2, stroke 10% ±1, centre within ±1.5%.
Needs Pillow, NumPy and SciPy (pip3 install pillow numpy scipy).
"""
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SPAN, SPAN_TOL = 74.0, 2.0
STROKE, STROKE_TOL = 10.0, 1.0
CENTRE_TOL = 1.5


def mark_mask(img: Image.Image) -> np.ndarray:
    rgba = np.asarray(img.convert("RGBA")).astype(int)
    alpha = rgba[..., 3]
    if (alpha < 250).mean() > 0.2:  # transparent background: dark appearance
        return alpha > 128
    rgb = rgba[..., :3]
    # The tile tops out near #2D plus a faint glow; the mark's darkest gradient end is far brighter.
    return rgb.max(axis=2) > 100


def thickness(mask: np.ndarray) -> float:
    """Typical stroke width in pixels. Every point on a stroke's centre line is half the stroke
    width from the nearest edge, so the most common centre-line distance, doubled, is the stroke.
    Dots only add a few centre points, so they don't sway it."""
    dist = ndimage.distance_transform_edt(mask)
    peaks = (dist == ndimage.maximum_filter(dist, size=3)) & (dist >= 4)
    values = np.round(dist[peaks] * 2).astype(int)
    return float(np.bincount(values).argmax()) if values.size else 0.0


def measure(path: str) -> bool:
    img = Image.open(path)
    w, h = img.size
    mask = mark_mask(img)
    ys, xs = np.nonzero(mask)
    if len(xs) == 0:
        print(f"{path}: no mark found")
        return False
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    span = max(x1 - x0, y1 - y0) / w * 100
    stroke = thickness(mask) / w * 100
    dx = ((x0 + x1) / 2 - w / 2) / w * 100
    dy = ((y0 + y1) / 2 - h / 2) / h * 100

    def verdict(ok: bool) -> str:
        return "OK" if ok else "ADJUST"

    ok_span = abs(span - SPAN) <= SPAN_TOL
    ok_stroke = abs(stroke - STROKE) <= STROKE_TOL
    ok_centre = abs(dx) <= CENTRE_TOL and abs(dy) <= CENTRE_TOL
    print(path)
    print(f"  mark span   {span:.1f}%   target {SPAN:.0f}% ±{SPAN_TOL:.0f}%   {verdict(ok_span)}")
    print(f"  stroke      {stroke:.1f}%   target {STROKE:.0f}% ±{STROKE_TOL:.0f}%   {verdict(ok_stroke)}")
    print(f"  off-centre  x {dx:+.1f}%, y {dy:+.1f}%   target within ±{CENTRE_TOL}%   {verdict(ok_centre)}")
    return ok_span and ok_stroke and ok_centre


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    results = [measure(p) for p in sys.argv[1:]]
    sys.exit(0 if all(results) else 1)
