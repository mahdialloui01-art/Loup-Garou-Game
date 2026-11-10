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
                module.import_pack("castle", archive)


if __name__ == "__main__":
    unittest.main()
