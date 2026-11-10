#!/usr/bin/env python3
"""Safely stage a tiny runtime subset from the Gobkit CC0 insect archive."""
from __future__ import annotations

import argparse
import json
import shutil
import stat
import zipfile
from pathlib import Path, PurePosixPath


def validate_archive(archive: Path) -> tuple[list[zipfile.ZipInfo], zipfile.ZipInfo, list[zipfile.ZipInfo]]:
    with zipfile.ZipFile(archive) as zf:
        infos = zf.infolist()
        if sum(info.file_size for info in infos) > 100 * 1024 * 1024:
            raise ValueError("Archive expands beyond the 100 MiB safety limit")
        for info in infos:
            path = PurePosixPath(info.filename)
            mode = (info.external_attr >> 16) & 0o170000
            if path.is_absolute() or ".." in path.parts or "\\" in info.filename or mode == stat.S_IFLNK:
                raise ValueError(f"Unsafe archive member: {info.filename}")
        licenses = [i for i in infos if PurePosixPath(i.filename).name.lower() in {"license", "license.txt"}]
        if not licenses:
            raise ValueError("Gobkit archive has no LICENSE/License.txt file")
        with zf.open(licenses[0]) as handle:
            license_text = handle.read(256 * 1024).decode("utf-8", errors="replace")
        if "CC0" not in license_text.upper():
            raise ValueError("Gobkit license does not identify CC0")
        models = [i for i in infos if not i.is_dir() and i.filename.lower().endswith(".glb")]
        if not models:
            raise ValueError("Gobkit archive contains no GLB models")
        textures = [i for i in infos if not i.is_dir() and i.filename.lower().endswith(".png")]
        return models, licenses[0], textures


def rank_model(info: zipfile.ZipInfo) -> tuple[int, str]:
    name = PurePosixPath(info.filename).name.lower()
    preferred = ("bee", "butterfly", "dragonfly", "ant", "beetle", "grasshopper", "ladybug", "fly")
    for index, token in enumerate(preferred):
        if token in name:
            return index, name
    return len(preferred), name


def stage(archive: Path, destination: Path, max_models: int) -> list[str]:
    models, license_info, textures = validate_archive(archive)
    selected = sorted(models, key=rank_model)[:max_models]
    destination = destination.resolve()
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    with zipfile.ZipFile(archive) as zf:
        for info in selected + textures + [license_info]:
            name = PurePosixPath(info.filename).name
            if not name:
                continue
            target = destination / name
            if target.exists():
                continue
            with zf.open(info) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output)
            if info.filename.lower().endswith(".glb"):
                copied.append(name)
        readmes = [i for i in zf.infolist() if not i.is_dir() and PurePosixPath(i.filename).name.lower() == "readme.md"]
        if readmes:
            target = destination / "README.md"
            with zf.open(readmes[0]) as source, target.open("wb") as output:
                shutil.copyfileobj(source, output)
    (destination / "staged_manifest.json").write_text(
        json.dumps({"models": copied, "license": PurePosixPath(license_info.filename).name}, indent=2) + "\n",
        encoding="utf-8",
    )
    return copied


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("archive", type=Path)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--max-models", type=int, default=2)
    args = parser.parse_args()
    if args.max_models < 1 or args.max_models > 4:
        parser.error("--max-models must be between 1 and 4")
    models = stage(args.archive, args.destination, args.max_models)
    print(f"Staged {len(models)} Gobkit GLB models: {', '.join(models)}")


if __name__ == "__main__":
    main()
