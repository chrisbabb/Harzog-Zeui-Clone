# Skyforge Command

Skyforge Command is an original 2.5D action-RTS prototype: a single commander
who can transform between a ground form and an air form, leading built units
against an enemy base on an angled, orthographic battlefield.

This is an early scaffold. Mechanics are inspired by the general conventions
of classic transformable-commander RTS games (a hero that fights directly
*and* manages base production), but everything here — names, assets, maps,
and text — is original to this project. No copyrighted names, art, music,
maps, or text from any existing game are used anywhere in this repository.
All meshes are temporary primitive placeholders (capsules, boxes, prisms)
until real art is produced.

## Opening the project in Godot

1. Install **Godot 4.x** (developed against the 4.3 feature set) from
   [godotengine.org](https://godotengine.org/).
2. Launch Godot and choose **Import**.
3. Select the `project.godot` file at the root of this repository.
4. Click **Import & Edit**.
5. Press **F5** (or the Play button) to run the game — it boots into the
   main menu first.

## Controls

### Keyboard & Mouse

| Action | Keyboard / Mouse |
| --- | --- |
| Move forward / back | `W` / `S` (or `Up` / `Down`) |
| Move left / right | `A` / `D` (or `Left` / `Right`) |
| Fire primary weapon | `Left Mouse` or `Space` |
| Transform (ground ↔ air) | `E` |
| Pick up / drop unit | `Q` |
| Open build menu | `B` |
| Open command menu | `C` |
| Cycle selected order | — |
| Confirm | `Enter` or `Left Mouse` |
| Cancel | `Esc` or `Right Mouse` |
| Pause | `Esc` |
| Minimap zoom | `Tab` |

### Controller (Xbox / PlayStation)

| Action | Button |
| --- | --- |
| Move commander | Left stick |
| Aim / fire direction | Right stick |
| Fire primary weapon | `A` / Cross |
| Transform (ground ↔ air) | `B` / Circle |
| Pick up / drop unit | `X` / Square |
| Open command menu | `Y` / Triangle |
| Open build menu | Left Bumper (LB / L1) |
| Cycle selected order | Right Bumper (RB / R1) |
| Navigate menus | D-pad |
| Confirm | `A` / Cross |
| Cancel | `B` / Circle |
| Pause | Start |
| Minimap zoom | Back / Select |

All bindings are defined in **Project Settings → Input Map** and referenced
in code through `scripts/autoload/Constants.gd`, so they can be remapped in
one place.

## Current development status

This is a scaffold, not a playable build. What exists today:

- Folder structure and autoload singletons (`GameState`, `EventBus`,
  `Constants`, `Economy`).
- A 3D `Game` scene with a navigable ground plane, an angled orthographic
  camera, a player/enemy spawn marker, and a baked navigation mesh.
- A transformable `Commander` that moves and switches between ground/air
  placeholder meshes.
- A generic `Unit` scaffold driven by `NavigationAgent3D`.
- `Base` and `Outpost` building scaffolds with health/destruction stubs.
- Menu flow: Main → Main Menu → Game, with a Pause Menu overlay.
- HUD shell with a resource readout, build/command menu buttons, and a
  minimap that plots registered units and buildings.

What's intentionally not implemented yet: real combat resolution, build
queues actually spending resources to spawn units, AI opponents, real art
and audio, and saved/loaded matches (`scripts/save` and `data/maps` are
empty scaffolds for this work).

## Project structure

```
scenes/
  main/        Main.tscn (entry point), Game.tscn (battlefield)
  player/      Commander.tscn
  units/       Unit.tscn
  buildings/   Base.tscn, Outpost.tscn
  ui/          HUD, BuildMenu, CommandMenu, Minimap, MainMenu, PauseMenu
  effects/     reserved for VFX scenes
scripts/
  autoload/    GameState, EventBus, Constants, Economy
  main/        Main.gd, Game.gd
  player/      Commander.gd
  units/       Unit.gd
  buildings/   Base.gd, Outpost.gd
  ai/          reserved for AI opponent logic
  map/         TerrainRoot.gd (navigation mesh baking)
  ui/          HUD/menu scripts
  save/        reserved for save/load logic
assets/        placeholder art, audio, fonts (no copyrighted assets)
data/maps/     reserved for map/level data
tests/unit_tests/  reserved for unit tests
```

## Performance notes

The game is designed to maintain smooth frame rates at up to 60 units per team
(120 units total). Several architectural choices keep the per-frame cost low:

**Node groups**

Units register in both a team-agnostic `"units"` group and a team-specific
`"player_units"` or `"enemy_units"` group when spawned, and deregister from all
three on death. Code that only needs one team (building supply radius,
AI order assignment, `UnitOrder._resolve_ally_target`) queries the team group
directly, halving the iteration cost compared to scanning all units and
discarding half. The `"buildings"` and `"outposts"` groups follow the same
pattern for future use.

**Separation avoidance (biggest win)**

`Unit._separation_offset()` was previously an O(n²)-per-frame scan of the
entire `"units"` group (every unit checking every other unit). It now reads the
unit's own `_nearby_bodies` array maintained by the detection `Area3D`, which
already covers the 2.5-unit separation radius. The detection sphere is
guaranteed to be at least as large as `SEPARATION_RADIUS`, so no nearby
teammate is ever missed.

**AI decision loop**

`EnemyAI` already runs on periodic timers (`_decision_timer`, `_wave_timer`)
rather than every frame. It now fetches `enemy_units` and `player_units` groups
once per tick and passes the arrays down into `TacticalDirector` helpers,
avoiding repeated tree queries within a single decision cycle.

**Unit cap**

Each team is limited to `Constants.MAX_UNITS_PER_TEAM` (60) live units.
`GameState` tracks counts via `EventBus.unit_created` / `unit_destroyed`
signals. `BuildMenu` checks the count before purchase and disables buttons
when at cap; `EnemyAI._try_build_unit` returns early if the enemy is at cap.

**Minimap**

`Minimap._draw()` now runs at 8 Hz instead of every render frame (a typical
60× reduction). The redraw timer is a simple float decrement — no `Timer` node
overhead.

**HUD polling**

The four `_update_*` methods in `HUD._process()` (timer, commander panel, HQ
bars, selected-unit labels) are throttled to 10 Hz. Only the feedback-label
timeout still ticks every frame because its animation must feel responsive.

**Health bar LOD**

Unit health bars are hidden unless the unit has taken damage within the past
8 seconds (`HEALTH_BAR_SHOW_DURATION`). At full health and outside combat the
bar is invisible, reducing both draw calls and visual clutter.

**Projectile/explosion material caching**

`Projectile` caches one `StandardMaterial3D` per team for straight-flying bolts
(artillery shells still get individual instances since their emission energy
differs). `Explosion` caches the shared `QuadMesh` and
`ParticleProcessMaterial` used by all spark bursts, avoiding several allocations
per detonation.

**Wrecks and projectile cleanup**

Destroyed unit wrecks fade alpha over `WRECK_FADE_DURATION` (5 s) then call
`queue_free()`. Projectiles `queue_free()` on detonation or lifetime expiry.
Neither requires manual housekeeping from the game controller.

## Asset policy

Every asset in this repository must be original or appropriately licensed.
Do not add art, audio, maps, or text copied or adapted from any existing
commercial game.
