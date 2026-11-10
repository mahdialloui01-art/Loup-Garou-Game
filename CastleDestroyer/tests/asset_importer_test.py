import importlib.util
import tempfile
import unittest
import zipfile
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "tools" / "import_kenney_assets.py"
spec = importlib.util.spec_from_file_location("asset_importer", MODULE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ImporterSafetyTests(unittest.TestCase):
    def test_rejects_path_traversal(self):
        with self.assertRaises(ValueError):
            module.safe_member_path("../escape.txt")

    def test_rejects_archive_without_cc0_license(self):
        with tempfile.TemporaryDirectory() as tmp:
            archive = Path(tmp) / "bad.zip"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("License.txt", "All rights reserved")
            with self.assertRaisesRegex(ValueError, "does not explicitly identify CC0"):
                module.import_pack("castle", archive, Path(tmp) / "outside")

    def test_extracts_full_pack_outside_project_when_requested(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            archive = root / "castle.zip"
            destination_root = root / "outside-source"
            with zipfile.ZipFile(archive, "w") as z:
                z.writestr("License.txt", "Creative Commons Zero (CC0)")
                z.writestr("Models/GLB format/wall.glb", b"glb-data")
                z.writestr("Models/FBX format/wall.fbx", b"fbx-data")
            destination = module.import_pack("castle", archive, destination_root)
            self.assertEqual(destination.parent, destination_root.resolve())
            self.assertTrue((destination / "Models/FBX format/wall.fbx").is_file())
            self.assertTrue((destination / "Models/GLB format/wall.glb").is_file())
            self.assertFalse((root / "project/assets/vendor/kenney-castle-kit").exists())


if __name__ == "__main__":
    unittest.main()
