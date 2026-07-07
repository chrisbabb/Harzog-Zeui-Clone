# Asset Pipeline — Replacing Procedural Placeholders with Final Art

Every unit, building, and effect in Skyforge Command currently uses
**procedural placeholder visuals** built at runtime from Godot primitives
(`UnitVisualFactory.gd`, `BuildingVisualFactory.gd`, `MaterialLibrary.gd`).
This document explains how to author and drop in final assets **one at a
time**, without breaking gameplay, animation, or the other placeholder
visuals. The companion design doc is [ART_DIRECTION.md](./ART_DIRECTION.md)
(palette, silhouette language, VFX style); this file covers the mechanical
contract between an asset file and the code.

The short version: put a correctly named `.glb` (or `.tscn` wrapper) under
`assets/art/final/`, matching the node-name contract below, and the game
uses it automatically — the procedural build remains the fallback for
everything else. See [Replacement Plan](#7-replacement-plan).

---

## 1. Recommended Asset Style

- **Low-poly stylized 3D.** Chunky primitives-forward shapes read best; the
  procedural placeholders are deliberately "final-style" so finished art
  should feel like a refinement of them, not a different game. Target
  roughly 300–1,500 triangles per unit, 2,000–6,000 per building.
- **Orthographic readability first.** The game camera is orthographic
  (size 42) pitched at −60° with a 45° yaw. Every asset must read from
  that one angle: favor strong top/three-quarter silhouettes, avoid detail
  that only reads from ground level, and keep the top surfaces interesting.
- **Exaggerated silhouettes.** At gameplay zoom a tank is ~40 px tall.
  Oversize the identifying feature of each unit (the artillery barrel, the
  walker legs, the radar dish) by 20–40% beyond realistic proportion —
  silhouette identification is the primary readability channel.
- **Team-color emissive strips.** Player = cyan/blue, enemy = red/orange,
  neutral = gray/silver (exact values in `MaterialLibrary.gd` and
  ART_DIRECTION.md). Reserve dedicated emissive strips/panels for team
  color rather than tinting the whole body; the code also floats a
  team-colored ring under every unit, so the asset itself only needs
  accents.
- **Simple animations.** Recoil kicks, spinning wheels/dishes, a small
  idle bob — nothing skeletal-heavy is required. The current procedural
  animation (see §4) is the bar to clear, not a mocap pipeline.

---

## 2. Unit Asset Requirements

**File format:** `.glb` preferred (self-contained, Godot-native import).
Optionally commit a `.tscn` wrapper alongside it when the asset needs
in-editor tuning (material overrides, offset fixes) — the wrapper takes
precedence over the raw `.glb` (see §7).

**Approximate sizes** (world units = meters; envelope the placeholder
occupies — the authoritative reference is the corresponding
`UnitVisualFactory` builder):

| Unit            | File base name    | W × H × L (approx) |
|-----------------|-------------------|--------------------|
| Scout Buggy     | `scout_buggy`     | 1.6 × 1.1 × 2.4    |
| Tank            | `tank`            | 2.3 × 1.5 × 2.8    |
| Missile Crawler | `missile_crawler` | 2.2 × 1.7 × 2.6    |
| Artillery       | `artillery`       | 2.2 × 1.6 × 3.2    |
| Anti-Air        | `anti_air`        | 2.0 × 1.8 × 2.2    |
| Supply Truck    | `supply_truck`    | 2.0 × 1.7 × 2.8    |
| Capture Drone   | `capture_drone`   | 1.4 × 1.6 × 1.4    |
| Heavy Walker    | `heavy_walker`    | 2.4 × 3.0 × 2.4    |

Forward is **−Z**, up is **+Y**, origin at ground center (the unit body
sits on y = 0). Deviating more than ~25% from these envelopes will fight
the tuned pickup/capture/collision radii.

**Required named nodes.** `UnitAnimator.gd` finds parts **by node name**
(`get_node_or_null`) — a missing name never crashes, it just silently
doesn't animate. Name these nodes exactly:

| Role (spec)        | Actual node name(s) the code looks up            | Units             |
|--------------------|---------------------------------------------------|-------------------|
| Body               | `Hull` — damage flash + team tint target          | all               |
| Turret             | `Cannon` (Tank), `Rack` (Missile Crawler), `ArmCannon` (Heavy Walker) — yaw-tracks targets, recoils | where applicable |
| Barrel / Muzzle    | `Barrel` (Artillery), `BarrelLeft`/`BarrelRight` (Anti-Air), `MissileTube0..3` + `MissileTip0..3` (Missile Crawler) | where applicable |
| Wheels             | any children named `Wheel0..N` spin automatically while moving | wheeled units |
| Special            | `RepairDish` (Supply Truck), `CaptureEmitter` (Capture Drone), `LegLeft`/`LegRight` (Heavy Walker), `BraceLeft`/`BraceRight` (Artillery) | per type |
| TeamColorSlots     | today: the `Hull` node's **material override** is tinted/flashed. Forward convention: additionally name any dedicated accent meshes `TeamColor*` so a future pass can tint them wholesale | all |
| MuzzlePoint        | `Muzzle` — a `Marker3D` that lives in the unit's **gameplay scene** (`scenes/units/*.tscn`), not the visual. If the final asset includes its own `Muzzle` marker, the integrator moves the scene marker to match | all shooters |
| DamageSmokePoint   | **reserved**: `DamageSmokePoint*` markers. `DamageStateController.gd` currently uses per-class fixed offsets; assets that include these markers are forward-compatible with switching to marker-driven emitters | all |

Integration notes per type:

- **Turret pivots are constants.** `UnitAnimator` rotates turret parts
  around a hardcoded pivot height per type (e.g. Tank `y = 1.35`). Either
  keep the final turret's pivot at the placeholder's height, or adjust the
  matching `_setup_*()` pivot in `UnitAnimator.gd` when integrating.
- **Tank treads:** `UnitAnimator._add_tread_cylinders()` currently *adds*
  placeholder tread cylinders to the tank at setup. When the final tank
  (with authored wheels/treads named `Wheel*`) lands, remove or gate that
  call — authored `Wheel*` nodes are picked up automatically.
- **Missile tips:** `MissileTip0..3` materials are duplicated and flashed
  per shot; give each tip its own small mesh.

**Collision stays in Godot.** Each unit's gameplay scene keeps its tuned
`CollisionShape3D` (capsules/boxes sized for navigation and pickup) —
do **not** rely on imported collision. Only if a final asset genuinely
needs custom collision should you provide a `-col`-suffixed mesh, and then
the integrator replaces the scene shape deliberately (see §5).

---

## 3. Building Asset Requirements

Same format rules as units. Origin at ground center, −Z toward the
battlefield front. File base names: `hq`, `outpost`.

**HQ** (`hq.glb`, envelope ≈ 9 × 14 × 9 — platform to radar tip):

| Role (spec)   | Actual node name  | Consumed by                                              |
|---------------|-------------------|----------------------------------------------------------|
| Body          | `Hull`            | damage flash + team tint (`BuildingAnimator`)             |
| Core          | `PowerCore`       | idle pulse (`BuildingAnimator`), critical flicker + death strobe (`DamageStateController`) |
| Radar         | `RadarDish`       | continuous spin (`BuildingAnimator`)                      |
| ProductionBay | `ProductionBayDoor` | glows while the build queue is busy (`BuildingAnimator`) |
| Alarm lights  | `BannerLeft`, `BannerRight` | flicker when damaged, strobe red when critical (`DamageStateController`) |
| SpawnPoint    | `SpawnPoint`      | `Marker3D` in `scenes/buildings/Base.tscn` (gameplay scene, not the asset) — units are delivered here |
| SmokePoints   | **reserved**: `SmokePoint*` markers | damage smoke currently uses fixed offsets in `DamageStateController` |

**Outpost** (`outpost.glb`, envelope ≈ 9 × 7 × 9 including the ring):

| Role (spec)  | Actual node name | Consumed by                                                |
|--------------|------------------|------------------------------------------------------------|
| Platform     | `Platform`       | static base (also `LandingPad` off to the +X/+Z corner)     |
| Tower        | `Hull`           | damage flash + team tint                                    |
| CaptureRing  | `CaptureRing`    | rotation, capture/contested/idle pulses (`BuildingAnimator`), capture-transition color rides on it |
| Core         | `OwnershipCore`  | shares the ring's material so it pulses in sync; `AntennaTip` above it blinks when critically damaged |
| SpawnPoint   | `UnitSpawnPoint` | `Marker3D` in `scenes/buildings/Outpost.tscn` (gameplay scene) |
| SmokePoints  | **reserved**: `SmokePoint*` markers | as with the HQ, currently fixed offsets |

The capture ring **must keep its own dedicated material** — the code
recolors and pulses it per team every frame, and the capture transition
(lights-off → neutral pulse → lights-on) drives it through
`BuildingAnimator.set_team()`.

---

## 4. Animation Requirements

Authored animation is optional at first — the procedural layer keeps
animating named parts on any asset that follows §2/§3. When authoring
proper clips, use an `AnimationPlayer` inside the asset with these exact
clip names, which map 1:1 onto the existing animation hooks:

| Clip            | Current procedural equivalent (what it must replace)             |
|-----------------|-------------------------------------------------------------------|
| `idle`          | position bob (`UnitAnimator._update_idle_motion`), core/ring pulses |
| `move`          | wheel spin, walker leg bob + body sway, scout bounce (only where the unit visibly needs it) |
| `fire`          | recoil kick, missile-tip flash, artillery brace shake (`on_fire`)  |
| `damaged`       | white material flash (`on_damaged`)                                |
| `destroyed`     | sink + spin + fade wreck (`on_death`/`update_wreck`, 5 s total)    |
| `capture_pulse` | outpost ring pulse while a capture is in progress                  |
| `transform`     | commander air/ground squash — only if the commander is authored later (its meshes live in `scenes/player/Commander.tscn`, not the factories) |

Integration approach: swap one unit type at a time. In the matching
`UnitAnimator` hook (`on_fire`, `on_damaged`, ...), play the authored clip
when an `AnimationPlayer` exists on the visual root, else keep the
procedural path. Keep clips short and snappy (fire ≤ 0.3 s, damaged
≤ 0.15 s) — gameplay never waits for animation.

---

## 5. Import Settings

- **Scale:** 1 Blender unit = 1 meter = 1 Godot unit. Apply all transforms
  before export (no residual object scale). Export glTF with **+Y up**;
  author facing **−Z forward**.
- **Material naming:** `M_<asset>_<part>`, e.g. `M_tank_hull`,
  `M_tank_teamcolor`. Anything that must glow uses an emissive material
  whose name contains `teamcolor` or `emissive` so it's greppable during
  integration. Note: the runtime tint/flash targets a node's *material
  override*; imported materials live on the mesh, so the damage flash will
  silently skip final assets until the integrator either sets the hull
  material as an override or extends the animator — this is graceful, not
  a crash.
- **Texture sizes:** units ≤ 1024², buildings ≤ 2048², power-of-two only.
  Prefer a small shared palette texture over per-asset albedo maps — it
  matches the flat-color art direction and keeps VRAM trivial.
- **Compression:** leave Godot's default **VRAM Compressed** import for
  3D textures (BPTC/S3TC on desktop; the project currently ships desktop
  only). UI/icon textures (§6 `ui/`, `icons/`) use **Lossless** — crisp
  edges matter more than memory there. No special `.import` overrides
  should be committed without a comment explaining why.
- **Collision import rules:** do **not** use `-col`/`-convcol`/`-colonly`
  suffixes by default — gameplay collision shapes are hand-tuned in the
  unit/building `.tscn` files and must stay authoritative (pickup radii,
  navigation, projectile hits are balanced around them). If a final asset
  ships a deliberate collision mesh, name it with Godot's `-colonly`
  suffix and the integrator swaps the scene's `CollisionShape3D`
  consciously, in the same commit that documents the balance check.

---

## 6. Directory Layout

```
assets/art/final/
  units/       scout_buggy.glb, tank.glb, ... (+ optional matching .tscn wrappers)
  buildings/   hq.glb, outpost.glb
  terrain/     rocks, ruins, road decals (replacing MapDecorations primitives)
  vfx/         authored particle textures/meshes for scenes/effects/
  ui/          panel backgrounds, frames (SkyforgeTheme.tres upgrades)
  icons/       unit/order/building icons (replacing IconFactory's raster shapes)
```

The tree exists in-repo with `.gitkeep` files. File base names are the
lowercase `Constants.UnitType` keys (see the §2 table) — the resolver
derives paths from them, so a typo in the filename means the asset is
silently ignored and the placeholder keeps rendering.

---

## 7. Replacement Plan

The factories are the single seam, and the fallback is **already wired**:

1. `UnitVisualFactory.create_visual()` (and both `BuildingVisualFactory`
   builders) first call `UnitVisualFactory.load_final_visual(file_base,
   subdir)`.
2. That resolver checks, in order:
   `assets/art/final/<subdir>/<file_base>.tscn` (artist-tuned wrapper),
   then `<file_base>.glb`. First hit is instantiated and returned as the
   visual root.
3. If neither exists (or fails to load), the procedural placeholder is
   generated exactly as before.

Because every consumer (`UnitAnimator`, `BuildingAnimator`,
`DamageStateController`) looks parts up with `get_node_or_null`, a final
asset that's missing an optional named node **degrades gracefully** — that
part just doesn't animate; nothing crashes. This means:

- Development never blocks on art: ship zero, one, or all final assets.
- Assets land one at a time, each in its own reviewable commit.
- The title-screen diorama (`TitleBackground.gd`) uses the same factories,
  so finished assets appear there automatically.
- Rollback is deleting a file.

The commander is the one visual **not** routed through a factory (its
meshes live in `Commander.tscn`); replacing it is a scene edit and is
deliberately last on the list, after its `transform` animation is
authored (§4).

---

## 8. Copyright Rules

Non-negotiable, and enforced at review:

- **No Herzog Zwei assets** — no models, sprites, sounds, music, names,
  or text from it or any other commercial game, "as homage" included.
  This game is genre-inspired only.
- **No ripped game sprites** or meshes from any source, no matter how
  heavily modified.
- **No copyrighted music** — including covers/remixes of game themes.
  `AudioManager` synthesizes placeholder tones today; replacement music
  must be original or licensed for redistribution (license file committed
  alongside the audio).
- **Use original, licensed, or self-created assets only.** CC0/CC-BY
  assets are acceptable with attribution recorded in a `CREDITS` entry;
  anything with a non-commercial or share-alike clause needs explicit
  sign-off before it enters the repo.

See also the [Asset policy](./README.md#asset-policy) section of the
README, which this expands on.
