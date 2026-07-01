# Skyforge Command — Art Direction

This document defines the final visual identity of Skyforge Command: a
readable, colorful, arcade-tactical battlefield viewed from a fixed
orthographic angle. It is the reference for every new asset, effect, and
UI panel — new work should look like it belongs next to what's described
here, whether or not the underlying mesh is still a primitive placeholder.

Where useful, sections cite the actual constants/files that currently
implement (or should implement) each rule, so this stays a working
reference rather than a mood board. Gaps between this document and the
current build are tracked in the [TODO](#todo--final-presentation-pass)
at the end.

---

## 1. Visual Pillars

- **2.5D orthographic sci-fi battlefield** — a fixed angled-down camera
  over a hard-surfaced military sci-fi world, not a top-down map and not
  a free 3D camera.
- **Readable silhouettes first** — every unit, building, and effect must
  be identifiable by outline alone, at a glance, mid-battle, from the
  fixed camera angle. Silhouette beats detail every time.
- **Colorful team identity** — team ownership is always obvious at a
  glance via color, never something the player has to check a label for.
- **Chunky low-poly shapes** — bold primitive-driven forms (boxes,
  wedges, cylinders, torii) with clear proportions rather than
  high-frequency surface detail. Simplicity is a style choice, not a
  placeholder excuse — final art should still read as chunky/low-poly.
- **Retro arcade energy** — punchy colors, snappy animation, immediate
  feedback. Nothing about combat should feel slow or muddy to read.
- **Modern polish** — clean emissive lighting, soft ambient fill, subtle
  fog depth, and consistent material language elevate the chunky/retro
  shapes so the result reads as intentional, not unfinished.

## 2. Camera & Composition

- **Orthographic 2.5D view.** No perspective distortion — object size on
  screen never changes with distance, which is what keeps silhouettes
  and team colors legible across the whole battlefield. Current tuning:
  `Camera3D.projection = ORTHOGONAL`, `size = 42.0`, mounted on a rig at
  a `(10.61, 25.98, 10.61)` offset with a `(-60°, 45°, 0°)` tilt (see
  `Game.tscn` / `LocalMultiplayer.tscn`'s per-player camera rigs).
- **The battlefield must read clearly at all zoom levels.** The world
  camera itself is fixed-size by design (consistent readability beats
  a zoomable camera that can crush silhouettes at extremes); the
  minimap instead offers three discrete zoom tiers (`60`/`40`/`20`
  world units — see `Minimap._zoom_levels`). Every icon/rect drawn on
  the minimap must stay legible at all three.
- **Exaggerated silhouettes for important objects.** HQs and outposts
  are built to dominate their footprint (wide `TEAM_STRIP` rings,
  tall health bars) precisely so they never get lost among units at
  this camera angle. New buildings/effects should follow the same rule:
  when in doubt, make the important thing bigger or brighter, not more
  detailed.
- **Units must never blend into terrain.** Every unit and commander
  carries a thin, always-visible, unshaded emissive team-color ring at
  its base (`_create_team_strip()` in `Unit.gd`/`Commander.gd`/
  `EnemyCommanderBot.gd`/`Base.gd`) specifically so a small silhouette
  against a same-toned terrain zone still pops via color and glow.

## 3. Color Palette

Team colors are the single source of truth for ownership at a glance;
everything else exists to support them without competing for attention.

| Group | Color | Hex | Godot `Color(...)` | Source |
| --- | --- | --- | --- | --- |
| **Player team** | Cyan-blue | `#3399FF` | `(0.2, 0.6, 1.0)` | `Constants.COLOR_PLAYER` |
| Player accents (projectiles) | Bright cyan | `#59D9FF` | `(0.35, 0.85, 1.0)` | `Projectile.PLAYER_PROJECTILE_COLOR` |
| Player accents (minimap dot) | Light cyan | `#66D9FF` | `(0.4, 0.85, 1.0)` | `Minimap._draw_commander()` |
| Player accents (contrail) | Pale sky blue | `#A6D9FF` @ 55% | `(0.65, 0.85, 1.0, 0.55)` | `Commander.CONTRAIL_COLOR` |
| **Enemy team** | Red-orange | `#FF4D33` | `(1.0, 0.3, 0.2)` | `Constants.COLOR_ENEMY` |
| Enemy accents (projectiles) | Amber-orange | `#FF8C26` | `(1.0, 0.55, 0.15)` | `Projectile.ENEMY_PROJECTILE_COLOR` |
| **Neutral** | Gray | `#999999` | `(0.6, 0.6, 0.6)` | `Constants.COLOR_NEUTRAL` |
| Neutral utility (highlight/objective) | Warm yellow | `#FFD933` | `(1.0, 0.85, 0.2)` | `Tutorial.HIGHLIGHT_COLOR` |
| Neutral utility (flash/white) | White | `#FFFFFF` | `(1.0, 1.0, 1.0)` | `Constants.DAMAGE_FLASH_COLOR` |
| **Terrain — green** | Muted olive | `#475C3D` | `(0.28, 0.36, 0.24)` | `MapGenerator.ZONE_GRASS_COLOR` |
| **Terrain — desert/metal plate** | Dusty blue-gray | `#545963` | `(0.33, 0.35, 0.39)` | `MapGenerator.ZONE_METAL_COLOR` |
| Terrain — roads | Near-black gray | `#26262B` | `(0.15, 0.15, 0.17)` | `MapGenerator.ROAD_COLOR` |
| Terrain — rocky ground tint | Dusty brown | `#4D453B` | `(0.30, 0.27, 0.23)` | `MapGenerator.ROCKY_COLOR` |
| **Metal** (obstacles/hulls) | Dark blue-gray | `#6B6157` | `(0.42, 0.38, 0.34)` | `MapGenerator.OBSTACLE_COLOR` |
| **Energy — cyan** | Bright cyan | `#59D9FF` | `(0.35, 0.85, 1.0)` | shared with player projectiles |
| **Energy — orange** | Hot orange | `#FF731A` | `(1.0, 0.45, 0.1)` | `Explosion.LARGE_COLOR` |
| **Energy — white/yellow** | Neutral capture-adjacent VFX | `#FFD933` | `(1.0, 0.85, 0.2)` | `MaterialLibrary.warning_yellow()`, reused by `VFXManager` for neutral-team effects |
| **Danger — red** | Enemy red | `#FF4D33` | `(1.0, 0.3, 0.2)` | shared with `COLOR_ENEMY` |
| **Danger — yellow** | Alert yellow | `#FFD933` | `(1.0, 0.85, 0.2)` | shared with neutral utility |
| Sky / void | Deep navy | `#0A0D17` | `(0.04, 0.05, 0.09, 1)` | `WorldEnvironment.background_color` |
| Ambient fill light | Cool blue-gray | `#8C9EBF` | `(0.55, 0.62, 0.75, 1)` | `WorldEnvironment.ambient_light_color` |
| Fog | Cool blue-gray | `#8C9EC7` | `(0.55, 0.62, 0.78, 1)` | `WorldEnvironment.fog_light_color` |
| Sun / key light | Near-white | `#F5F5FF` | `(0.96, 0.96, 1.0, 1)` | `DirectionalLight3D.light_color` |

**Rules of use:**
- Player = cyan/blue, Enemy = red/orange, always. Never swap, never use
  either hue for anything that isn't a team-owned object.
- Neutral gray/white/yellow is reserved for un-owned outposts, damage
  flashes, and UI/tutorial call-outs — it should never compete visually
  with the two team colors.
- Danger red/yellow (low HP, low fuel/ammo, contested capture) reuses the
  Enemy red and Neutral-utility yellow rather than inventing new hues, so
  "danger" always reads as an escalation of colors the player already
  associates with threat, not a third unrelated color language.
- Terrain and metal tones stay desaturated and dark on purpose — they are
  the stage, not the actors. Nothing on the ground plane should be as
  saturated as a team color, a projectile, or an explosion.

## 4. Materials

| Surface | Treatment | Notes |
| --- | --- | --- |
| Terrain (ground, terrain zones, roads, rocky patches) | Soft matte | Plain `StandardMaterial3D`, default (lit) shading, no emission, no specular emphasis — terrain must never glint or draw the eye. |
| Units (hulls, turrets, wheels) | Semi-matte painted metal | Default-lit `StandardMaterial3D` tinted with the owning team's flat color (`Unit._apply_team_color()` applies one shared material across every `MeshInstance3D` on the unit). Low specular, no gloss — reads as painted armor plate, not chrome. |
| Buildings (HQ/outpost hulls) | Darker metal with emissive strips | Hull uses the same semi-matte team-tinted material as units, one shade darker/duller in practice since buildings are meant to recede slightly behind units; the team-color **strip/ring is a separate unshaded, emissive material** (`SHADING_MODE_UNSHADED`, `emission_enabled = true`) so it glows independent of scene lighting. |
| Projectiles | Fully emissive | `SHADING_MODE_UNSHADED` + `emission_enabled` at `emission_energy_multiplier` 1.4 (standard shots) / 2.2 (artillery arcs) — projectiles should always look like pure light, never a lit solid. |
| Capture rings (outpost) | Transparent emissive | Unshaded emissive `TorusMesh`, brightness and scale pulse while a capture is in progress (`Outpost._update_ring_animation()`), idle-rotating even when uncontested so an outpost never reads as "dead" geometry. |
| UI panels | Dark translucent with colored highlights | See [UI Style](#8-ui-style) — this is the one area not yet matching the target material language (currently default engine theme; see TODO). |

General rule: **if it's meant to be read as "energy" (weapons, capture
rings, muzzle flashes, sparks, HUD accents), it's unshaded + emissive.
If it's meant to be read as "matter" (terrain, hulls, armor), it's a
normal lit matte material.** Never mix the two on the same mesh part.

## 5. Unit Silhouette Rules

Every unit must be identifiable by outline alone at the standard camera
angle. Current placeholder geometry already follows these proportions —
final art should preserve them.

| Unit | Silhouette | Current placeholder build |
| --- | --- | --- |
| **Scout Buggy** | Small, fast, wedge-shaped | Low flat `1.4 × 0.5 × 2.2` box body on four small wheels — shortest, lowest-profile ground unit in the roster. |
| **Tank** | Squat rectangle with a turret | `2.0 × 0.7 × 3.2` box hull, cylindrical turret + a single forward barrel — the "default" blocky silhouette other units are judged against. |
| **Missile Crawler** | Visible missile pod | Box hull with a distinct raised rack (`1.4 × 0.3 × 1.2`) carrying visible cylindrical missile bodies — the pod must always be readable as "ammunition," not just a box. |
| **Artillery** | Long cannon barrel | A `3.0`-long thin barrel (vs. the Tank's `1.6`) is the single defining feature — silhouette should look barrel-first from any angle. |
| **Anti-Air** | Twin angled guns | Two separate barrels (`BarrelLeft`/`BarrelRight`) on a turret base, canted outward — must read as "two guns," never mistakable for the Tank's single barrel. |
| **Supply Truck** | Boxy support vehicle with a glowing repair icon | Tallest, boxiest hull (`2.0 × 1.3 × 3.0`, no turret/barrel at all) topped with a cross/plus icon — the *absence* of any weapon silhouette plus the cross mark is what reads as "support," so the icon must stand out (target: emissive, not team-tinted like the hull — see TODO). |
| **Capture Drone** | Small utility craft with an antenna / capture dish | Smallest hull in the roster (sphere, `0.45` radius) with a thin raised antenna — deliberately reads as fragile/non-combat at a glance. |
| **Heavy Walker** | Tall, slow, bulky biped machine | Two thick vertical legs (`0.6 × 1.4 × 0.6` each) under a wide `2.6 × 1.2 × 3.0` body — tallest ground silhouette in the roster, unmistakably the "heavy" of the line even in a crowd. |

Silhouette hierarchy at a glance (smallest/lowest → largest/tallest):
Capture Drone → Scout Buggy → Missile Crawler / Anti-Air → Tank / Artillery
→ Supply Truck → Heavy Walker. New units should slot into this size
language rather than introducing a same-size competitor to an existing
role.

## 6. Building Silhouette Rules

| Building | Silhouette | Notes |
| --- | --- | --- |
| **HQ** | Large command fortress with a central core | The single biggest, tallest object either team owns — a wide team-colored ring at the base, a raised central tower. Cannot be captured, only destroyed; its silhouette should always communicate "this is the win condition." |
| **Outpost** | Medium tower with a capture ring and landing pad | Smaller than the HQ, larger than any unit; the pulsing capture ring is its defining, non-negotiable feature (see [Materials](#4-materials) / [Animation Style](#7-animation-style)). |
| **Production pad** | Visible unit spawn platform | Not yet a distinct visual element — units currently spawn at an invisible `Marker3D` (`Base.spawn_point` / `Outpost.unit_spawn_point`). Target: a lit platform/pad mesh under the spawn marker so "this is where units appear" is readable without watching it happen (see TODO). |
| **Repair/refuel zones** | Glowing circular pads | Not yet a distinct visual element — `repair_radius`/`refuel_radius` are currently gameplay-only invisible ranges on `Base`/`Outpost`. Target: a soft emissive ring/decal on the ground at each radius so players can see the resupply zone instead of memorizing it (see TODO). |

## 7. Animation Style

- **Snappy, readable, arcade-like.** No animation in this game should
  feel like it's easing gently for its own sake — transitions are quick
  and legible, or they're instant.
- **Slight bob / engine vibration on units.** Not yet implemented on the
  generic `Unit.gd` (see TODO) — target is a subtle idle micro-motion so
  a stationary unit still reads as "powered on," not a static prop.
- **Commander transformation is a clear, ~0.45-second event.** Already
  tuned via `Constants.PLAYER_TRANSFORM_TIME = 0.45`: the mesh squashes
  toward `SQUASH_SCALE (1.3, 0.7, 1.3)` at the animation's midpoint (where
  the GROUND↔AIR mesh swap also happens) and eases back to normal scale —
  fast enough to feel arcade-snappy, long enough to always be noticed.
- **Outposts pulse when contested.** Already implemented: the capture
  ring's scale and emission brightness oscillate (`RING_PULSE_SPEED`)
  whenever a team is actively capturing, and idle-rotates slowly even
  when uncontested (`RING_ROTATION_SPEED`) so it never looks inert.
- **Buildings smoke when damaged.** Not yet implemented — buildings
  currently only get a brief full-mesh white damage flash on hit
  (`DAMAGE_FLASH_DURATION = 0.12s`), with no persistent visual state at
  low HP. Target: a light smoke/spark particle emitter that kicks in
  below a HP threshold (see TODO).

## 8. UI Style

- **Clean sci-fi panels.** Flat, geometric, high-contrast — no skeuomorphic
  texture, no ornamentation beyond a clean border and a colored accent.
- **Dark translucent panels with colored highlights** (see
  [Materials](#4-materials)). Target look: a dark `StyleBoxFlat` (near the
  `#0A0D17`/`#26262B` end of the palette) at partial opacity, with a
  thin border and/or corner accent in the relevant team color — cyan for
  Player-side panels, neutral yellow/white for shared HUD chrome. **Not
  yet built:** every current panel (`HUD`, `BuildMenu`, `CommandMenu`,
  `PauseMenu`, `OptionsMenu`, `SkirmishSetup`, `MainMenu`,
  `TutorialOverlay`) still uses the default Godot engine theme with no
  custom `Theme`/`StyleBoxFlat` resource anywhere in the project (see
  TODO — this is the single biggest gap between current build and this
  document).
- **Animated bars.** HQ health, commander HP/fuel/ammo, and outpost
  capture progress are all live `ProgressBar`/scaled-mesh values already;
  they should gain color transitions at critical thresholds (see
  [Danger palette](#3-color-palette) and TODO) rather than only changing
  length.
- **Minimap with strong icon readability.** Team-colored dots for units,
  team-colored squares for HQs/outposts, a white camera-frustum outline —
  keep new minimap markers to simple filled shapes in team/neutral colors,
  never fine detail that won't survive an 8Hz-redraw, small-canvas render.
- **Command/build menu should feel like a tactical cockpit interface.**
  Numbered/hotkeyed option lists, not a shop grid — every entry reads as
  "issuing an order," reinforced by the eventual dark-panel treatment
  above plus a tactical-console accent color per menu.

## 9. VFX Style

| Effect | Style | Status |
| --- | --- | --- |
| Muzzle flashes | Short (`~0.08s`), team-colored (cyan/orange/neutral-yellow) pop, sized per weapon class | Implemented via `VFXManager.spawn_muzzle_flash()` (`Commander`/`EnemyCommanderBot`/`UnitAnimator`), replacing the old fixed warm-white sphere each of those used to build privately. |
| Energy projectiles | Colorful, fully emissive, team-colored (cyan/orange); artillery shells arc and glow brighter; leave a short trailing streak | Implemented (`Projectile.gd`; trail via `VFXManager.spawn_projectile_trail()`). |
| Small unit explosions | Compact fireball + spark burst | Implemented (`Explosion.setup(false)` for projectile impacts; `VFXManager.spawn_explosion_small()` for unit deaths). |
| Larger building explosions | Bigger, longer, brighter fireball + spark burst, triggers camera shake | Implemented (`Explosion.setup(true)` for impacts; `VFXManager.spawn_explosion_large()` on HQ/Outpost destruction). |
| Damage sparks | Quick directionless spark burst at the hit point, team-colored | Implemented (`VFXManager.spawn_damage_sparks()`, triggered by `UnitAnimator`/`BuildingAnimator` on every hit). |
| Dust trails / contrails | Kicked-up dust while moving on the ground; faint trailing streak while airborne or in flight | Implemented for the commander (`Commander`/`EnemyCommanderBot`) and for projectile trails. `VFXManager.spawn_dust_trail()`/`spawn_contrail()` exist as general-purpose effects; not yet wired to regular ground units' movement. |
| Capture beams / rings | Pulsing ring on the structure; a from-unit-to-structure beam | Ring: done (see [Animation Style](#7-animation-style)). Beam: `VFXManager.spawn_capture_beam()` is implemented and available; not auto-triggered anywhere yet since the ring pulse alone already communicates capture progress. |
| Repair beams | Short repeating pulse of energy toward whatever's being repaired | Implemented (`VFXManager.spawn_repair_beam()`, pulsed periodically by a Supply Truck's `UnitAnimator` while repairing). |
| Spawn warp | Collapsing energy column + upward burst as a unit materializes | Implemented (`VFXManager.spawn_spawn_warp()`, triggered on unit spawn). |
| Shield hit | Quick expanding ring flash at an impact point | `VFXManager.spawn_shield_hit()` is implemented and available; no gameplay shield mechanic exists yet to trigger it. |

## 10. Audio Style

| Style pillar | Current implementation |
| --- | --- |
| Punchy arcade weapon sounds | Short square-wave tones (`commander_fire` 880Hz/0.08s, `unit_fire` 660Hz/0.06s) via `AudioManager`'s procedural synth. |
| Synthetic UI clicks | Square-wave `ui_select`/`ui_cancel` tones. |
| Low bass explosions | Low-frequency "noise" waveform (`explosion_small` 140Hz, `explosion_large` 90Hz) for a percussive thump rather than a clean pitch. |
| Warning beeps for fuel/ammo | Triangle-wave `low_fuel_warning`/`low_ammo_warning`, fired once per crossing into the low-resource state (not spammed every frame). |
| Dynamic battle music intensity | **Not yet implemented.** Music is currently one flat track per state (`MENU`/`BATTLE`/`VICTORY`/`DEFEAT`, see `AudioManager.MusicTrack`) with no in-battle escalation. See TODO. |

All current audio is procedurally generated placeholder tone/noise/silence
(see `scripts/autoload/AudioManager.gd`'s header comment) — the target
above is what authored replacements should aim for, not a description of
final audio quality.

---

## TODO — Final Presentation Pass

Concrete, actionable gaps between this document and the current build.
Grouped roughly by area; order within a group is not priority order.

**UI**
- [ ] Build a shared `Theme` resource — dark translucent `StyleBoxFlat`
      panels with colored border/corner accents — and apply it across
      `HUD`, `BuildMenu`, `CommandMenu`, `PauseMenu`, `OptionsMenu`,
      `SkirmishSetup`, `MainMenu`, and `TutorialOverlay` (currently 100%
      default engine theme).
- [ ] Add color transitions to the HUD's HP/fuel/ammo bars at the
      existing low-resource thresholds (`AudioManager.LOW_FUEL_RATIO`,
      `LOW_AMMO_RATIO`) so the Danger palette reinforces the audio
      warning that already fires at that point.
- [ ] Pass over minimap icon sizes at all three zoom tiers (`60`/`40`/
      `20`) to confirm readability holds at the extremes.
- [ ] Give the command/build menus a tactical-console accent treatment
      (per-menu accent color, console-style framing) once the shared
      theme exists.

**Units & buildings**
- [ ] Give the Supply Truck's repair cross its own emissive
      white/cyan material distinct from the shared team-tint material
      `Unit._apply_team_color()` currently applies to every mesh part.
- [ ] Add a small dish/receiver detail to the Capture Drone alongside its
      existing antenna, so "capture specialist" reads even more
      unambiguously at a glance.
- [ ] Add a visible production-pad platform mesh under each HQ/outpost
      spawn marker (`Base.spawn_point`, `Outpost.unit_spawn_point` are
      currently bare `Marker3D`s with no geometry).
- [ ] Add a glowing circular ground decal/ring sized to each building's
      `repair_radius`/`refuel_radius` so the resupply zone is visible,
      not just a gameplay-only invisible range.
- [ ] Add a subtle rim-light or outline pass so small unit silhouettes
      hold up against same-toned terrain zones at a distance, beyond the
      existing base-ring/health-bar cues.
- [ ] Replace the default Godot placeholder `icon.svg` (currently the
      stock Godot robot logo, unmodified) with a custom Skyforge Command
      icon in this palette, and point `export_presets.cfg`'s
      `application/icon` at it.

**Animation**
- [ ] Add idle bob / engine-vibration micro-animation to `Unit.gd`
      (currently no idle animation on generic units at all).
- [ ] Add a damage-state smoke/spark particle emitter for buildings
      (and optionally heavily-damaged units) below a low-HP threshold —
      today, damage only produces a brief full-mesh white flash.

**VFX**
- [ ] Add dust trail particles to regular ground units (`Unit.gd`) to
      match the commander's existing dust system — currently only
      `Commander`/`EnemyCommanderBot` emit ground dust.
- [ ] Add a capture beam effect between a capturing unit/commander and
      the outpost it's capturing, to complement the already-implemented
      pulsing ring.

**Audio**
- [ ] Design and implement dynamic battle-music intensity (layered
      stems or an escalation trigger, e.g. tied to `EnemyAI._launch_wave()`
      or live nearby-unit counts) instead of the current single flat
      `BATTLE` track.
- [ ] Replace procedurally-generated placeholder SFX/music with authored
      audio per the [Audio Style](#10-audio-style) pillars, using the
      existing drop-in path (`assets/audio/placeholder/<event_name>.wav`
      or `.ogg` overrides the generated tone with no script changes).

**Art asset pass**
- [ ] Replace primitive placeholder meshes (units, buildings, terrain)
      with authored low-poly models, preserving the proportions and
      silhouette hierarchy defined in [Unit](#5-unit-silhouette-rules) and
      [Building Silhouette Rules](#6-building-silhouette-rules).
- [ ] Once real art lands, re-verify every [Materials](#4-materials) rule
      still holds (matte matter vs. emissive energy) against the new
      meshes/textures.
