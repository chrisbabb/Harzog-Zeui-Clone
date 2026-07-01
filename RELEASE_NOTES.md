# Skyforge Command — Release Notes

## Implemented features

### Core gameplay
- Transformable commander: GROUND mode (sturdier, more accurate, ground-only
  hits) and AIR mode (faster, evasive, can hit air targets), toggled with a
  brief squash-animated transform lock.
- Fuel (drains while moving, drains faster in AIR) and ammo (consumed per
  shot), both resupplied automatically near a friendly HQ or outpost.
- Direct commander combat: camera-relative aiming (right stick / aim keys),
  primary fire with a cooldown, muzzle flash, and mode-dependent
  damage/projectile speed.
- Pick up / drop: the commander can carry one friendly unit at a time
  (AIR mode only) and drop it elsewhere on the battlefield.

### Economy & production
- Per-team money with passive base income plus a bonus per owned outpost.
- Build menu (per HQ/outpost production radius) with 8 purchasable unit
  types, each with cost, hp, speed, damage, range, fire rate, armor class,
  and role, defined in `data/units.json`.
- Delivery queue with a short delay between a purchase and the unit
  physically spawning at the producing building.
- Unit cap of 60 live units per team.

### Units & orders
- 8 unit types: Scout Buggy, Tank, Missile Crawler, Artillery, Anti-Air,
  Supply Truck, Capture Drone, Heavy Walker — each a distinct scene with
  type-appropriate stats and role.
- Orders: Hold Position, Patrol Radius, Advance To Target, Attack Enemy HQ,
  Capture Nearest Outpost, Defend Friendly Outpost, Support Allies.
  Assignable via the command menu (carried unit, or nearby grounded units
  within range) or automatically by production defaults.
- NavigationAgent3D-driven pathfinding with local separation steering
  (no O(n²) full-group scans), formation spacing for coordinated HQ
  attacks, and automatic fallback to direct steering if the navmesh isn't
  ready yet.
- Opportunistic combat: units engage the nearest valid enemy in detection
  range regardless of order, prioritizing an airborne enemy commander,
  then an enemy actively capturing a friendly outpost, then the nearest
  skirmish target, then their explicitly ordered HQ target.
- Supply Trucks project a resupply aura (hp/fuel/ammo) to nearby allies,
  seeking out whichever ally needs it most.

### Buildings
- HQ (`Base.gd`): cannot be captured, only destroyed — destruction ends
  the match immediately in favor of the opposing team. Repairs/refuels/
  reloads nearby friendly commander and units; can produce any unit type.
- Outpost (`Outpost.gd`): starts neutral, captured by uncontested
  occupation (commander in GROUND mode, or a unit under a Capture order)
  over time; capture speed scales with the occupant's capture power.
  Provides weaker resupply than the HQ and a restricted build list. Can
  also be destroyed outright by sustained fire, in which case it's gone
  for the rest of the match rather than reverting to neutral.
- Both building types show a floating health bar once damaged, flash
  white on hit, and are armor-scaled (light/medium/heavy damage
  multipliers).

### AI opponent (Single Player)
- Three difficulty tiers (Easy/Normal/Hard) tuning decision frequency,
  bonus income, attack-wave thresholds/intervals, and unit-choice weights.
- Periodic decision loop: builds units based on current outpost count,
  HQ threat level, and unit composition; assigns/rebalances orders across
  its whole army each tick.
- Launches coordinated attack waves once enough combat units have
  accumulated (or a max interval elapses), instead of trickling units in
  one at a time.
- Separate AI-controlled commander (`EnemyCommanderBot.gd`) with its own
  state machine: patrol between HQ and frontline outpost, detect and
  engage the player commander, harass player outposts, retreat and
  resupply at low hp/fuel/ammo, and periodically fly out to upgrade a
  nearby idle unit's order.

### Local Multiplayer
- Player 1 vs Player 2 on a shared battlefield, no AI, split-screen
  (vertical or horizontal, chosen at setup).
- Two independent `Commander` instances (P1 team BLUE / P2 team RED), two
  camera rigs with independent follow/shake, two SubViewports built at
  runtime, two full HUDs (money, HQ bars, commander panel, minimap, build
  menu, command menu, pause menu).
- Player 1: keyboard/mouse, read directly (bypassing the shared action
  map) to avoid a connected controller bleeding into Player 1's input.
- Player 2: controller only, read directly from joypad device 0 with
  manual edge-detection for transform/pickup toggles.
- Every per-player UI script (HUD, BuildMenu, CommandMenu, PauseMenu,
  Minimap) filters incoming input by device type once
  `GameState.game_mode == LOCAL_MULTIPLAYER`, so a keyboard press from P1
  can't also trigger P2's menus/pause/minimap-zoom and vice versa — even
  when both players' menus happen to be open at once.
- Economy, unit caps, and match-end logic all work identically to Single
  Player with PLAYER/ENEMY simply mapped to two human teams instead of
  human-vs-AI.

### Tutorial
- 13-step guided practice match (move, transform, refuel, open build
  menu, build a Capture Drone, pick it up, drop it near an outpost,
  assign a capture order, wait for capture, build a Tank, send it to
  attack, destroy a target dummy, finish) with contextual on-screen
  instructions and a highlight marker pointing at the current objective.
- No enemy HQ, no AI — an isolated, low-risk practice space.

### UI & persistence
- HUD: credits/income/outpost count, match timer, HQ health bars (own +
  opponent, from each viewer's own perspective), commander panel
  (mode/hp/fuel/ammo/carried unit), selected unit/order labels, transient
  feedback messages, and a full match-end summary (result, time, units
  built/lost/destroyed, outposts captured) with rematch/main-menu options.
- Minimap: live-plotted units, buildings, HQs, and camera frustum
  rectangle, redrawn at 8 Hz, with 3 zoom levels.
- Build menu, command menu, pause menu, options menu (audio sliders,
  fullscreen, difficulty, camera shake) — all keyboard/mouse and
  controller navigable.
- Skirmish Setup screen: game mode (Single Player vs AI / Local
  Multiplayer), split-screen direction, map, difficulty, starting
  credits, match speed, outpost count.
- Settings persisted to `user://settings.json` (master/music/sfx volume,
  fullscreen, resolution, camera shake, minimap zoom, difficulty),
  applied immediately on change and reloaded on next launch.
- Placeholder audio: every gameplay/UI event has a short
  procedurally-generated tone (or silence for music) so there's audio
  feedback with zero imported assets; dropping a matching `.wav`/`.ogg`
  into `assets/audio/placeholder/` overrides the generated tone with no
  script changes.
- In-game debug panel (F1, debug builds only): live stats, money/unit
  spawn cheats, force-capture, damage-enemy-HQ, AI toggle, god mode.

## Known limitations

- No networked multiplayer — Local Multiplayer is same-machine,
  split-screen only.
- Local Multiplayer supports exactly one controller (device 0) for
  Player 2; no hot-swap or auto-assignment if it disconnects.
- Minimap zoom level persists to a single shared settings file, so
  whichever player last changed it sets the default for next launch
  (each player's zoom is still independent *during* a match).
- All art is procedural primitive geometry and all audio is procedurally
  generated placeholder tones — no imported/binary art or audio assets
  ship with the project.
- No in-game control remapping UI (edit Project Settings → Input Map).
- No gamepad vibration/haptics.
- Only 3 maps, 3 difficulty tiers, and 8 unit types.
- `export_presets.cfg` (Windows Desktop) was hand-authored without access
  to a Godot editor/binary in the environment that produced it — verify
  it opens cleanly in **Project → Export** before relying on it.
- No automated test suite yet (`tests/unit_tests/` is an empty scaffold).
- Support is limited to 2 teams/2 players; the team/economy model is
  PLAYER/ENEMY rather than an arbitrary N-team roster.
