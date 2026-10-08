"""Device Farm post-test collector; diagnostic evidence only."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

output = Path(os.environ["DEVICEFARM_LOG_DIR"])
archive = output / "shader-sources.tar"
status = {"diagnostic_only": True, "acceptance": False}
try:
    # adb shell can read the app's external files without run-as/debuggable.
    # Retain failures and partial output for diagnosis; never mark them complete.
    with archive.open("xb") as data, (output / "shader-sources.stderr").open("xb") as errors:
        result = subprocess.run(
            ["adb", "exec-out", "tar", "-C",
             "/storage/emulated/0/Android/data/org.ironmeridian.game/files/shader-probe",
             "-cf", "-", "."],
            stdout=data, stderr=errors, timeout=120, check=False,
        )
    status["returncode"] = result.returncode
    status["bytes"] = archive.stat().st_size
    with archive.open("rb") as source:
        status["sha256"] = hashlib.file_digest(source, "sha256").hexdigest()
    status["collected"] = result.returncode == 0 and status["bytes"] > 0
except Exception as error:
    status.update(collected=False, error=str(error))
finally:
    with (output / "shader-sources-collection.json").open("x") as stream:
        json.dump(status, stream, indent=2)
        stream.write("\n")
if not status["collected"]:
    raise SystemExit("Shader source collection failed; inspect retained status/stderr.")
