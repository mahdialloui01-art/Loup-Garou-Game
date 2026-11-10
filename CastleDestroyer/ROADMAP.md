# Castle Destroyer — Development Roadmap

## Milestone 1 — Playable core
- [x] Separate Godot Android project
- [x] Landscape scene and HUD foundation
- [x] Drag aiming and cannon firing
- [x] Three weapon types
- [x] Block damage and splash damage
- [x] Enemy cannon opponent
- [x] Campaign levels and enemy scaling
- [x] Gold rewards and local save
- [x] Cannon and fort upgrades
- [ ] Validate Android export and install on physical devices

## Milestone 2 — Destruction and combat
- [x] Structural support graph and ground-connected stability evaluation
- [x] Jolt Physics selected for the 3D physics server (Godot 4.4 built-in)
- [x] Pre-fractured mesh-swap editor plugin foundation
- [ ] Migrate battlefield debris and fort fragments to live 3D Jolt bodies
- [x] Structural stability graph and cascading collapse evaluation
- [ ] Explosive impulse, debris pooling and impact effects
- [ ] Troop movement, pathfinding, melee/ranged combat
- [ ] Distinct troop classes, skills, cooldowns and counters
- [ ] Enemy fort layouts and boss encounters

## Milestone 3 — Content and progression
- [ ] Campaign map, chapters and level objectives
- [ ] 30+ original troop/defender variants
- [ ] Weapon and troop unlock tree
- [ ] Upgrade economy and balancing
- [ ] Daily challenges, achievements, quests and rewards
- [ ] Player profile and cloud backup

## Milestone 4 — Online and release
- [ ] Backend accounts and secure player inventory
- [ ] Matchmaking and 1v1 online battles
- [ ] Server-authoritative results and anti-cheat
- [ ] Reconnect handling, latency compensation and telemetry
- [ ] Original art/audio production and localization
- [ ] QA matrix, Android performance tests, signed release build

## Quality gates
A milestone is complete only after Godot imports cleanly, automated smoke tests pass, Android export succeeds, and real-device tests confirm input, scaling, save/load and performance.
