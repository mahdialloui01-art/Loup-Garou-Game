# Kenney asset packs and optimized runtime staging

The project uses two owner-supplied Kenney CC0 packs:

- [Castle Kit](https://kenney-assets.itch.io/castle-kit)
- [UI Pack](https://kenney.nl/assets/ui-pack)

## Local import

From the repository root, import the original ZIP archives and then stage only
the assets used by the Godot scenes:

```sh
python3 CastleDestroyer/tools/import_kenney_assets.py castle /path/to/kenney_castle-kit.zip
python3 CastleDestroyer/tools/import_kenney_assets.py ui /path/to/kenney_ui-pack.zip
python3 CastleDestroyer/tools/stage_kenney_runtime.py
```

For Android CI, the full archives are extracted outside the Godot project to
avoid importing unused FBX, OBJ, audio and duplicate source formats:

```sh
python3 CastleDestroyer/tools/import_kenney_assets.py castle /path/to/kenney_castle-kit.zip --destination-root /tmp/kenney/source
python3 CastleDestroyer/tools/import_kenney_assets.py ui /path/to/kenney_ui-pack.zip --destination-root /tmp/kenney/source
python3 CastleDestroyer/tools/stage_kenney_runtime.py /tmp/kenney/source/kenney-castle-kit /tmp/kenney/source/kenney-ui-pack
```

The game project contains only the optimized runtime selection under
`CastleDestroyer/assets/vendor/kenney-runtime/`:

- 10 GLB models for the fortress, gate, siege prop and environment
- 3 UI button-state PNG textures for the battle HUD and Camera A controls
- Both original per-pack CC0 license files and source metadata

The full ZIP source archives remain outside the project during CI and are not
bundled into the Android APK. The workflow verifies their pinned SHA-256 hashes
before importing, then stages only the listed runtime files.

## Safety and licensing

Both archives must contain their own explicit CC0 `License.txt`. The importer
rejects unsafe ZIP paths, symlinks, oversized archives, and archives without a
CC0 license. Runtime staging verifies both licenses and every required model
and UI texture before replacing its output folder. Keep both license notices
with the staged assets.


## Gobkit Insect runtime selection
The owner-uploaded `gobkit-insect001-pack.zip` is kept as a source archive in this folder. Android CI validates its CC0 license and safely stages at most two GLB models plus PNG textures into `gobkit-runtime/`. The game loads only those two models as small animated background insects; shadows are disabled for mobile performance. The source ZIP is excluded from the exported APK.
