"""Pair real captures only when their recorded cameras match exactly."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--before", type=Path, required=True)
parser.add_argument("--after", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
poses = ("road-horizon", "repair-shelter-entrance", "terrain-wide")
records = [
    {row["name"]: row for row in json.loads((folder / "environment-camera-poses.json").read_text())}
    for folder in (args.before, args.after)
]
args.output.mkdir(parents=True, exist_ok=True)
evidence = []
for pose in poses:
    if records[0][pose] != records[1][pose]:
        raise ValueError(f"Camera mismatch: {pose}")
    paths = [folder / f"{pose}.png" for folder in (args.before, args.after)]
    images = [Image.open(path).convert("RGB") for path in paths]
    if images[0].size != images[1].size:
        raise ValueError(f"Resolution mismatch: {pose}")
    width, height = images[0].size
    canvas = Image.new("RGB", (width * 2, height + 32), "#182028")
    draw = ImageDraw.Draw(canvas)
    for index, image in enumerate(images):
        canvas.paste(image, (index * width, 32))
        draw.text((index * width + 12, 10), f"{'BEFORE' if index == 0 else 'AFTER'}: {pose}", fill="white")
    target = args.output / f"{pose}-comparison.png"
    canvas.save(target)
    evidence.append({
        "pose": pose, "camera_match": True, "camera": records[1][pose],
        "comparison": str(target),
        "sources_sha256": {str(path): hashlib.sha256(path.read_bytes()).hexdigest() for path in paths},
    })
(args.output / "camera-comparison.json").write_text(json.dumps(evidence, indent=2) + "\n")
