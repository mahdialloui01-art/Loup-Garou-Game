# Kenney runtime asset staging

The repository contains a curated runtime subset from the two CC0 ZIP archives
supplied by the project owner. It intentionally does not vendor full FBX/OBJ
source variants or unused UI files.

The Android CI workflow runs:

```sh
python3 CastleDestroyer/tools/import_kenney_runtime_bundle.py \
  CastleDestroyer/vendor_sources/kenney-runtime-selected.zip.base64
```

This safely reconstructs and stages the selected content under
`CastleDestroyer/assets/vendor/kenney-runtime/`:

- `models/wall.glb` — the wall module used by the angled Camera A fortress
- `ui/button_rectangle_depth_flat.png` — the button texture used by the HUD
- `LICENSES/` — the original CC0 license text from both Kenney packs
- `SOURCE_METADATA.json` — source URLs, subset and bundle hash

The script rejects unsafe paths, symlinks, unexpected archive members, invalid
CC0 license text and archives that exceed its size/count limits. It stages the
files in a temporary directory and replaces the runtime destination only after
validation succeeds.

Official sources: [Castle Kit](https://kenney.nl/assets/castle-kit) and
[UI Pack](https://kenney.nl/assets/ui-pack). The original project source ZIPs
remain user-supplied files and are not copied wholesale into this repository.
