#!/usr/bin/env python3
"""Builds the README animation from the Debug preview renderer's frames.

    Ferry --render-previews <dir> --transparent --gif -AppleLanguages "(en)"
    python3 scripts/make-gif.py <dir>/gif docs/assets/readme/demo-en.gif

The renderer draws the switcher once with no selection (base.png) and once
per selected tile (sel-N.png). Here the selection ring slides between tiles on
the same critically damped spring the app uses, and the panel opens and
closes on the app's presentation spring.
"""
import math
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

FPS = 30
OUT_WIDTH = 960
CORAL = (143, 136, 129)  # the ring colour (pebble grey)

frames_dir, out = Path(sys.argv[1]), Path(sys.argv[2])
base = Image.open(frames_dir / 'base.png').convert('RGBA')
sel = {}
for path in sorted(frames_dir.glob('sel-*.png')):
    sel[int(path.stem.split('-')[1])] = Image.open(path).convert('RGBA')
W, H = base.size


def backdrop():
    """A warm, quiet wallpaper with two soft windows behind the panel."""
    img = Image.new('RGBA', (W, H))
    top, bottom = (247, 222, 204), (226, 170, 150)
    draw = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        draw.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,))
    shapes = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(shapes)
    d.rounded_rectangle([W * 0.08, H * 0.12, W * 0.48, H * 0.86], 36, fill=(255, 251, 246, 150))
    d.rounded_rectangle([W * 0.55, H * 0.2, W * 0.93, H * 0.92], 36, fill=(255, 251, 246, 120))
    return Image.alpha_composite(img, shapes.filter(ImageFilter.GaussianBlur(18)))


def ring_box(index):
    """Outer edge of the coral ring, found where the selected frame turns coral."""
    diff = ImageChops.difference(sel[index], base).convert('L').point(lambda v: 255 if v > 24 else 0)
    px, mask = sel[index].load(), diff.load()
    xs, ys = [], []
    left, upper, right, lower = diff.getbbox()
    for y in range(upper, lower):
        for x in range(left, right):
            if mask[x, y]:
                r, g, b, _ = px[x, y]
                if abs(r - CORAL[0]) < 24 and abs(g - CORAL[1]) < 24 and abs(b - CORAL[2]) < 24:
                    xs.append(x)
                    ys.append(y)
    return [min(xs), min(ys), max(xs), max(ys)]


class Spring:
    """Same model as the app: response (s) and damping ratio, from the current value and velocity."""

    def __init__(self, value):
        self.value, self.target, self.velocity = value, value, 0.0

    def step(self, dt, response, damping=1.0):
        stiffness = (2 * math.pi / response) ** 2
        friction = 4 * math.pi * damping / response
        for _ in range(8):
            h = dt / 8
            self.velocity += (-stiffness * (self.value - self.target) - friction * self.velocity) * h
            self.value += self.velocity * h


wall = backdrop()
frames = []


def emit(img, count=1):
    frames.extend([img] * count)


def panel(img, scale, opacity):
    layer = img
    if scale != 1:
        size = (round(W * scale), round(H * scale))
        layer = img.resize(size, Image.LANCZOS)
        canvas = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        canvas.paste(layer, ((W - size[0]) // 2, (H - size[1]) // 2))
        layer = canvas
    if opacity < 1:
        alpha = layer.getchannel('A').point(lambda a: int(a * opacity))
        layer = layer.copy()
        layer.putalpha(alpha)
    return Image.alpha_composite(wall, layer)


def present(img, opening):
    s = Spring(0.0 if opening else 1.0)
    s.target = 1.0 if opening else 0.0
    for _ in range(int(FPS * 0.45)):
        s.step(1 / FPS, 0.28)
        p = min(max(s.value, 0), 1)
        emit(panel(img, 0.94 + 0.06 * p, p))


def ring_frame(box):
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle(box, radius=32, outline=CORAL + (255,), width=4)
    return Image.alpha_composite(Image.alpha_composite(wall, base), layer)


def slide(a, b):
    box_a, box_b = ring_box(a), ring_box(b)
    springs = [Spring(v) for v in box_a]
    for spring, target in zip(springs, box_b):
        spring.target = target
    for _ in range(int(FPS * 0.32)):
        for spring in springs:
            spring.step(1 / FPS, 0.2)
        emit(ring_frame([spring.value for spring in springs]))
    # Settle into the real selected frame (card fill, bold caption).
    end = Image.alpha_composite(wall, sel[b])
    last = ring_frame(box_b)
    for t in (0.35, 0.7):
        emit(Image.blend(last, end, t))


emit(wall, int(FPS * 0.6))
present(sel[1], opening=True)
emit(Image.alpha_composite(wall, sel[1]), int(FPS * 0.7))
for a, b in [(1, 2), (2, 3), (3, 4)]:
    slide(a, b)
    emit(Image.alpha_composite(wall, sel[b]), int(FPS * 0.55))
present(sel[4], opening=False)
emit(wall, int(FPS * 0.5))

with tempfile.TemporaryDirectory() as tmp:
    height = round(H * OUT_WIDTH / W) // 2 * 2
    for i, frame in enumerate(frames):
        frame.convert('RGB').resize((OUT_WIDTH, height), Image.LANCZOS).save(f'{tmp}/f{i:04d}.png')
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-framerate', str(FPS), '-i', f'{tmp}/f%04d.png',
                    '-vf', 'split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle',
                    '-loop', '0', str(out)], check=True)
print(f'{out}: {len(frames)} frames, {out.stat().st_size // 1024} KB')
