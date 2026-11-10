from __future__ import annotations

import tempfile
import unittest
import zipfile
from pathlib import Path

import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from stage_gobkit_runtime import stage


class GobkitRuntimeStagingTests(unittest.TestCase):
    def make_archive(self, path: Path, members: dict[str, bytes]) -> None:
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name, content in members.items():
                archive.writestr(name, content)

    def test_stages_only_two_models_and_keeps_license_and_texture(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive = root / "gobkit.zip"
            self.make_archive(archive, {
                "LICENSE": b"CC0 1.0 Universal",
                "models/bee.glb": b"bee-model",
                "models/dragonfly.glb": b"dragonfly-model",
                "models/ant.glb": b"ant-model",
                "Texture001.png": b"texture",
            })
            output = root / "runtime"
            copied = stage(archive, output, 2)
            self.assertEqual(len(copied), 2)
            self.assertTrue((output / "bee.glb").is_file())
            self.assertTrue((output / "dragonfly.glb").is_file())
            self.assertFalse((output / "ant.glb").exists())
            self.assertTrue((output / "Texture001.png").is_file())
            self.assertTrue((output / "LICENSE").is_file())

    def test_rejects_path_traversal(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive = root / "unsafe.zip"
            self.make_archive(archive, {
                "LICENSE": b"CC0 1.0 Universal",
                "../escape.glb": b"bad",
            })
            with self.assertRaises(ValueError):
                stage(archive, root / "runtime", 2)

    def test_rejects_missing_cc0_license(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            archive = root / "wrong-license.zip"
            self.make_archive(archive, {
                "LICENSE": b"All rights reserved",
                "models/bug.glb": b"model",
            })
            with self.assertRaises(ValueError):
                stage(archive, root / "runtime", 2)


if __name__ == "__main__":
    unittest.main()
