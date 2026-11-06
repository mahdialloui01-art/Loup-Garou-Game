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

## Still in development
- Runtime and full rules/balance testing on Godot 4.4.1.
- Rich character portraits, map/background art, animations, sound and tutorial.
- Local pass-and-play with multiple human seats.
- Online rooms, matchmaking, reconnect handling and server-authoritative game state.
- Android export configuration, store assets, privacy and release checks.

## Run locally
Open this folder in Godot 4.4.1 or later and run `scenes/main.tscn`.

## Automated check
A GitHub Actions workflow is configured to run a headless Godot import and startup smoke test on pushes and pull requests. The workflow has not yet reported a completed run in this session. Even a passing smoke test will not replace manual gameplay testing or Android-device testing.

**Build status:** Source updates are committed. No APK has been produced or verified yet.
