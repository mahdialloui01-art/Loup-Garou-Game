#!/usr/bin/env python3
"""Decode and safely stage the minimal Kenney CC0 runtime asset bundle."""
from __future__ import annotations

import base64
import hashlib
import io
import json
import re
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath

SCRIPT = Path(__file__).resolve()
PROJECT_ROOT = SCRIPT.parents[1]
DEFAULT_SOURCE = PROJECT_ROOT / "vendor_sources" / "kenney-runtime-selected.zip.base64"
DESTINATION = PROJECT_ROOT / "assets" / "vendor" / "kenney-runtime"
MAX_B64_BYTES = 256_000
MAX_EXPANDED_BYTES = 32 * 1024 * 1024
MAX_FILES = 20

ALLOWED_FILES = {
    "LICENSES/CastleKit-License.txt",
    "LICENSES/UIPack-License.txt",
    "models/wall.glb",
    "ui/button_rectangle_depth_flat.png",
}
LICENSE_FILES = {
    "LICENSES/CastleKit-License.txt",
    "LICENSES/UIPack-License.txt",
}

def fail(message: str) -> None:
    raise SystemExit(f"Kenney runtime import failed: {message}")

def main() -> int:
    source = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else DEFAULT_SOURCE
    if not source.is_file():
        fail(f"missing bundle: {source}")
    encoded = source.read_bytes()
    if len(encoded) > MAX_B64_BYTES:
        fail("base64 bundle exceeds size limit")
    if not re.fullmatch(rb"[A-Za-z0-9+/=\r\n]+", encoded):
        fail("bundle contains invalid base64 characters")
    try:
        archive = base64.b64decode(encoded, validate=True)
    except Exception as exc:
        fail(f"invalid base64 data: {exc}")

    archive_hash = hashlib.sha256(archive).hexdigest()
    staging = DESTINATION.with_name("kenney-runtime-staging")
    if staging.exists():
        import shutil
        shutil.rmtree(staging)
    staging.mkdir(parents=True, exist_ok=True)

    seen: set[str] = set()
    total_size = 0
    try:
        with zipfile.ZipFile(io.BytesIO(archive), "r") as bundle:
            entries = [item for item in bundle.infolist() if not item.is_dir()]
            if len(entries) > MAX_FILES:
                fail("archive contains too many files")
            for item in entries:
                name = item.filename.replace("\\", "/")
                path = PurePosixPath(name)
                mode = item.external_attr >> 16
                if path.is_absolute() or ".." in path.parts or stat.S_ISLNK(mode):
                    fail(f"unsafe archive path: {name}")
                if name not in ALLOWED_FILES or name in seen:
                    fail(f"unexpected or duplicate file: {name}")
                seen.add(name)
                total_size += item.file_size
                if total_size > MAX_EXPANDED_BYTES:
                    fail("archive expanded size exceeds limit")
                target = staging.joinpath(*path.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(bundle.read(item))
    except zipfile.BadZipFile:
        fail("decoded payload is not a valid ZIP archive")

    if seen != ALLOWED_FILES:
        fail(f"bundle contents mismatch: missing {sorted(ALLOWED_FILES - seen)}")
    for license_path in LICENSE_FILES:
        contents = staging.joinpath(*PurePosixPath(license_path).parts).read_text(
            encoding="utf-8", errors="replace"
        )
        if "Creative Commons Zero" not in contents or "CC0" not in contents:
            fail(f"CC0 license text missing or invalid: {license_path}")

    if DESTINATION.exists():
        import shutil
        shutil.rmtree(DESTINATION)
    staging.rename(DESTINATION)
    metadata = {
        "source": "Kenney Castle Kit 2.0 + UI Pack 2.0",
        "license": "CC0 1.0 Universal",
        "sources": [
            "https://kenney.nl/assets/castle-kit",
            "https://kenney.nl/assets/ui-pack",
        ],
        "archive_sha256": archive_hash,
        "runtime_files": sorted(ALLOWED_FILES),
        "note": "Curated runtime subset. Original source archives were supplied by the project owner.",
    }
    (DESTINATION / "SOURCE_METADATA.json").write_text(
        json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
    )
    print(f"Imported {len(ALLOWED_FILES)} verified CC0 runtime files to {DESTINATION}")
    print(f"Archive SHA256: {archive_hash}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
