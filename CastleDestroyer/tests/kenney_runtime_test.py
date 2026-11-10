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
    def _make_sources(self, root: Path, inside_project: bool = True):
        vendor = root / "assets" / "vendor" if inside_project else root / "downloaded_sources"
        castle = vendor / "kenney-castle-kit"
        ui_pack = vendor / "kenney-ui-pack"
        retro = vendor / "kenney-retro-medieval-kit"
        avramania = vendor / "avramania-free"
        models = castle / "Models" / "GLB format"
        ui = ui_pack / "PNG" / "Blue" / "Default"
        retro_models = retro / "Models" / "GLB format"
        models.mkdir(parents=True)
        ui.mkdir(parents=True)
        retro_models.mkdir(parents=True)
        avramania.mkdir(parents=True)
        (castle / "License.txt").write_text(
            "License: Creative Commons Zero (CC0)", encoding="utf-8"
        )
        (ui_pack / "License.txt").write_text(
            "License: Creative Commons Zero (CC0)", encoding="utf-8"
        )
        (retro / "License.txt").write_text("License: Creative Commons Zero (CC0)", encoding="utf-8")
        (avramania / "License.txt").write_text("License: Creative Commons Zero (CC0)", encoding="utf-8")
        (avramania / "mdvl_nature_boulder_01.glb").write_bytes(b"avramania-glb")
        for name in module.RETRO_MODEL_FILES:
            (retro_models / name).write_bytes(b"retro-glb")
        for name in module.MODEL_FILES:
            (models / name).write_bytes(b"glb-test")
        for name in module.UI_FILES:
            (ui / name).write_bytes(b"png-test")
        return castle, ui_pack

    def test_stages_models_ui_and_both_licenses(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._make_sources(root)
            destination = module.stage_runtime(root)
            self.assertEqual(len(list((destination / "models").glob("*.glb"))), 10)
            self.assertEqual(len(list((destination / "models" / "retro").glob("*.glb"))), len(module.RETRO_MODEL_FILES))
            self.assertEqual(len(list((destination / "ui").glob("*.png"))), 3)
            self.assertTrue((destination / "models" / "retro" / "Textures").is_dir())
            self.assertTrue((destination / "licenses" / "castle-kit-License.txt").is_file())
            self.assertTrue((destination / "licenses" / "ui-pack-License.txt").is_file())
            self.assertTrue((destination / "licenses" / "retro-medieval-kit-License.txt").is_file())
            self.assertTrue((destination / "licenses" / "avramania-cc0-License.txt").is_file())
            metadata = json.loads((destination / "SOURCE_METADATA.json").read_text())
            self.assertEqual(metadata["license"], "CC0 1.0")

    def test_stages_from_external_sources_without_copying_full_packs_into_project(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp) / "godot-project"
            root.mkdir()
            castle, ui_pack = self._make_sources(Path(tmp), inside_project=False)
            retro = Path(tmp) / "downloaded_sources" / "kenney-retro-medieval-kit"
            (retro / "Models" / "GLB format").mkdir(parents=True, exist_ok=True)
            (retro / "License.txt").write_text("CC0", encoding="utf-8")
            for name in module.RETRO_MODEL_FILES:
                (retro / "Models" / "GLB format" / name).write_bytes(b"retro-glb")
            avramania = root / "assets" / "vendor" / "avramania-free"
            avramania.mkdir(parents=True)
            (avramania / "License.txt").write_text("CC0", encoding="utf-8")
            (avramania / "mdvl_nature_boulder_01.glb").write_bytes(b"avramania-glb")
            destination = module.stage_runtime(root, castle, ui_pack, retro)
            self.assertTrue((destination / "models" / "wall.glb").is_file())
            self.assertTrue((destination / "ui" / "button_rectangle_depth_flat.png").is_file())
            self.assertFalse((root / "assets/vendor/kenney-castle-kit").exists())
            self.assertFalse((root / "assets/vendor/kenney-ui-pack").exists())
            self.assertEqual(len(list((destination / "models").rglob("*.glb"))), 18)

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
