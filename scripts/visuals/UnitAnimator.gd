class_name UnitAnimator
extends RefCounted
## Per-unit procedural animation controller. One instance is created by
## Unit.gd._build_visual() for each spawned unit and driven every physics
## frame via update(), rather than living on a Node -- there is no _process()
## here, so all motion is pushed explicitly from Unit.gd's existing
## _physics_process(). Reads/writes named parts on the Visual root that
## UnitVisualFactory built (e.g. "Cannon", "TurretBase", "Wheel0"), the same
## naming contract BuildingAnimator uses on the building side.
##
## This is procedural final-style placeholder animation -- meant to be
## replaceable by authored skeletal/blend-shape animation later without
## touching Unit.gd beyond the handful of call sites documented there.

# ---------------------------------------------------------------------------
# Tuning constants
# ---------------------------------------------------------------------------

const IDLE_BOB_SPEED: float = 2.0
const IDLE_BOB_AMOUNT: float = 0.025
const DEFAULT_WHEEL_SPIN_RATE: float = 8.0

const SCOUT_WHEEL_SPIN_RATE: float = 14.0
const SCOUT_BOB_SPEED_MOVING: float = 9.0
const SCOUT_BOB_AMOUNT_MOVING: float = 0.05

const TANK_TREAD_SPIN_RATE: float = 5.0

# "Turn rate" is a lerp_angle closing-speed factor (see _ease_angle), not a
# literal radians/sec cap -- mirrors Commander.gd's ROTATION_SPEED usage.
const TURN_RATE_SLOW: float = 1.5
const TURN_RATE_NORMAL: float = 4.0
const TURN_RATE_FAST: float = 9.0

const RECOIL_DISTANCE_LIGHT: float = 0.08
const RECOIL_DISTANCE_NORMAL: float = 0.15
const RECOIL_DISTANCE_STRONG: float = 0.35
const RECOIL_DISTANCE_HEAVY: float = 0.3
const RECOIL_RECOVER_SPEED: float = 3.5

const MISSILE_TILT_PITCH: float = -18.0 * PI / 180.0
const MISSILE_TUBE_FLASH_DURATION: float = 0.15
const MISSILE_TUBE_FLASH_ENERGY: float = 5.0

const BRACE_SHAKE_DURATION: float = 0.25
const BRACE_SHAKE_AMOUNT: float = 0.04
const BRACE_SHAKE_FREQUENCY: float = 60.0

const LEG_BOB_SPEED: float = 5.0
const LEG_BOB_AMOUNT: float = 0.08
const BODY_SWAY_SPEED: float = 2.5
const BODY_SWAY_AMOUNT: float = 0.035

const MUZZLE_FLASH_SIZE_LIGHT: float = 0.7
const MUZZLE_FLASH_SIZE_NORMAL: float = 1.0
const MUZZLE_FLASH_SIZE_HEAVY: float = 1.4

const WRECK_FADE_DURATION: float = 5.0
const DEATH_SINK_DISTANCE: float = 0.35
const WRECK_SPIN_MAX_RATE: float = 1.4
const WRECK_SPIN_DECAY: float = 1.2

# Squash-and-rebound when the commander drops this unit.
const DROP_BOUNCE_DURATION: float = 0.35
const DROP_SQUASH_AMOUNT: float = 0.22

# Brief backward lean when starting to move from a standstill.
const ANTICIPATION_DURATION: float = 0.18
const ANTICIPATION_TILT: float = 0.07
const DEATH_SPARK_AMOUNT: int = 16
const DEATH_SPARK_SIZE: float = 0.15
const DEATH_SMOKE_AMOUNT: int = 10
const DEATH_SMOKE_SIZE: float = 0.4

const REPAIR_DISH_SPIN_SPEED: float = 2.4
const REPAIR_DISH_IDLE_SPIN_SPEED: float = 0.3
const REPAIR_PULSE_INTERVAL: float = 0.4

const CAPTURE_DISH_SPIN_SPEED: float = 3.2
const CAPTURE_DISH_IDLE_SPIN_SPEED: float = 0.4
const CAPTURE_BEAM_AMOUNT: int = 14
const CAPTURE_BEAM_LIFETIME: float = 0.6
const CAPTURE_BEAM_PARTICLE_SIZE: float = 0.1

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _visual_root: Node3D
var _unit_type: int = -1
var _team: int = Constants.Team.PLAYER
var _time: float = 0.0
var _phase: float = 0.0

var _hull_mesh: MeshInstance3D
var _hull_material: StandardMaterial3D
var _flash_remaining: float = 0.0

var _bob_speed_idle: float = IDLE_BOB_SPEED
var _bob_amount_idle: float = IDLE_BOB_AMOUNT
var _bob_speed_moving: float = IDLE_BOB_SPEED
var _bob_amount_moving: float = IDLE_BOB_AMOUNT

var _wheels: Array[Node3D] = []
var _wheel_spin_rate: float = DEFAULT_WHEEL_SPIN_RATE

var _fire_origin_node: Node3D = null
var _muzzle_marker: Node3D = null

# Turret/barrel group shared by Tank, Artillery, Anti-Air, Heavy Walker and
# the Missile Crawler's rack -- see _add_turret_part()/_update_turret().
var _turret_parts: Array[Dictionary] = []
var _turret_pivot_position: Vector3 = Vector3.ZERO
var _turret_turn_rate: float = TURN_RATE_NORMAL
var _turret_yaw: float = 0.0
var _turret_pitch: float = 0.0

var _alt_fire_index: int = 0

var _missile_tips: Array[MeshInstance3D] = []
var _missile_tip_materials: Array[StandardMaterial3D] = []
var _missile_tip_rest_energy: float = 1.6
var _missile_flash_index: int = -1
var _missile_flash_remaining: float = 0.0

var _brace_nodes: Array[Node3D] = []
var _brace_rest_positions: Array[Vector3] = []
var _brace_shake_remaining: float = 0.0

var _leg_left: Node3D = null
var _leg_right: Node3D = null
var _leg_rest_y_left: float = 0.0
var _leg_rest_y_right: float = 0.0

var _repair_dish: Node3D = null
var _repair_pulse_timer: float = 0.0

var _capture_dish: Node3D = null
var _capture_beam: GPUParticles3D = null

var _is_dead: bool = false
var _wreck_remaining: float = 0.0
var _death_sink_start_y: float = 0.0
var _wreck_spin_rate: float = 0.0
var _smoke_particles: GPUParticles3D = null
var _wreck_meshes: Array[MeshInstance3D] = []

var _drop_bounce_remaining: float = 0.0
var _anticipation_remaining: float = 0.0
var _was_moving: bool = false


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(visual_root: Node3D, unit_type: int, team: int, muzzle_marker: Node3D = null) -> void:
	_visual_root = visual_root
	_unit_type = unit_type
	_team = team
	_muzzle_marker = muzzle_marker
	_phase = randf() * TAU

	_hull_mesh = _visual_root.get_node_or_null("Hull")
	if _hull_mesh != null:
		_hull_material = _hull_mesh.material_override as StandardMaterial3D

	match unit_type:
		Constants.UnitType.SCOUT_BUGGY:
			_setup_scout_buggy()
		Constants.UnitType.TANK:
			_setup_tank()
		Constants.UnitType.MISSILE_CRAWLER:
			_setup_missile_crawler()
		Constants.UnitType.ARTILLERY:
			_setup_artillery()
		Constants.UnitType.ANTI_AIR:
			_setup_anti_air()
		Constants.UnitType.SUPPLY_TRUCK:
			_setup_supply_truck()
		Constants.UnitType.CAPTURE_DRONE:
			_setup_capture_drone()
		Constants.UnitType.HEAVY_WALKER:
			_setup_heavy_walker()

	_collect_wheels()


func _setup_scout_buggy() -> void:
	_bob_speed_moving = SCOUT_BOB_SPEED_MOVING
	_bob_amount_moving = SCOUT_BOB_AMOUNT_MOVING
	_wheel_spin_rate = SCOUT_WHEEL_SPIN_RATE


func _setup_tank() -> void:
	_setup_turret_group(Vector3(0.0, 1.35, 0.0), TURN_RATE_NORMAL)
	_fire_origin_node = _add_turret_part("Cannon", RECOIL_DISTANCE_NORMAL).get("node")
	_add_tread_cylinders()
	_wheel_spin_rate = TANK_TREAD_SPIN_RATE


func _setup_missile_crawler() -> void:
	_setup_turret_group(Vector3(0.0, 1.05, 0.0), TURN_RATE_NORMAL)
	_add_turret_part("Rack", 0.0)
	for i in range(4):
		_add_turret_part("MissileTube%d" % i, 0.0)
		var tip_entry: Dictionary = _add_turret_part("MissileTip%d" % i, 0.0)
		if tip_entry.is_empty():
			continue
		var tip: MeshInstance3D = tip_entry["node"]
		# MissileTip meshes share MaterialLibrary.warning_yellow() directly
		# across every crawler on the field -- duplicate before mutating it
		# so flashing one tube doesn't flash every tip in the game.
		var flash_material: StandardMaterial3D = (tip.material_override as StandardMaterial3D).duplicate()
		tip.material_override = flash_material
		_missile_tips.append(tip)
		_missile_tip_materials.append(flash_material)
	if not _missile_tip_materials.is_empty():
		_missile_tip_rest_energy = _missile_tip_materials[0].emission_energy_multiplier
	_fire_origin_node = _visual_root.get_node_or_null("MissileTip0")


func _setup_artillery() -> void:
	_setup_turret_group(Vector3(0.0, 0.9, 0.0), TURN_RATE_SLOW)
	_fire_origin_node = _add_turret_part("Barrel", RECOIL_DISTANCE_STRONG).get("node")
	_collect_braces(["BraceLeft", "BraceRight"])


func _setup_anti_air() -> void:
	_setup_turret_group(Vector3(0.0, 1.1, 0.0), TURN_RATE_FAST)
	_fire_origin_node = _add_turret_part("BarrelLeft", RECOIL_DISTANCE_LIGHT).get("node")
	_add_turret_part("BarrelRight", RECOIL_DISTANCE_LIGHT)


func _setup_supply_truck() -> void:
	_repair_dish = _visual_root.get_node_or_null("RepairDish")


func _setup_capture_drone() -> void:
	_capture_dish = _visual_root.get_node_or_null("CaptureEmitter")
	_capture_beam = GPUParticles3D.new()
	_capture_beam.amount = CAPTURE_BEAM_AMOUNT
	_capture_beam.lifetime = CAPTURE_BEAM_LIFETIME
	_capture_beam.local_coords = true
	_capture_beam.emitting = false
	_capture_beam.draw_pass_1 = _make_particle_quad(CAPTURE_BEAM_PARTICLE_SIZE)
	_capture_beam.process_material = _make_capture_burst_material(MaterialLibrary.emissive_for_team(_team).albedo_color)
	if _capture_dish != null:
		_capture_beam.position = _capture_dish.position
	_visual_root.add_child(_capture_beam)


func _setup_heavy_walker() -> void:
	_setup_turret_group(Vector3(0.0, 2.0, 0.0), TURN_RATE_NORMAL)
	_fire_origin_node = _add_turret_part("ArmCannon", RECOIL_DISTANCE_HEAVY).get("node")
	_bob_amount_idle = IDLE_BOB_AMOUNT * 0.5
	_leg_left = _visual_root.get_node_or_null("LegLeft")
	_leg_right = _visual_root.get_node_or_null("LegRight")
	if _leg_left != null:
		_leg_rest_y_left = _leg_left.position.y
	if _leg_right != null:
		_leg_rest_y_right = _leg_right.position.y


# ---------------------------------------------------------------------------
# Per-frame update
# ---------------------------------------------------------------------------

## support_target is only meaningful for Supply Truck (who it's repairing,
## if anyone); is_capturing only for Capture Drone. Both are cheap no-ops for
## every other type, so Unit.gd can pass them unconditionally.
func update(delta: float, is_moving: bool, target: Node = null, support_target: Node = null, is_capturing: bool = false) -> void:
	_time += delta
	if is_moving and not _was_moving:
		_anticipation_remaining = ANTICIPATION_DURATION
	_was_moving = is_moving
	_update_flash(delta)
	_update_idle_motion(is_moving)
	_update_drop_bounce(delta)
	_update_anticipation(delta)
	_update_wheels(delta, is_moving)

	if not _turret_parts.is_empty():
		_update_turret(delta, target)

	if _unit_type == Constants.UnitType.ARTILLERY:
		_update_brace_shake(delta)
	elif _unit_type == Constants.UnitType.MISSILE_CRAWLER:
		_update_missile_flash(delta)
	elif _unit_type == Constants.UnitType.SUPPLY_TRUCK:
		_update_supply_truck(delta, support_target)
	elif _unit_type == Constants.UnitType.CAPTURE_DRONE:
		_update_capture_drone(delta, is_capturing)
	elif _unit_type == Constants.UnitType.HEAVY_WALKER:
		_update_walker(delta, is_moving)


func _update_idle_motion(is_moving: bool) -> void:
	var speed: float = _bob_speed_moving if is_moving else _bob_speed_idle
	var amount: float = _bob_amount_moving if is_moving else _bob_amount_idle
	_visual_root.position.y = sin(_time * speed + _phase) * amount


## Damped squash-and-rebound after the commander drops this unit: lands
## squashed, overshoots tall, settles to rest -- reads as weight.
func _update_drop_bounce(delta: float) -> void:
	if _drop_bounce_remaining <= 0.0:
		return
	_drop_bounce_remaining -= delta
	if _drop_bounce_remaining <= 0.0:
		_visual_root.scale = Vector3.ONE
		return
	var progress: float = 1.0 - _drop_bounce_remaining / DROP_BOUNCE_DURATION
	var squash: float = DROP_SQUASH_AMOUNT * (1.0 - progress) * cos(progress * TAU)
	_visual_root.scale = Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5)


## Brief backward lean as the unit starts moving from a standstill --
## anticipation before the push-off. Only rotation.x is touched, so it
## composes with the walker's rotation.z sway and the idle position bob.
func _update_anticipation(delta: float) -> void:
	if _anticipation_remaining <= 0.0:
		return
	_anticipation_remaining -= delta
	if _anticipation_remaining <= 0.0:
		_visual_root.rotation.x = 0.0
		return
	var progress: float = 1.0 - _anticipation_remaining / ANTICIPATION_DURATION
	_visual_root.rotation.x = ANTICIPATION_TILT * sin(progress * PI)


func _update_wheels(delta: float, is_moving: bool) -> void:
	if _wheels.is_empty() or not is_moving:
		return
	for wheel in _wheels:
		wheel.rotate_x(_wheel_spin_rate * delta)


func _collect_wheels() -> void:
	for child in _visual_root.get_children():
		if child is MeshInstance3D and (child as Node).name.begins_with("Wheel"):
			_wheels.append(child)


func _add_tread_cylinders() -> void:
	var positions: Array[Vector3] = [
		Vector3(1.05, 0.35, 1.0), Vector3(1.05, 0.35, -1.0),
		Vector3(-1.05, 0.35, 1.0), Vector3(-1.05, 0.35, -1.0),
	]
	for i in range(positions.size()):
		var wheel := MeshInstance3D.new()
		wheel.name = "Wheel%d" % i
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.32
		mesh.bottom_radius = 0.32
		mesh.height = 0.22
		wheel.mesh = mesh
		wheel.material_override = MaterialLibrary.dark_metal()
		wheel.position = positions[i]
		wheel.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		_visual_root.add_child(wheel)


# ---------------------------------------------------------------------------
# Turret/barrel tracking + recoil
# ---------------------------------------------------------------------------

func _setup_turret_group(pivot_position: Vector3, turn_rate: float) -> void:
	_turret_pivot_position = pivot_position
	_turret_turn_rate = turn_rate


## Registers a part that orbits _turret_pivot_position and rotates with the
## turret's yaw (and, for the Missile Crawler, pitch). A part whose rest
## position IS the pivot (zero offset) still gets its own rotation applied,
## which is how e.g. the missile Rack itself turns in place. Returns the
## created entry (or {} if the named node doesn't exist) so callers that
## need the node again (missile tip flashing) don't have to look it up twice.
func _add_turret_part(node_name: String, recoil_distance: float) -> Dictionary:
	var node: Node3D = _visual_root.get_node_or_null(node_name)
	if node == null:
		return {}
	var entry: Dictionary = {
		"node": node,
		"rest_offset": node.position - _turret_pivot_position,
		"rest_basis": node.transform.basis,
		"recoil_distance": recoil_distance,
		"recoil_progress": 0.0,
	}
	_turret_parts.append(entry)
	return entry


func _update_turret(delta: float, target: Node) -> void:
	var has_target: bool = target != null and is_instance_valid(target)
	var desired_yaw: float = 0.0
	if has_target:
		var to_target: Vector3 = target.global_position - _visual_root.global_position
		to_target.y = 0.0
		if to_target.length() > 0.05:
			var local_dir: Vector3 = _visual_root.global_transform.basis.inverse() * to_target.normalized()
			desired_yaw = atan2(local_dir.x, local_dir.z)

	_turret_yaw = _ease_angle(_turret_yaw, desired_yaw, _turret_turn_rate, delta)

	if _unit_type == Constants.UnitType.MISSILE_CRAWLER:
		var desired_pitch: float = MISSILE_TILT_PITCH if has_target else 0.0
		_turret_pitch = _ease_angle(_turret_pitch, desired_pitch, _turret_turn_rate, delta)

	var combined: Basis = Basis(Vector3.UP, _turret_yaw) * Basis(Vector3.RIGHT, _turret_pitch)

	for part in _turret_parts:
		var rest_offset: Vector3 = part["rest_offset"]
		var recoil_vec: Vector3 = Vector3.ZERO
		if part["recoil_distance"] > 0.0:
			var progress: float = part["recoil_progress"]
			if progress > 0.0:
				var outward: Vector3 = rest_offset.normalized() if rest_offset.length() > 0.01 else Vector3.BACK
				recoil_vec = -outward * part["recoil_distance"] * progress
				part["recoil_progress"] = max(0.0, progress - RECOIL_RECOVER_SPEED * delta)
		var node: Node3D = part["node"]
		node.transform = Transform3D(combined * part["rest_basis"], _turret_pivot_position + combined * (rest_offset + recoil_vec))


func _trigger_recoil() -> void:
	if _unit_type == Constants.UnitType.ANTI_AIR:
		# Alternates which barrel actually kicks/flashes each shot.
		var target_name: String = "BarrelLeft" if _alt_fire_index == 0 else "BarrelRight"
		_alt_fire_index = 1 - _alt_fire_index
		for part in _turret_parts:
			if (part["node"] as Node3D).name == target_name:
				part["recoil_progress"] = 1.0
				_fire_origin_node = part["node"]
		return

	for part in _turret_parts:
		if part["recoil_distance"] > 0.0:
			part["recoil_progress"] = 1.0


static func _ease_angle(current: float, target: float, rate: float, delta: float) -> float:
	return lerp_angle(current, target, clamp(rate * delta, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Missile Crawler tube flash
# ---------------------------------------------------------------------------

func _trigger_missile_flash() -> void:
	if _missile_tips.is_empty():
		return
	_missile_flash_index = (_missile_flash_index + 1) % _missile_tips.size()
	_missile_flash_remaining = MISSILE_TUBE_FLASH_DURATION
	_fire_origin_node = _missile_tips[_missile_flash_index]
	_missile_tip_materials[_missile_flash_index].emission_energy_multiplier = MISSILE_TUBE_FLASH_ENERGY


func _update_missile_flash(delta: float) -> void:
	if _missile_flash_remaining <= 0.0:
		return
	_missile_flash_remaining -= delta
	if _missile_flash_remaining <= 0.0:
		_missile_tip_materials[_missile_flash_index].emission_energy_multiplier = _missile_tip_rest_energy


# ---------------------------------------------------------------------------
# Artillery stabilizer brace shake
# ---------------------------------------------------------------------------

func _collect_braces(names: Array) -> void:
	for brace_name in names:
		var node: Node3D = _visual_root.get_node_or_null(brace_name)
		if node != null:
			_brace_nodes.append(node)
			_brace_rest_positions.append(node.position)


func _trigger_brace_shake() -> void:
	_brace_shake_remaining = BRACE_SHAKE_DURATION


func _update_brace_shake(delta: float) -> void:
	if _brace_nodes.is_empty() or _brace_shake_remaining <= 0.0:
		return
	_brace_shake_remaining -= delta
	var decay: float = clamp(_brace_shake_remaining / BRACE_SHAKE_DURATION, 0.0, 1.0)
	if _brace_shake_remaining <= 0.0:
		for i in range(_brace_nodes.size()):
			_brace_nodes[i].position = _brace_rest_positions[i]
		return
	for i in range(_brace_nodes.size()):
		var jitter := Vector3(
			sin(_time * BRACE_SHAKE_FREQUENCY + i) * BRACE_SHAKE_AMOUNT,
			0.0,
			cos(_time * BRACE_SHAKE_FREQUENCY * 0.8 + i) * BRACE_SHAKE_AMOUNT
		) * decay
		_brace_nodes[i].position = _brace_rest_positions[i] + jitter


# ---------------------------------------------------------------------------
# Heavy Walker leg bob + body sway
# ---------------------------------------------------------------------------

func _update_walker(delta: float, is_moving: bool) -> void:
	if not is_moving:
		if _leg_left != null:
			_leg_left.position.y = _leg_rest_y_left
		if _leg_right != null:
			_leg_right.position.y = _leg_rest_y_right
		_visual_root.rotation.z = lerp(_visual_root.rotation.z, 0.0, clamp(4.0 * delta, 0.0, 1.0))
		return

	if _leg_left != null:
		_leg_left.position.y = _leg_rest_y_left + max(0.0, sin(_time * LEG_BOB_SPEED)) * LEG_BOB_AMOUNT
	if _leg_right != null:
		_leg_right.position.y = _leg_rest_y_right + max(0.0, sin(_time * LEG_BOB_SPEED + PI)) * LEG_BOB_AMOUNT
	_visual_root.rotation.z = sin(_time * BODY_SWAY_SPEED) * BODY_SWAY_AMOUNT


# ---------------------------------------------------------------------------
# Supply Truck repair dish + beam
# ---------------------------------------------------------------------------

## Rather than a continuously re-aimed persistent particle stream, this fires
## a short VFXManager.spawn_repair_beam() pulse toward whatever's being
## repaired every REPAIR_PULSE_INTERVAL seconds -- simpler to keep correct
## than a per-frame-mutated ParticleProcessMaterial, and reads as a
## "heartbeat" of repair energy rather than a laser.
func _update_supply_truck(delta: float, support_target: Node) -> void:
	var is_repairing: bool = support_target != null and is_instance_valid(support_target)

	if _repair_dish != null:
		var spin_speed: float = REPAIR_DISH_SPIN_SPEED if is_repairing else REPAIR_DISH_IDLE_SPIN_SPEED
		_repair_dish.rotate_y(spin_speed * delta)

	if not is_repairing:
		_repair_pulse_timer = 0.0
		return

	_repair_pulse_timer -= delta
	if _repair_pulse_timer > 0.0:
		return
	_repair_pulse_timer = REPAIR_PULSE_INTERVAL
	var origin: Vector3 = _repair_dish.global_position if _repair_dish != null else _visual_root.global_position
	VFXManager.spawn_repair_beam(origin, support_target.global_position)


# ---------------------------------------------------------------------------
# Capture Drone dish + beam
# ---------------------------------------------------------------------------

func _update_capture_drone(delta: float, is_capturing: bool) -> void:
	if _capture_dish != null:
		var spin_speed: float = CAPTURE_DISH_SPIN_SPEED if is_capturing else CAPTURE_DISH_IDLE_SPIN_SPEED
		_capture_dish.rotate_y(spin_speed * delta)
	if _capture_beam != null:
		_capture_beam.emitting = is_capturing


# ---------------------------------------------------------------------------
# Muzzle flash
# ---------------------------------------------------------------------------

## Direction is approximated as "fire origin minus hull center" -- close
## enough for a small flash's orientation without needing to extract the
## turret's exact aim basis. Position falls back to the unit's static Muzzle
## marker for types with no tracked barrel (see get_fire_origin()).
func _trigger_muzzle_flash() -> void:
	var fallback: Vector3 = _muzzle_marker.global_position if _muzzle_marker != null else _visual_root.global_position
	var position: Vector3 = get_fire_origin(fallback)
	VFXManager.spawn_muzzle_flash(position, position - _visual_root.global_position, _team, _muzzle_flash_size())


func _muzzle_flash_size() -> float:
	match _unit_type:
		Constants.UnitType.ARTILLERY, Constants.UnitType.HEAVY_WALKER:
			return MUZZLE_FLASH_SIZE_HEAVY
		Constants.UnitType.SCOUT_BUGGY, Constants.UnitType.ANTI_AIR:
			return MUZZLE_FLASH_SIZE_LIGHT
		_:
			return MUZZLE_FLASH_SIZE_NORMAL


# ---------------------------------------------------------------------------
# Damage flash
# ---------------------------------------------------------------------------

func _update_flash(delta: float) -> void:
	if _hull_material == null or _flash_remaining <= 0.0:
		return
	_flash_remaining -= delta
	_hull_material.albedo_color = Constants.DAMAGE_FLASH_COLOR if _flash_remaining > 0.0 else Constants.team_color(_team)


# ---------------------------------------------------------------------------
# Public event hooks (called from Unit.gd)
# ---------------------------------------------------------------------------

func on_fire() -> void:
	if not _turret_parts.is_empty():
		_trigger_recoil()
	if _unit_type == Constants.UnitType.MISSILE_CRAWLER:
		_trigger_missile_flash()
	elif _unit_type == Constants.UnitType.ARTILLERY:
		_trigger_brace_shake()
	_trigger_muzzle_flash()


func on_damaged() -> void:
	_flash_remaining = Constants.DAMAGE_FLASH_DURATION
	VFXManager.spawn_damage_sparks(_visual_root.global_position, _team)


## Returns the live world-space position projectiles should spawn from --
## the tip of whatever barrel/tube is currently tracking/just fired, or
## fallback (the unit's static Muzzle marker) for types with no tracked part.
func get_fire_origin(fallback: Vector3) -> Vector3:
	return _fire_origin_node.global_position if _fire_origin_node != null else fallback


## Small squash-bounce triggered by Unit.set_carried(false) when the
## commander drops this unit back onto the field.
func on_dropped() -> void:
	_drop_bounce_remaining = DROP_BOUNCE_DURATION


func on_death() -> void:
	if _is_dead:
		return
	_is_dead = true
	_wreck_remaining = WRECK_FADE_DURATION
	_death_sink_start_y = _visual_root.position.y
	# A random decaying spin sells the kill without any physics.
	_wreck_spin_rate = randf_range(-WRECK_SPIN_MAX_RATE, WRECK_SPIN_MAX_RATE)
	# Meshes are fixed once the unit is dead (nothing else adds/removes
	# children afterward), so collect the fade list once here instead of
	# re-walking the whole visual hierarchy every frame for the 5s fade.
	for node in _visual_root.find_children("*", "MeshInstance3D", true, false):
		_wreck_meshes.append(node as MeshInstance3D)
	VFXManager.spawn_explosion_small(_visual_root.global_position)
	_spawn_death_sparks()
	_spawn_death_smoke()


## Called every physics frame while the unit is destroyed, in place of the
## per-frame update() used while alive. Returns true once the wreck has
## fully faded, telling Unit.gd it's safe to queue_free().
func update_wreck(delta: float) -> bool:
	_wreck_remaining -= delta
	var progress: float = 1.0 - clamp(_wreck_remaining / WRECK_FADE_DURATION, 0.0, 1.0)
	_visual_root.position.y = _death_sink_start_y - DEATH_SINK_DISTANCE * min(1.0, progress * 3.0)
	_visual_root.rotation.y += _wreck_spin_rate * delta
	_wreck_spin_rate = move_toward(_wreck_spin_rate, 0.0, WRECK_SPIN_DECAY * delta)
	for mesh in _wreck_meshes:
		mesh.transparency = progress
	if progress > 0.4 and _smoke_particles != null and _smoke_particles.emitting:
		_smoke_particles.emitting = false
	return _wreck_remaining <= 0.0


func _spawn_death_sparks() -> void:
	var sparks := GPUParticles3D.new()
	sparks.one_shot = true
	sparks.emitting = false
	sparks.lifetime = 0.5
	sparks.local_coords = false
	sparks.amount = DEATH_SPARK_AMOUNT
	sparks.draw_pass_1 = _make_particle_quad(DEATH_SPARK_SIZE)
	sparks.process_material = _make_spark_material()
	_visual_root.add_child(sparks)
	sparks.global_position = _hull_mesh.global_position if _hull_mesh != null else _visual_root.global_position
	sparks.emitting = true


func _spawn_death_smoke() -> void:
	_smoke_particles = GPUParticles3D.new()
	_smoke_particles.lifetime = 1.2
	_smoke_particles.local_coords = false
	_smoke_particles.amount = DEATH_SMOKE_AMOUNT
	_smoke_particles.draw_pass_1 = _make_particle_quad(DEATH_SMOKE_SIZE)
	_smoke_particles.process_material = _make_smoke_material()
	_visual_root.add_child(_smoke_particles)
	_smoke_particles.global_position = _visual_root.global_position + Vector3(0.0, 0.5, 0.0)
	_smoke_particles.emitting = true


# ---------------------------------------------------------------------------
# Particle helpers (mirrors Commander.gd/Explosion.gd's proven patterns)
# ---------------------------------------------------------------------------

static func _make_particle_quad(size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	return mesh


static func _make_fade_gradient(color: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


static func _make_spark_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0.0, -4.0, 0.0)
	material.scale_min = 0.6
	material.scale_max = 1.3
	material.color_ramp = _make_fade_gradient(Color(1.0, 0.8, 0.4))
	return material


static func _make_smoke_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 25.0
	material.initial_velocity_min = 0.3
	material.initial_velocity_max = 0.8
	material.gravity = Vector3(0.0, 0.4, 0.0)
	material.scale_min = 0.8
	material.scale_max = 1.6
	material.color_ramp = _make_fade_gradient(MaterialLibrary.smoke_dark().albedo_color)
	return material


static func _make_capture_burst_material(color: Color) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 0.0, 1.0)
	material.spread = 180.0
	material.initial_velocity_min = 0.6
	material.initial_velocity_max = 1.1
	material.gravity = Vector3.ZERO
	material.scale_min = 0.4
	material.scale_max = 0.9
	material.color_ramp = _make_fade_gradient(color)
	return material
