"""Build the code-native needle silhouette and its antialiased RGBA particle texture.

This creates a new geometric asset; it does not edit the generated v1 bitmap.
Usage: python scripts/build_fall_needle.py (requires Pillow).
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "art/vfx/fall"
SIZE, SCALE = 1024, 4
CURVES = [
    ((512, 32), (516, 180), (522, 365), (522, 512)),
    ((522, 512), (522, 659), (516, 844), (512, 992)),
    ((512, 992), (508, 844), (502, 659), (502, 512)),
    ((502, 512), (502, 365), (508, 180), (512, 32)),
]


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    path = "M512 32 " + " ".join(
        "C" + " ".join(f"{x} {y}" for x, y in points[1:]) for points in CURVES
    ) + " Z"
    (ROOT / "speed-needle-v2.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
        f'<path d="{path}" fill="#fff"/></svg>\n', encoding="utf-8"
    )
    polygon = []
    for points in CURVES:
        for i in range(257):
            t = i / 256
            weights = ((1-t)**3, 3*(1-t)**2*t, 3*(1-t)*t*t, t**3)
            polygon.append(tuple(SCALE * sum(w * p[a] for w, p in zip(weights, points)) for a in (0, 1)))
    alpha = Image.new("L", (SIZE*SCALE, SIZE*SCALE), 0)
    ImageDraw.Draw(alpha).polygon(polygon, fill=255)
    # White RGB even outside the silhouette avoids dark fringes under bilinear filtering.
    texture = Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 0))
    texture.putalpha(alpha.resize((SIZE, SIZE), Image.Resampling.LANCZOS))
    texture.save(ROOT / "speed-needle-v2.png", optimize=True)
    print("Created speed-needle-v2.svg and speed-needle-v2.png (1024 RGBA)")


if __name__ == "__main__":
    main()
