"""Build a vector-authored 4x4 flipbook: length collapses before stroke width.

Usage: python scripts/build_fall_flipbook.py (Pillow).
This rasterizes new SVG geometry; no existing bitmap is edited.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'art/vfx/fall'
LENGTHS = (0.72, 1, 1, .95, .84, .71, .58, .46, .35, .26, .19, .13, .085, .05, .025, 0)
CELL, SCALE = 256, 4


def main():
    alpha = Image.new('L', (1024 * SCALE, 1024 * SCALE), 0)
    draw = ImageDraw.Draw(alpha)
    shapes = []
    for i, factor in enumerate(LENGTHS):
        if not factor:
            continue
        cx, cy = (i % 4) * CELL + 128, (i // 4) * CELL + 128
        height, width = 236 * factor, 4.8 * (1 if i < 13 else .7)
        # Sharp ends and a solid middle: shortening must not turn the stroke into fog.
        points = []
        for sign, samples in ((1, range(129)), (-1, range(128, -1, -1))):
            for step in samples:
                t = step / 128
                profile = (4 * t * (1 - t)) ** .78
                points.append((cx + sign * width * .5 * profile, cy + (t - .5) * height))
        draw.polygon([(x*SCALE, y*SCALE) for x, y in points], fill=255)
        shapes.append('<polygon fill="white" points="' + ' '.join(f'{x:.4f},{y:.4f}' for x,y in points) + '"/>')
    ROOT.mkdir(parents=True, exist_ok=True)
    (ROOT / 'fall-stroke-flipbook-v3.svg').write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">' + ''.join(shapes) + '</svg>\n', encoding='utf-8')
    image = Image.new('RGBA', (1024, 1024), (255,255,255,0))
    image.putalpha(alpha.resize((1024,1024), Image.Resampling.LANCZOS))
    image.save(ROOT / 'fall-stroke-flipbook-v3.png', optimize=True)
    print('Built 16-frame flipbook, 1024 RGBA; fixed-width contraction')


if __name__ == '__main__':
    main()
