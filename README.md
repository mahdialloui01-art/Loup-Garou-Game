# LOUP GAROU — Legends of the Village

A standalone Godot 4.4 Android game project for the classic Werewolf social-deduction party game.

## Implemented in the current development build
- Arabic, French and English interface selection.
- Offline matches for 6–10 seats, with the human player and AI-controlled villagers.
- Role distribution based on match size: Werewolf, Seer, Witch, Guard, Hunter and Villager.
- Night/day loop, secret role reveal, Seer investigation, Guard protection, Witch healing and poison, Hunter's final shot, voting and win conditions.
- AI night actions and voting behavior.

## Still in development
- Full balance and edge-case testing of the offline rules and AI.
- Better player portraits, animations, sound, tutorials and settings.
- Local pass-and-play.
- Online rooms, matchmaking, reconnect handling and server-authoritative game state.
- Android export, store assets, privacy and release checks.

## Build
Open this folder in Godot 4.4.1 or later and run `scenes/main.tscn`.
Android export requires Android SDK/JDK and matching Godot export templates.

**Build status:** The source changes have been committed to GitHub. An APK has not yet been built or runtime-tested in this development step.
