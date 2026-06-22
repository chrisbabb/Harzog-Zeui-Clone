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

| Action | Keyboard / Mouse |
| --- | --- |
| Move forward / back | `W` / `S` (or `Up` / `Down`) |
| Move left / right | `A` / `D` (or `Left` / `Right`) |
| Fire primary weapon | `Left Mouse` or `Space` |
| Transform (ground ↔ air) | `E` |
| Pick up / drop unit | `Q` |
| Open build menu | `B` |
| Open command menu | `C` |
| Confirm | `Enter` or `Left Mouse` |
| Cancel | `Esc` or `Right Mouse` |
| Pause | `Esc` |
| Minimap zoom | `Tab` |

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

## Asset policy

Every asset in this repository must be original or appropriately licensed.
Do not add art, audio, maps, or text copied or adapted from any existing
commercial game.
