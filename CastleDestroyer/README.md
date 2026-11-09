# Castle Destroyer — Android Game

Independent Godot 4 game project inside the Loup-Garou-Game repository. The original werewolf game at the repository root remains separate.

## Current gameplay foundation
- Landscape Android layout and touch/mouse drag aiming.
- Three weapons: stone, mega bomb with area damage, and fire orb with area damage.
- Destructible block-based forts with armor and visible damage states.
- Enemy cannon AI with increasing aggression and fort strength by campaign level.
- Campaign progression, gold rewards, persistent local progress, cannon upgrades and wall fortification.
- HUD for health, score, level, gold, weapon and ammunition.
- Pause, retry and next-level flow.
- Original procedural visuals; no ripped Castle Busters assets, code or audio.

## Run in Godot
1. Install Godot 4.4.1 or later.
2. Open `CastleDestroyer/project.godot`.
3. Press Play. The game uses landscape orientation.
4. Drag from the friendly cannon area toward the upper-right to aim; use touch-drag on mobile.
5. Use the bottom controls to switch weapon, fire, upgrade, fortify, pause and advance after victory.

## Android build
The dedicated GitHub Actions workflow imports the project, runs a headless smoke test, and exports an ARM64 debug APK artifact. A debug APK is for testing and is not a Play Store release-signed package.

## Production status
This is an expanded playable foundation, not yet equivalent in content or production polish to Castle Busters. Major remaining work includes rigid-body structural collapse, animated troop classes, campaign map and bosses, original art/audio, cloud save, online matchmaking/PvP, anti-cheat, balancing and device QA. See ROADMAP.md.
