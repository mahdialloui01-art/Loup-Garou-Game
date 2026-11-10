import json
import tempfile
import unittest
from pathlib import Path

MODULE = Path(__file__).resolve().parents[1] / "tools" / "stage_kenney_runtime.py"
import importlib.util
spec = importlib.util.spec_from_file_location("kenney_runtime", MODULE)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class KenneyRuntimeStageTests(unittest.TestCase):
    def _make_sources(self, root: Path) -> None:
        vendor = root / "assets" / "vendor"
        models = vendor / "kenney-castle-kit" / "Models" / "GLB format"
        ui = vendor / "kenney-ui-pack" / "PNG" / "Blue" / "Default"
        models.mkdir(parents=True)
        ui.mkdir(parents=True)
        (vendor / "kenney-castle-kit" / "License.txt").write_text(
            "License: Creative Commons Zero (CC0)", encoding="utf-8"
        )
        (vendor / "kenney-ui-pack" / "License.txt").write_text(
            "License: Creative Commons Zero (CC0)", encoding="utf-8"
        )
        for name in module.MODEL_FILES:
            (models / name).write_bytes(b"glb-test")
        for name in module.UI_FILES:
            (ui / name).write_bytes(b"png-test")

    def test_stages_models_ui_and_both_licenses(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._make_sources(root)
            destination = module.stage_runtime(root)
            self.assertEqual(len(list((destination / "models").glob("*.glb"))), 10)
            self.assertEqual(len(list((destination / "ui").glob("*.png"))), 3)
            self.assertTrue((destination / "licenses" / "castle-kit-License.txt").is_file())
            self.assertTrue((destination / "licenses" / "ui-pack-License.txt").is_file())
            metadata = json.loads((destination / "SOURCE_METADATA.json").read_text())
            self.assertEqual(metadata["license"], "CC0 1.0")

    def test_rejects_missing_model(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._make_sources(root)
            (root / "assets/vendor/kenney-castle-kit/Models/GLB format/wall.glb").unlink()
            with self.assertRaisesRegex(FileNotFoundError, "wall.glb"):
                module.stage_runtime(root)

    def test_rejects_non_cc0_license(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._make_sources(root)
            (root / "assets/vendor/kenney-ui-pack/License.txt").write_text(
                "All rights reserved", encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "CC0"):
                module.stage_runtime(root)


if __name__ == "__main__":
    unittest.main()
