# Skyforge Command

Skyforge Command is an original 2.5D action-RTS: a transformable commander
who switches between a fast AIR form and a sturdier GROUND form, personally
fighting on the battlefield while also directing an economy, a build queue,
and up to 60 units per side toward capturing outposts and destroying the
enemy HQ.

Mechanics are inspired by the general conventions of classic
transformable-commander RTS games (a hero that fights directly *and*
manages base production), but everything in this repository — names,
maps, unit roster, art, audio, and text — is original. No copyrighted
names, art, music, maps, or text from any existing game are used anywhere
in this project. See [Asset policy](#asset-policy) below.

## Overview

- **Single Player vs AI** — pick a map, difficulty (Easy/Normal/Hard),
  starting credits, match speed, and outpost count, then fight a
  three-tier AI opponent that builds units, captures outposts, defends
  its HQ, and launches coordinated attack waves.
- **Local Multiplayer** — two humans, one machine, split-screen
  (vertical or horizontal). Player 1 (BLUE) plays keyboard/mouse;
  Player 2 (RED) plays controller. Each player gets their own camera,
  HUD, build menu, and command menu; the battlefield and economy are
  shared/contested. A match ends the instant either HQ is destroyed.
- **Interactive Tutorial** — a 13-step guided practice match covering
  movement, transforming, refueling, building, picking up/dropping units,
  capturing an outpost, and destroying a target.
- **8 unit types** (Scout Buggy, Tank, Missile Crawler, Artillery,
  Anti-Air, Supply Truck, Capture Drone, Heavy Walker), each with its own
  stats, role, and cost, defined in `data/units.json`.
- Persistent **options** (audio volumes, fullscreen, difficulty, camera
  shake, minimap zoom) saved to `user://settings.json`.

All meshes are procedurally-built primitive placeholders (boxes, capsules,
prisms) and all audio is procedurally-generated placeholder tones/silence
— see [Known issues](#known-issues).

## Controls

### Player 1 — Keyboard & Mouse

| Action | Key / Button |
| --- | --- |
| Move | `W` `A` `S` `D` (or arrow keys) |
| Fire primary weapon | `Left Mouse` or `Space` |
| Transform (ground ↔ air) | `E` |
| Pick up / drop unit | `Q` |
| Open build menu | `B` |
| Open command menu | `C` |
| Cycle selected order | `R` |
| Confirm | `Enter` or `Left Mouse` |
| Cancel | `Esc` or `Right Mouse` |
| Pause | `Esc` |
| Minimap zoom | `Tab` |

### Controller (Xbox / PlayStation layout)

Used by Player 1 in Single Player, or by **Player 2** in Local
Multiplayer (device index 0 — the first controller connected).

| Action | Button |
| --- | --- |
| Move | Left stick |
| Aim / fire direction | Right stick |
| Fire primary weapon | `A` / Cross |
| Transform (ground ↔ air) | `B` / Circle |
| Pick up / drop unit | `X` / Square |
| Open command menu | `Y` / Triangle |
| Open build menu | Left Bumper (LB / L1) |
| Cycle selected order | Right Bumper (RB / R1) |
| Navigate menus | D-pad / left stick |
| Confirm | `A` / Cross |
| Cancel | `B` / Circle |
| Pause | Start |
| Minimap zoom | Back / Select |

All bindings are defined in **Project Settings → Input Map** and
referenced in code through `scripts/autoload/Constants.gd`'s `ACTION_*`
constants, so they can be remapped in one place. In Local Multiplayer,
Player 1's movement/transform/pickup/fire are read directly from the
keyboard/mouse (bypassing the shared action map) and Player 2's are read
directly from joypad device 0, so a keyboard press in P1's hands or a
controller press in P2's can't cross-trigger the other player's commander,
menus, pause, or minimap zoom — each per-player UI script filters input by
device type whenever `GameState.game_mode == LOCAL_MULTIPLAYER`.

## How to run

1. Install **Godot 4.x** (developed against the 4.3 feature set) from
   [godotengine.org](https://godotengine.org/).
2. Launch Godot, choose **Import**, and select `project.godot` at the
   root of this repository.
3. Click **Import & Edit**.
4. Press **F5** (or the Play button) to run the game — it boots into the
   main menu.
5. From the main menu: **Start Skirmish** → choose Single Player or Local
   Multiplayer and your other settings → **Start Skirmish**; or
   **Tutorial** for the guided practice match; or **Options** for
   audio/display/gameplay settings.

For local multiplayer, connect a controller before launching (or before
starting the split-screen match) so it's recognized as device 0.

## How to export

This repository includes an `export_presets.cfg` with a **Windows
Desktop** preset (output: `builds/windows/SkyforgeCommand.exe`), authored
by hand against the standard Godot 4.3 preset format since no Godot editor
was available in the environment that produced it. Before exporting for
the first time:

1. Open the project in the Godot editor.
2. Go to **Editor → Manage Export Templates** and install the templates
   matching your installed Godot version exactly (e.g. 4.3.stable).
3. Go to **Project → Export**. The "Windows Desktop" preset should
   already be listed; open it and confirm the settings look correct for
   your machine (in particular, `application/icon` is left blank — set it
   to `res://icon.svg` or a `.ico` if you want a custom taskbar icon).
4. Click **Export Project** and choose an output location (defaults to
   `builds/windows/`, which is git-ignored).

To add another platform (Linux, macOS, Web), use **Project → Export →
Add...** in the editor — this appends a new `[preset.N]` block to
`export_presets.cfg` alongside the existing Windows preset.

## Known issues

- **No networked multiplayer.** Local Multiplayer is same-machine,
  split-screen only; there is no LAN or online play.
- **Local Multiplayer assumes exactly one controller** (device index 0)
  for Player 2. A second controller plugged in afterward is not
  auto-assigned, and if no controller is connected P2 simply has no
  input.
- **Minimap zoom level is a shared, persisted setting.** Each player's
  minimap zooms independently *during* a match, but whichever player last
  changed it is the one whose zoom level is remembered as the default for
  the next session (it's stored in the single shared `settings.json`).
- **All art and audio are placeholders.** Meshes are primitives (boxes,
  capsules, prisms, cylinders) built in code; sound effects are short
  procedurally-generated tones and music tracks are silent unless a
  matching file is dropped into `assets/audio/placeholder/` (see the
  comment at the top of `scripts/autoload/AudioManager.gd`).
- **`export_presets.cfg` was hand-authored**, not generated by the Godot
  editor (this environment had no Godot binary to run it through).
  Double-check it opens without errors in **Project → Export** before
  relying on it, and re-save it from the editor if Godot normalizes any
  fields.
- **No in-game control remapping UI.** Rebinding requires editing
  **Project Settings → Input Map** (or `project.godot` directly) and
  re-exporting.
- **No gamepad vibration/haptics.**
- Outposts can be destroyed outright by sustained fire (not just
  captured) as a deliberate design choice; a destroyed outpost is gone
  for the rest of the match rather than reverting to neutral.

## Future improvements

- Real art (unit/building models, terrain textures) and real audio
  (music tracks, recorded SFX) to replace the procedural placeholders.
- Networked multiplayer (the existing team/economy separation in
  `GameState`/`Economy`/`EventBus` was written with two independent human
  teams in mind, which should ease a future move from split-screen to
  networked sessions).
- Support for more than 2 players / more than 2 teams.
- In-game key/button remapping UI backed by `SaveManager`.
- Additional maps, unit types, and a difficulty tier between Normal and
  Hard.
- Automated tests (`tests/unit_tests/` is currently an empty scaffold).
- Controller auto-assignment / hot-swap and support for a second
  controller taking over P2 if the first disconnects mid-match.

## Project structure

```
scenes/
  main/        Main.tscn (entry point), Game.tscn (single player),
               LocalMultiplayer.tscn (split-screen), Tutorial.tscn
  player/      Commander.tscn, EnemyCommander.tscn
  units/       Unit.tscn + one scene per unit type
  buildings/   Base.tscn (HQ), Outpost.tscn
  effects/     Projectile.tscn, Explosion.tscn
  ui/          HUD, BuildMenu, CommandMenu, Minimap, MainMenu,
               SkirmishSetup, OptionsMenu, PauseMenu, TutorialOverlay,
               DebugPanel
scripts/
  autoload/    Constants, EventBus, GameState, Economy, AudioManager
  save/        SaveManager (settings persistence)
  main/        Main.gd, Game.gd, LocalMultiplayer.gd, Tutorial.gd
  player/      Commander.gd
  units/       Unit.gd, UnitOrder.gd, UnitDatabase.gd
  buildings/   Base.gd, Outpost.gd
  ai/          EnemyAI.gd, EnemyCommanderBot.gd, TacticalDirector.gd
  map/         MapGenerator.gd, NavigationManager.gd, TerrainRoot.gd,
               CaptureZone.gd
  ui/          HUD/menu scripts
  effects/     Projectile.gd, Explosion.gd
  debug/       DebugPanel.gd (F1 in-game, debug builds only)
data/units.json  Per-unit-type stats (cost, hp, speed, damage, range, ...)
assets/          Placeholder art/audio directories (no shipped binary
                 assets — see Known issues). Final art drops into
                 assets/art/final/ and replaces the procedural visuals
                 automatically — see ASSET_PIPELINE.md
tests/unit_tests/  Reserved for future automated tests
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
pattern.

**Separation avoidance (biggest win)**

`Unit._separation_offset()` reads the unit's own `_nearby_bodies` array
maintained by its detection `Area3D` rather than scanning the entire
`"units"` group every frame (an O(n²) cost at scale). The detection sphere
is guaranteed to be at least as large as `SEPARATION_RADIUS`, so no nearby
teammate is ever missed.

**AI decision loop**

`EnemyAI` runs on periodic timers (`_decision_timer`, `_wave_timer`) rather
than every frame, fetching `enemy_units`/`player_units` groups once per
tick and passing the arrays down into `TacticalDirector` helpers instead of
repeating tree queries within a single decision cycle.

**Unit cap**

Each team is limited to `Constants.MAX_UNITS_PER_TEAM` (60) live units.
`GameState` tracks counts via `EventBus.unit_created` / `unit_destroyed`
signals. `BuildMenu` checks the count before purchase and disables buttons
when at cap; `EnemyAI._try_build_unit` returns early if the enemy is at cap.

**Minimap**

`Minimap._draw()` runs at 8 Hz instead of every render frame. The redraw
timer is a simple float decrement — no `Timer` node overhead.

**HUD polling**

The `_update_*` methods in `HUD._process()` (timer, commander panel, HQ
bars, selected-unit labels, outpost/income display) are throttled to
10 Hz. Only the feedback-label timeout still ticks every frame because its
animation must feel responsive.

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

For the full pipeline — recommended style, per-asset node-name contracts,
import settings, and how final art replaces the procedural placeholders
one file at a time — see [ASSET_PIPELINE.md](./ASSET_PIPELINE.md).
