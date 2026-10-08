import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "visual_probe", Path(__file__).resolve().parents[1] / "tools/android_visual_profile_probe.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


class ExecutableOwnershipTest(unittest.TestCase):
    def test_read_only_package_never_requires_chmod(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = root / "package"
            (bundle / "runtime").mkdir(parents=True)
            destination = root / "owned"
            destination.mkdir()
            sources = [bundle / "godot", bundle / "runtime/ld-linux-x86-64.so.2"]
            for source in sources:
                source.write_bytes(source.name.encode())
                source.chmod(0o444)
            original_chmod = Path.chmod

            def owned_chmod(path, mode, **kwargs):
                if path in sources:
                    raise PermissionError("package belongs to another user")
                return original_chmod(path, mode, **kwargs)

            with patch.object(Path, "chmod", owned_chmod):
                copies = probe.prepare_executables(bundle, destination)
            for source, target in zip(sources, copies):
                self.assertEqual(target.read_bytes(), source.read_bytes())
                self.assertEqual(target.stat().st_mode & 0o777, 0o700)
                self.assertEqual(source.stat().st_mode & 0o777, 0o444)
                self.assertNotEqual(source.stat().st_ino, target.stat().st_ino)


if __name__ == "__main__":
    unittest.main()
