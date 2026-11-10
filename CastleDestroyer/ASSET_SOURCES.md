# Castle Destroyer — External Asset Sources

## Imported and selected assets

| Source | Intended use | Formats | License | Integration |
|---|---|---|---|---|
| [Kenney Castle Kit](https://kenney-assets.itch.io/castle-kit) | Modular walls, corner pieces, towers, gate, flag, catapult, trees and rocks | GLB, FBX, OBJ | CC0 1.0; original pack license retained | Imported by CI; 10 GLB models staged for Camera A |
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | HUD button skins and future interface elements | PNG, SVG, TTF, OGG | CC0 1.0; original pack license retained | Imported by CI; 3 button-state textures staged for game and Camera A |

## Runtime integration

The Android workflow downloads the two exact Kenney archives, verifies their SHA-256 hashes, and imports them with `tools/import_kenney_assets.py`. It then runs `tools/stage_kenney_runtime.py`, which keeps the complete source packs under `assets/vendor/kenney-castle-kit/` and `assets/vendor/kenney-ui-pack/`, while copying the 10 models and 3 UI textures actually referenced by the game into `assets/vendor/kenney-runtime/`.

The Camera A preview uses the GLB wall, corner, doorway, square tower and roof, flag, gate, catapult, tree and rock models. The game and Camera A HUDs use the Kenney button textures. Both original CC0 license files and source metadata are kept with the staged runtime assets.

The downloads are pinned to the exact archive versions previously reviewed:
- Castle Kit SHA-256: `921f3f73927bb23106cae34bc21d5ab4b033a9fc120475e96f714a406e3169df`
- UI Pack SHA-256: `a8a14a234911eb648c062622915c93e79e94e97cb7f9f375a70f6617f1174318`

## Selection and mobile-performance rules

1. GLB is used for the runtime scene; FBX/OBJ remain in the retained source pack for future editing but are not loaded by the game.
2. Jolt collision geometry remains separate from decorative render meshes. Prefer simplified collision shapes for mobile performance.
3. Destruction should use intact meshes plus matching pre-fractured variants. Mesh swapping must preserve block health, team ownership and structural graph IDs.
4. Keep the UI pack's source artwork and license; only the three button states are currently loaded at runtime.
5. Do not mix optional third-party art into the castle scene unless its style and license have been checked.

## Import safety

The importer rejects unsafe ZIP paths and symlinks, limits archive size and file count, and requires an explicit CC0 license. The runtime staging script verifies both licenses and every required runtime file before replacing the staged directory. Unit tests cover path traversal, license rejection, and missing runtime assets.

Kenney's CC0 license permits personal, educational and commercial use without mandatory attribution. The original license files are retained as the authoritative per-pack notices.
