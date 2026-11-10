# Castle Destroyer — External Asset Sources

This file tracks candidate assets reviewed for Castle Destroyer. Only assets whose individual source page explicitly grants a compatible license may be imported. Keep each pack's original license file beside the imported assets.

## Selected sources

| Source | Intended use | Format / scope | License evidence | Integration status |
|---|---|---|---|---|
| [Kenney Castle Kit](https://kenney-assets.itch.io/castle-kit) | Main fort silhouettes, towers, gates, battlements and siege props | 70+ models; OBJ, FBX, glTF | CC0 1.0 on the pack page | Selected; files not yet imported |
| [Kenney UI Pack](https://kenney.nl/assets/ui-pack) | HUD panels, buttons, sliders and interface states | 430+ UI files | CC0 on the pack page | Selected; files not yet imported |
| [Medieval Voxel Assets — Felix Strefter](https://felixstrefter.itch.io/medieval-voxel-assets) | Optional alternate wall/tower set and environment props; use only if its voxel style matches the final art direction | 52 pieces; OBJ/MTL and GLB | CC0 1.0 on the pack page | Evaluated as optional; not imported |

## Selection rules

1. Prefer Kenney Castle Kit for the core fort because it is purpose-built for castles and siege scenes, has multiple interchange formats, and is CC0.
2. Use Kenney UI Pack for the mobile HUD; adapt its panels and controls to the existing landscape layout rather than adding a heavy UI framework.
3. Treat the voxel pack as optional. Do not mix it into the main scene unless its visual style can be unified with the castle kit.
4. Keep Jolt Physics collision geometry separate from decorative render meshes. Use simplified box/convex collision shapes for mobile performance.
5. For destruction, author intact meshes and matching pre-fractured variants. Mesh swapping must preserve block health, team ownership, and structural graph IDs.
6. Do not import paid, unclear-license, or redistribution-restricted assets. Record source URL and license for every pack.

## Attribution and licensing

Kenney states that assets on its asset pages are public-domain CC0 and attribution is not required; the individual pack license must still be retained and checked at import time. The selected itch.io pages also display CC0 1.0. License terms should be rechecked before a commercial release.

## Implementation note

The source packs have been researched and selected, but their binary files have **not** yet been committed to this repository. Do not describe the art integration as complete until the actual source archives, license files, imported Godot resources, and in-game usage have been verified.
