# Kenney asset packs and runtime staging

The project uses two owner-supplied Kenney CC0 packs:

- [Castle Kit](https://kenney-assets.itch.io/castle-kit)
- [UI Pack](https://kenney.nl/assets/ui-pack)

## Local import

From the repository root, import the original ZIP archives:

```sh
python3 CastleDestroyer/tools/import_kenney_assets.py castle /path/to/kenney_castle-kit.zip
python3 CastleDestroyer/tools/import_kenney_assets.py ui /path/to/kenney_ui-pack.zip
python3 CastleDestroyer/tools/stage_kenney_runtime.py
```

The importer retains the original pack contents and license text beneath
`CastleDestroyer/assets/vendor/kenney-castle-kit/` and
`CastleDestroyer/assets/vendor/kenney-ui-pack/`. Runtime staging copies only
the assets referenced by the Godot scenes into
`CastleDestroyer/assets/vendor/kenney-runtime/`:

- 10 GLB models for the Camera A fortress, gate, siege prop and environment
- 3 UI button-state textures for the battle HUD and Camera A controls
- Both original per-pack CC0 license files and source metadata

The Android CI workflow downloads the same pinned archives, verifies their
SHA-256 checksums, then runs these import and staging scripts before Godot
imports the project and exports the APK.

## Safety and licensing

Both archives must contain their own explicit CC0 `License.txt`. The importer
rejects unsafe ZIP paths, symlinks, oversized archives, and archives without a
CC0 license. Runtime staging verifies every required model and UI texture
before replacing its output folder. Keep both license notices with the assets.
