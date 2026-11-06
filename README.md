# LOUP GAROU — Legends of the Village

A standalone Godot 4.4.1 Android game project for the classic Werewolf social-deduction party game.

## Current playable foundation
- Arabic, French and English interface selection.
- Offline matches for 6–10 seats: one human player and AI-controlled villagers.
- Role distribution: Werewolf, Seer, Witch, Guard, Hunter and Villager.
- Private role briefing before the first night, with a short explanation of each role.
- Night/day loop, Seer investigation, Guard protection (including self-protection and no consecutive repeat target), Witch healing and poison, Hunter's final shot, village voting, tie-breaking and win conditions.
- AI night actions and voting, plus spectator continuation after the human player is eliminated.
- Dark village-themed interface with styled action buttons and a live player/elimination list.

## Automated checks and Android builds
- The Godot CI workflow imports project resources and starts the main scene headlessly.
- The Android workflow exports an **ARM64 debug APK** with Godot 4.4.1 and uploads it as the `LoupGarou-Android-debug` workflow artifact (retained for 14 days).
- This debug APK is for installation and testing only. It is **not** a release-signed build and is not ready for Google Play submission.
- A successful workflow run and a downloadable artifact are required before an APK can be considered produced.

## Still in development
- Runtime and full rules/balance testing on Godot 4.4.1 and physical Android devices.
- Rich character portraits, map/background art, animations, sound and tutorial.
- Local pass-and-play with multiple human seats.
- Online rooms, matchmaking, reconnect handling and server-authoritative game state.
- Store assets, privacy and release checks.

## Run locally
Open this folder in Godot 4.4.1 or later and run `scenes/main.tscn`.
