"""Create an original seamless camouflage weave; requires Pillow."""
from pathlib import Path
import random
import math
from PIL import Image, ImageDraw, ImageFilter

rng = random.Random(39412)
size = 512
image = Image.new('RGB', (size, size), '#68664b')
draw = ImageDraw.Draw(image)
for color in ['#454c36', '#807356', '#393d30']:
    for _ in range(34):
        x, y = rng.randrange(size), rng.randrange(size)
        width, height = rng.randrange(18, 52), rng.randrange(9, 25)
        phase = rng.random() * math.tau
        points = []
        for j in range(40):
            angle = j * math.tau / 40
            radius = 1 + 0.2 * math.sin(angle * 3 + phase) + 0.13 * math.cos(angle * 5 - phase)
            points.append((x + math.cos(angle) * width * radius, y + math.sin(angle) * height * radius))
        for dx in [-size, 0, size]:
            for dy in [-size, 0, size]:
                draw.polygon([(px + dx, py + dy) for px, py in points], fill=color)
image = image.filter(ImageFilter.GaussianBlur(0.7))
pixels = image.load()
for y in range(size):
    for x in range(size):
        weave = (3 if x % 3 == 0 else -1) + (2 if y % 3 == 0 else -1) + rng.randrange(-3, 4)
        pixels[x, y] = tuple(max(0, min(255, c + weave)) for c in pixels[x, y])
image.save(Path(__file__).resolve().parents[1] / 'client/assets/realism/uniform.png')
