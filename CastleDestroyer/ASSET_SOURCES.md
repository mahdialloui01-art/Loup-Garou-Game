# Castle Destroyer — External Asset Sources

## Imported runtime subset

| Source | Current runtime use | License | Status |
|---|---|---|---|
| [Kenney Castle Kit](https://kenney.nl/assets/castle-kit) | One authentic modular wall GLB used repeatedly around the Camera A fortress | CC0 1.0 | Included in the selected runtime bundle |
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | Flat depth button texture used by the battle HUD and Camera A controls | CC0 1.0 | Included in the selected runtime bundle |

The project owner supplied both original ZIP archives. A small curated bundle is stored as base64 text at `vendor_sources/kenney-runtime-selected.zip.base64` so the binary files can be reconstructed deterministically by CI without committing full source archives or redundant FBX/OBJ variants.

## Runtime integration

The Android workflow runs `tools/import_kenney_runtime_bundle.py` before Godot's editor import and test steps. It decodes the curated ZIP, checks safe archive paths and the presence of both CC0 license files, then stages these runtime files:

- `assets/vendor/kenney-runtime/models/wall.glb`
- `assets/vendor/kenney-runtime/ui/button_rectangle_depth_flat.png`
- Both original per-pack license texts and `SOURCE_METADATA.json`

The angled Camera A preview uses the Kenney wall module for the perimeter. Towers, roofs, central keep and environmental details remain procedural primitives for now; the runtime bundle does not include those models. The Kenney UI texture is used by both the Camera A controls and the battle HUD, with a procedural fallback if the staged texture is missing.

## License and safety

Both supplied archives contain a per-pack `License.txt` naming Creative Commons Zero (CC0 1.0). Their texts are retained in the staged runtime folder. The selected bundle SHA-256 is:

`31ff40ab261ba080b2bf34a60e86a1a02d26711ce5c3698c4f6b4ce1773eca41`

The importer rejects absolute paths, parent traversal, symlinks, unexpected/duplicate entries, excessive file counts, oversized base64 input and oversized expanded archives. It validates both CC0 notices before replacing the staged runtime directory.

The current subset is intentionally small for Android download size. More Castle Kit assets can be added later when their exact runtime roles are needed, while preserving the upstream license texts.
