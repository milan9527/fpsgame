"""Generate deterministic, seamless surface textures (requires Pillow)."""
from pathlib import Path
import random
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / 'client/assets/surfaces'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(['soil', 'concrete', 'asphalt', 'stone']):
        rng = random.Random(7400 + index)
        grids = [(n, [[rng.random() for _ in range(n)] for _ in range(n)]) for n in [4, 16, 64]]
        pixels = []
        for y in range(256):
            for x in range(256):
                noise = 0.0
                for (n, grid), amplitude in zip(grids, [30, 18, 9]):
                    u, v = x * n / 256, y * n / 256
                    ix, iy = int(u), int(v)
                    a, b = u - ix, v - iy
                    a, b = a*a*(3-2*a), b*b*(3-2*b)
                    top = grid[iy % n][ix % n] * (1-a) + grid[iy % n][(ix+1) % n] * a
                    bottom = grid[(iy+1) % n][ix % n] * (1-a) + grid[(iy+1) % n][(ix+1) % n] * a
                    noise += ((top*(1-b) + bottom*b) - 0.5) * amplitude
                grain = rng.gauss(0, 7 if name in ['soil', 'asphalt'] else 3)
                value = int(max(100, min(255, 213 + noise + grain)))
                pixels.append((value, value, value))
        image = Image.new('RGB', (256, 256))
        image.putdata(pixels)
        image.save(OUT / (name + '.png'), optimize=True)
        print(name)


if __name__ == '__main__':
    main()
