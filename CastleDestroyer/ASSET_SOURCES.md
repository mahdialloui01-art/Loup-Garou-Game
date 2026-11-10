# Castle Destroyer — External Asset Sources

## Imported and selected assets

| Source | Intended use | Formats | License | Integration |
|---|---|---|---|---|
| [Kenney Castle Kit](https://kenney-assets.itch.io/castle-kit) | Modular walls, corner pieces, towers, gate, flag, catapult, trees and rocks | GLB, FBX, OBJ | CC0 1.0; original pack license retained | 10 GLB models staged for Camera A and battlefield |
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | HUD button skins and future interface elements | PNG, SVG, TTF, OGG | CC0 1.0; original pack license retained | 3 button-state textures staged for game and Camera A |

## Runtime integration

The Android workflow downloads the two exact Kenney archives and verifies their SHA-256 hashes. It extracts the full archives under the runner's temporary directory, outside the Godot project, then runs `tools/stage_kenney_runtime.py` to copy only the 10 GLB models and 3 UI textures referenced by the playable scenes into `assets/vendor/kenney-runtime/`.

The Camera A preview uses GLB wall, corner, doorway, square tower and roof, flag, gate, catapult, tree and rock models. The game and Camera A HUDs use the Kenney button textures. Both original CC0 license files and source metadata are retained with the staged runtime assets.

The uploaded ZIP archives were checked against the same pinned source archive hashes used by CI:
- Castle Kit SHA-256: `921f3f73927bb23106cae34bc21d5ab4b033a9fc120475e96f714a406e3169df`
- UI Pack SHA-256: `a8a14a234911eb648c062622915c93e79e94e97cb7f9f375a70f6617f1174318`

## Selection and mobile-performance rules

1. GLB is used for runtime scenes; FBX/OBJ remain in the source archive for future editing but are not imported into the APK.
2. Jolt collision geometry remains separate from decorative render meshes. Prefer simplified collision shapes for mobile performance.
3. Destruction should use intact meshes plus matching pre-fractured variants. Mesh swapping must preserve block health, team ownership and structural graph IDs.
4. Keep the UI pack's source artwork and license; only the three button states are currently loaded at runtime.
5. Do not mix optional third-party art into the castle scene unless its style and license have been checked.

## Import safety

The importer rejects unsafe ZIP paths and symlinks, limits archive size and file count, and requires an explicit CC0 license. Runtime staging verifies both licenses and every required runtime file before replacing the staged directory. Unit tests cover path traversal, license rejection, missing runtime assets, and external source staging.

Kenney's CC0 license permits personal, educational and commercial use without mandatory attribution. The original license files are retained as the authoritative per-pack notices.
