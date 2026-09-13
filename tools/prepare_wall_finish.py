"""Make a maintained plaster finish from the licensed scan, retaining its detail."""
from pathlib import Path
from PIL import Image, ImageEnhance

root = Path(__file__).resolve().parents[1] / "client/assets/realism"
with Image.open(root / "plaster_albedo.jpg") as image:
    image = ImageEnhance.Contrast(image.convert("RGB")).enhance(0.55)
    image = ImageEnhance.Color(image).enhance(0.70)
    image = ImageEnhance.Brightness(image).enhance(1.10)
    image.save(root / "plaster_painted.jpg", quality=95)
