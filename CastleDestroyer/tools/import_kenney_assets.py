#!/usr/bin/env python3
"""Safely extract official Kenney CC0 ZIP packs outside the Godot project.

Usage:
  python3 tools/import_kenney_assets.py castle /path/to/kenney_castle-kit.zip --destination-root /tmp/kenney-source
  python3 tools/import_kenney_assets.py ui /path/to/kenney_ui-pack.zip --destination-root /tmp/kenney-source

Only the optimized runtime selection is copied into the Godot project later.
The original archive and its full source pack remain outside the project tree.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import sys
import zipfile
from pathlib import Path, PurePosixPath

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DESTINATIONS = {
    "castle": ("kenney-castle-kit", "Kenney Castle Kit",
               "https://kenney-assets.itch.io/castle-kit"),
    "ui": ("kenney-ui-pack", "Kenney UI Pack",
           "https://kenney.nl/assets/ui-pack"),
}
MAX_TOTAL_BYTES = 100 * 1024 * 1024
MAX_FILES = 5000


def safe_member_path(name: str) -> PurePosixPath:
    path = PurePosixPath(name.replace("\\", "/"))
    if path.is_absolute() or not path.parts or any(p in ("", ".", "..") for p in path.parts):
        raise ValueError(f"Unsafe ZIP path: {name!r}")
    if path.parts[0].endswith(":"):
        raise ValueError(f"Drive path is not allowed: {name!r}")
    return path


def import_pack(kind: str, archive_path: Path, destination_root: Path | None = None) -> Path:
    if kind not in DESTINATIONS:
        raise ValueError(f"Unknown pack kind: {kind}")
    archive_path = archive_path.resolve(strict=True)
    if not zipfile.is_zipfile(archive_path):
        raise ValueError(f"Not a valid ZIP archive: {archive_path}")

    folder, title, source = DESTINATIONS[kind]
    root = Path(destination_root).resolve() if destination_root else PROJECT_ROOT / "assets" / "vendor"
    root.mkdir(parents=True, exist_ok=True)
    destination = root / folder
    staging = destination.with_name(destination.name + ".staging")
    if staging.exists():
        shutil.rmtree(staging)
    staging.mkdir(parents=True)

    try:
        with zipfile.ZipFile(archive_path) as archive:
            members = [m for m in archive.infolist() if not m.is_dir()]
            if len(members) > MAX_FILES:
                raise ValueError(f"Archive contains too many files ({len(members)})")
            total = sum(m.file_size for m in members)
            if total > MAX_TOTAL_BYTES:
                raise ValueError(f"Archive expands beyond {MAX_TOTAL_BYTES} bytes")
            license_members = [m for m in members
                               if PurePosixPath(m.filename.replace("\\", "/")).name.lower()
                               in ("license.txt", "license", "cc0.txt")]
            if not license_members:
                raise ValueError("Archive has no License.txt/license file; refusing import")
            license_text = archive.read(license_members[0]).decode("utf-8", errors="replace")
            if "CC0" not in license_text.upper() and "CREATIVE COMMONS ZERO" not in license_text.upper():
                raise ValueError("License file does not explicitly identify CC0; refusing import")

            for member in members:
                relative = safe_member_path(member.filename)
                unix_mode = (member.external_attr >> 16) & 0o170000
                if unix_mode == 0o120000:
                    raise ValueError(f"Symlink in ZIP is not allowed: {member.filename}")
                target = staging.joinpath(*relative.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(member) as src, target.open("wb") as dst:
                    shutil.copyfileobj(src, dst)

        metadata = {
            "name": title,
            "source": source,
            "license": "CC0 1.0",
            "archive": archive_path.name,
            "archive_sha256": hashlib.sha256(archive_path.read_bytes()).hexdigest(),
            "imported_into": f"external-staging/{folder}" if destination_root else f"res://assets/vendor/{folder}/",
        }
        (staging / "SOURCE_METADATA.json").write_text(
            json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
        )
        if destination.exists():
            shutil.rmtree(destination)
        staging.rename(destination)
        return destination
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=sorted(DESTINATIONS))
    parser.add_argument("archive", type=Path)
    parser.add_argument("--destination-root", type=Path, default=None,
                        help="Extract full source outside the Godot project (recommended for CI).")
    args = parser.parse_args()
    try:
        result = import_pack(args.kind, args.archive, args.destination_root)
    except Exception as exc:
        print(f"IMPORT FAILED: {exc}", file=sys.stderr)
        return 1
    print(f"Imported {args.kind} assets to {result}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
