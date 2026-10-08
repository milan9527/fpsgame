"""Bake illumination-free asphalt before mip generation (Pillow + numpy)."""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / "client/assets/realism/asphalt_albedo.jpg"
destination = source.with_name("asphalt_surface.png")
srgb = np.asarray(Image.open(source).convert("RGB"), dtype=np.float32) / 255
linear = np.where(srgb <= .04045, srgb / 12.92, ((srgb + .055) / 1.055) ** 2.4)
# Periodic padding keeps the illumination estimate continuous at repeat seams.
illumination = np.empty_like(linear)
for channel in range(3):
    tiled = np.tile(linear[:, :, channel], (3, 3))
    image = Image.fromarray(np.uint8(np.clip(tiled, 0, 1) * 255))
    blurred = np.asarray(image.filter(ImageFilter.GaussianBlur(24)), dtype=np.float32) / 255
    h, w = linear.shape[:2]
    illumination[:, :, channel] = blurred[h:2*h, w:2*w]
surface = np.clip(linear / np.maximum(illumination, .015) * linear.mean(axis=(0, 1)), 0, 1)
encoded = np.where(surface <= .0031308, surface * 12.92, 1.055 * surface ** (1 / 2.4) - .055)
Image.fromarray(np.uint8(np.clip(encoded, 0, 1) * 255)).save(destination)
print(destination)
