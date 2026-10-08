"""Build the diagnostic shell injector; never packages or changes the game."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import zipfile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sdk", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    # Exclusive creation protects earlier evidence snapshots from overwrite.
    if args.output.exists():
        raise FileExistsError(args.output)
    with tempfile.TemporaryDirectory(prefix="iron-touch-") as temporary:
        work = Path(temporary)
        source = Path(__file__).parent / "android_touch/MultiTouch.java"
        platform = args.sdk / "platforms/android-35/android.jar"
        subprocess.run(["javac", "-source", "8", "-target", "8", "-classpath",
                        str(platform), "-d", str(work), str(source)], check=True)
        subprocess.run([str(args.sdk / "build-tools/35.0.0/d8"), "--lib",
                        str(platform), "--min-api", "26", "--output", str(work),
                        str(work / "MultiTouch.class")], check=True)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(args.output, "x", zipfile.ZIP_DEFLATED) as archive:
            archive.write(work / "classes.dex", "classes.dex")


if __name__ == "__main__":
    main()
