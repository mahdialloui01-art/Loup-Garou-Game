# Kenney asset staging

The project is prepared to import the official CC0 archives without committing
unverified third-party mirrors.

1. Download the official [Castle Kit](https://kenney-assets.itch.io/castle-kit)
   ZIP (free / name-your-price) and the [UI Pack](https://kenney.nl/assets/ui-pack).
2. Keep the original ZIPs outside the repository.
3. From the repository root, run:

   ```sh
   python3 CastleDestroyer/tools/import_kenney_assets.py castle /path/to/kenney_castle-kit.zip
   python3 CastleDestroyer/tools/import_kenney_assets.py ui /path/to/kenney_ui-pack.zip
   ```

4. Open `CastleDestroyer/project.godot` in Godot 4.4.1 so Godot imports the
   glTF/OBJ models and PNG textures.
5. Keep `SOURCE_METADATA.json` and the original pack license beside each
   imported pack. Do not remove or rewrite the upstream license.

The importer rejects archives without an explicit CC0 license, path traversal,
ZIP symlinks, excessive file counts, and oversized expanded archives. It stages
into a temporary directory and only replaces the destination after extraction
and license validation succeed.

**Status:** importer tooling is committed; source ZIP binaries have not yet
been obtained or imported, and no game scene is claiming to use these assets yet.
