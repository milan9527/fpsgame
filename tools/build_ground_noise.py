"""Bake the service-ground value-noise lattice as linear data (not albedo)."""
from pathlib import Path

import numpy as np
from PIL import Image


def main():
    size = 1024
    y, x = np.mgrid[-size // 2:size // 2, -size // 2:size // 2]
    q = np.stack((x, y, x), axis=-1).astype(np.float32)
    q *= np.float32(0.1031)
    q -= np.floor(q)
    q += np.sum(q * (q[..., [1, 2, 0]] + np.float32(33.33)), axis=-1)[..., None]
    value = (q[..., 0] + q[..., 1]) * q[..., 2]
    value -= np.floor(value)
    output = Path(__file__).resolve().parents[1] / "client/assets/realism/ground_noise.png"
    Image.fromarray(np.rint(value * 255).astype(np.uint8)).save(output)
    print(output)


if __name__ == "__main__":
    main()
