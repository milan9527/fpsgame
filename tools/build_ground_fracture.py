"""Bake periodic soil-clod distance, identity and relief as linear RGBA data."""
from pathlib import Path

import numpy as np
from PIL import Image


def hash_cells(points):
    q = points[..., [0, 1, 0]].astype(np.float32) * np.float32(0.1031)
    q -= np.floor(q)
    q += np.sum(q * (q[..., [1, 2, 0]] + np.float32(33.33)), axis=-1)[..., None]
    value = (q[..., 0] + q[..., 1]) * q[..., 2]
    return value - np.floor(value)


def main():
    cells, size = 32, 1024
    y, x = np.mgrid[:size, :size]
    sample = (np.stack((x, y), axis=-1) + 0.5) * (cells / size)
    cell = np.floor(sample)
    uv = sample - cell
    nearest = np.full((size, size), 8.0)
    second = nearest.copy()
    direction = np.zeros((size, size, 2))
    seed = np.zeros((size, size))
    for dx in range(-1, 2):
        for dy in range(-1, 2):
            offset = np.array((dx, dy))
            # Wrap seed coordinates only; neighbour positions remain continuous.
            identity = (cell + offset) % cells
            jitter = np.stack(
                (hash_cells(identity + 31), hash_cells(identity - 19)), axis=-1
            )
            delta = offset + jitter * 0.74 + 0.13 - uv
            distance = np.sum(delta * delta, axis=-1)
            closer = distance < nearest
            second = np.where(closer, nearest, np.minimum(second, distance))
            nearest = np.minimum(nearest, distance)
            direction = np.where(closer[..., None], delta, direction)
            seed = np.where(closer, hash_cells(identity), seed)
    data = np.concatenate(
        ((np.sqrt(second) - np.sqrt(nearest))[..., None],
         seed[..., None], direction * 0.5 + 0.5), axis=-1
    )
    output = Path(__file__).resolve().parents[1] / "client/assets/realism/ground_fracture.png"
    Image.fromarray(np.rint(np.clip(data, 0, 1) * 255).astype(np.uint8)).save(output)
    print(output)


if __name__ == "__main__":
    main()
