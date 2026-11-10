#!/usr/bin/env python3
"""Stage only the Kenney models and UI textures referenced by playable scenes.

The full source archives can be extracted outside the project and supplied as
optional positional arguments. This keeps unused FBX/OBJ/source variants out of
Godot import and the Android APK.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
MODEL_FILES = (
    "wall.glb", "wall-corner.glb", "wall-doorway.glb",
    "tower-square.glb", "tower-square-roof.glb", "flag.glb",
    "gate.glb", "siege-catapult.glb", "tree-large.glb", "rocks-large.glb",
)
UI_FILES = (
    "button_rectangle_depth_flat.png",
    "button_rectangle_depth_gloss.png",
    "button_rectangle_depth_border.png",
)


def _require_cc0(license_path: Path) -> str:
    if not license_path.is_file():
        raise FileNotFoundError(f"Missing Kenney license: {license_path}")
    content = license_path.read_text(encoding="utf-8", errors="replace")
    normalized = content.upper()
    if "CC0" not in normalized and "CREATIVE COMMONS ZERO" not in normalized:
        raise ValueError(f"License does not explicitly identify CC0: {license_path}")
    return content


def stage_runtime(
    project_root: Path = PROJECT_ROOT,
    castle_source_root: Path | None = None,
    ui_source_root: Path | None = None,
) -> Path:
    vendor = Path(project_root) / "assets" / "vendor"
    castle_root = Path(castle_source_root) if castle_source_root else vendor / "kenney-castle-kit"
    ui_root = Path(ui_source_root) if ui_source_root else vendor / "kenney-ui-pack"
    castle_models = castle_root / "Models" / "GLB format"
    ui_source = ui_root / "PNG" / "Blue" / "Default"
    castle_license = castle_root / "License.txt"
    ui_license = ui_root / "License.txt"

    _require_cc0(castle_license)
    _require_cc0(ui_license)
    for name in MODEL_FILES:
        if not (castle_models / name).is_file():
            raise FileNotFoundError(f"Required Castle Kit model is missing: {name}")
    for name in UI_FILES:
        if not (ui_source / name).is_file():
            raise FileNotFoundError(f"Required UI Pack texture is missing: {name}")

    destination = vendor / "kenney-runtime"
    staging = vendor / "kenney-runtime.staging"
    if staging.exists():
        shutil.rmtree(staging)
    (staging / "models").mkdir(parents=True)
    (staging / "ui").mkdir(parents=True)
    (staging / "licenses").mkdir(parents=True)
    try:
        for name in MODEL_FILES:
            shutil.copy2(castle_models / name, staging / "models" / name)
        for name in UI_FILES:
            shutil.copy2(ui_source / name, staging / "ui" / name)
        shutil.copy2(castle_license, staging / "licenses" / "castle-kit-License.txt")
        shutil.copy2(ui_license, staging / "licenses" / "ui-pack-License.txt")

        metadata = {
            "name": "Kenney runtime selection for Castle Destroyer",
            "license": "CC0 1.0",
            "models": list(MODEL_FILES),
            "ui_textures": list(UI_FILES),
            "source_directories": [
                "verified source archives extracted outside the Godot project",
            ],
            "note": "Only runtime-required GLB and PNG assets plus both original CC0 license texts are staged.",
        }
        for pack, root in (("castle", castle_root), ("ui", ui_root)):
            source_metadata = root / "SOURCE_METADATA.json"
            if source_metadata.is_file():
                metadata[pack + "_source"] = json.loads(
                    source_metadata.read_text(encoding="utf-8")
                )
        (staging / "SOURCE_METADATA.json").write_text(
            json.dumps(metadata, indent=2) + "\n", encoding="utf-8"
        )
        if destination.exists():
            shutil.rmtree(destination)
        staging.rename(destination)
    except Exception:
        shutil.rmtree(staging, ignore_errors=True)
        raise
    return destination


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("castle_source_root", nargs="?", type=Path)
    parser.add_argument("ui_source_root", nargs="?", type=Path)
    args = parser.parse_args()
    try:
        result = stage_runtime(PROJECT_ROOT, args.castle_source_root, args.ui_source_root)
    except Exception as exc:
        print(f"KENNEY RUNTIME STAGING FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)
    print(f"Staged Kenney runtime assets: {result.relative_to(PROJECT_ROOT)}")
