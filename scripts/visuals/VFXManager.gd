extends Node
## Autoload providing a centralized, defensive VFX-spawning API for the whole
## game. Every effect lives as a self-contained scene under scenes/effects/
## (see VFXParticleUtil.gd for the shared particle-material helpers those
## scenes use) and is instantiated, parented, positioned, and configured
## here. Registered as an autoload (not a child of the Game scene) so it's
## reachable from anywhere -- including UnitAnimator/BuildingAnimator, which
## are plain RefCounted controllers with no scene-tree position of their own.
##
## Every spawn_*() function is defensive: a missing/broken effect scene, an
## invalid caller-supplied node, or a degenerate position/direction never
## raises an error up to the caller -- at worst the call is a silent no-op.
## Effect instances' own custom configure() methods are invoked via .call()
## rather than a direct method call, matching this codebase's established
## duck-typed cross-script convention (see Projectile.gd/Explosion.gd).

const MUZZLE_FLASH_SCENE: PackedScene = preload("res://scenes/effects/MuzzleFlash.tscn")
const EXPLOSION_SMALL_SCENE: PackedScene = preload("res://scenes/effects/ExplosionSmall.tscn")
const EXPLOSION_LARGE_SCENE: PackedScene = preload("res://scenes/effects/ExplosionLarge.tscn")
const SMOKE_PUFF_SCENE: PackedScene = preload("res://scenes/effects/SmokePuff.tscn")
const DUST_TRAIL_SCENE: PackedScene = preload("res://scenes/effects/DustTrail.tscn")
const CONTRAIL_SCENE: PackedScene = preload("res://scenes/effects/Contrail.tscn")
const CAPTURE_BEAM_SCENE: PackedScene = preload("res://scenes/effects/CaptureBeam.tscn")
const REPAIR_BEAM_SCENE: PackedScene = preload("res://scenes/effects/RepairBeam.tscn")
const SPAWN_WARP_SCENE: PackedScene = preload("res://scenes/effects/SpawnWarp.tscn")
const SHIELD_HIT_SCENE: PackedScene = preload("res://scenes/effects/ShieldHit.tscn")

const CONTRAIL_DEFAULT_COLOR: Color = Color(0.65, 0.85, 1.0, 0.55)

# Damage sparks reuse VFXParticleUtil's shared helpers directly rather than a
# dedicated scene, since no ShieldHit-style standalone file was requested
# for this one.
const DAMAGE_SPARK_AMOUNT: int = 10
const DAMAGE_SPARK_LIFETIME: float = 0.35
const DAMAGE_SPARK_SIZE: float = 0.12


func spawn_muzzle_flash(position: Vector3, direction: Vector3, team: int, size: float = 1.0) -> void:
	var instance: Node3D = _spawn(MUZZLE_FLASH_SCENE, position)
	if instance == null:
		return
	instance.call("configure", direction, _color_for_team(team), size)


## Attaches a trailing streak directly to the projectile (so it tracks for
## free) rather than spawning a detached one -- see Contrail.gd's continuous
## mode. The direction is a one-time snapshot of the projectile's intended
## flight path, since Projectile.gd never rotates to face it.
func spawn_projectile_trail(projectile: Node) -> void:
	if not is_instance_valid(projectile) or not (projectile is Node3D):
		return
	var trail: Node = CONTRAIL_SCENE.instantiate()
	if trail == null:
		return
	(projectile as Node3D).add_child(trail)
	var team_value: Variant = projectile.get("team")
	var team: int = team_value if team_value is int else Constants.Team.NEUTRAL
	trail.call("configure", _projectile_travel_direction(projectile), _color_for_team(team), true)


func spawn_explosion_small(position: Vector3) -> void:
	_spawn(EXPLOSION_SMALL_SCENE, position)


func spawn_explosion_large(position: Vector3) -> void:
	_spawn(EXPLOSION_LARGE_SCENE, position)


func spawn_smoke_puff(position: Vector3) -> void:
	_spawn(SMOKE_PUFF_SCENE, position)


func spawn_dust_trail(position: Vector3, velocity: Vector3) -> void:
	var instance: Node3D = _spawn(DUST_TRAIL_SCENE, position)
	if instance == null:
		return
	instance.call("configure", velocity)


func spawn_contrail(position: Vector3, velocity: Vector3) -> void:
	var instance: Node3D = _spawn(CONTRAIL_SCENE, position)
	if instance == null:
		return
	instance.call("configure", velocity, CONTRAIL_DEFAULT_COLOR, false)


func spawn_capture_beam(from_position: Vector3, to_position: Vector3, team: int) -> void:
	var instance: Node3D = _spawn(CAPTURE_BEAM_SCENE, from_position)
	if instance == null:
		return
	instance.call("configure", from_position, to_position, _color_for_team(team))


func spawn_repair_beam(from_position: Vector3, to_position: Vector3) -> void:
	var instance: Node3D = _spawn(REPAIR_BEAM_SCENE, from_position)
	if instance == null:
		return
	instance.call("configure", from_position, to_position)


func spawn_spawn_warp(position: Vector3, team: int) -> void:
	var instance: Node3D = _spawn(SPAWN_WARP_SCENE, position)
	if instance == null:
		return
	instance.call("configure", _color_for_team(team))


func spawn_shield_hit(position: Vector3, team: int) -> void:
	var instance: Node3D = _spawn(SHIELD_HIT_SCENE, position)
	if instance == null:
		return
	instance.call("configure", _color_for_team(team))


## Small enough (and un-scened, per the requested file list) to build
## directly rather than as its own scene -- reuses VFXParticleUtil's shared
## quad-mesh/gradient helpers for consistency with the rest of the system.
func spawn_damage_sparks(position: Vector3, team: int) -> void:
	var root: Node = _get_effects_root()
	if root == null:
		return

	var sparks := GPUParticles3D.new()
	sparks.one_shot = true
	sparks.emitting = false
	sparks.lifetime = DAMAGE_SPARK_LIFETIME
	sparks.local_coords = false
	sparks.amount = DAMAGE_SPARK_AMOUNT
	sparks.draw_pass_1 = VFXParticleUtil.make_quad_mesh(DAMAGE_SPARK_SIZE)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 180.0
	material.initial_velocity_min = 1.5
	material.initial_velocity_max = 3.5
	material.gravity = Vector3(0.0, -3.0, 0.0)
	material.scale_min = 0.4
	material.scale_max = 0.9
	material.color_ramp = VFXParticleUtil.make_fade_gradient(_color_for_team(team))
	sparks.process_material = material

	root.add_child(sparks)
	sparks.global_position = position
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
	get_tree().create_timer(DAMAGE_SPARK_LIFETIME + 0.3).timeout.connect(
		func() -> void:
			if is_instance_valid(sparks):
				sparks.queue_free()
	)


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

## Instantiates `scene`, parents it under the current scene's effects root,
## and positions it -- or returns null and does nothing if any of that
## fails, so a missing/broken effect scene can never crash a caller.
func _spawn(scene: PackedScene, position: Vector3) -> Node3D:
	if scene == null:
		return null
	var root: Node = _get_effects_root()
	if root == null:
		return null
	var instance: Node = scene.instantiate()
	if instance == null:
		return null
	if not (instance is Node3D):
		instance.queue_free()
		return null
	root.add_child(instance)
	(instance as Node3D).global_position = position
	return instance as Node3D


## Effects attach under the active scene's WorldRoot/EffectsRoot (see
## Game.tscn/Tutorial.tscn) so they're cleaned up automatically on scene
## change instead of leaking under this persistent autoload. Falls back to
## the scene root, then the SceneTree root, so a spawn call is still safe
## (just less tidy) on a screen without that node.
func _get_effects_root() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	var current: Node = tree.current_scene
	if current == null:
		return tree.root
	var effects_root: Node = current.get_node_or_null("WorldRoot/EffectsRoot")
	return effects_root if effects_root != null else current


## Player = cyan/blue, Enemy = red/orange, Neutral (capture/generic) =
## white/yellow -- reuses MaterialLibrary's existing emissive palette rather
## than inventing a third one; warning_yellow() covers the neutral case
## since MaterialLibrary's own neutral_emissive() reads more silver than
## "white/yellow", and it's the same yellow already used for contested
## outposts elsewhere in the game.
func _color_for_team(team: int) -> Color:
	if team == Constants.Team.PLAYER:
		return MaterialLibrary.emissive_for_team(Constants.Team.PLAYER).albedo_color
	elif team == Constants.Team.ENEMY:
		return MaterialLibrary.emissive_for_team(Constants.Team.ENEMY).albedo_color
	return MaterialLibrary.warning_yellow().albedo_color


## A one-time direction snapshot for a projectile's trail -- Projectile.gd
## never rotates to face its travel direction, so the trail can't just read
## the node's own orientation.
func _projectile_travel_direction(projectile: Node) -> Vector3:
	var target: Variant = projectile.get("target_position")
	if not (target is Vector3) or not (projectile is Node3D):
		return Vector3.ZERO
	return (target as Vector3) - (projectile as Node3D).global_position
