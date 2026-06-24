extends CharacterBody3D
## Player-controlled commander: a transformable vehicle that switches
## between a fast, evasive AIR mode and a sturdier, more accurate GROUND mode.
## Movement is camera-relative; mode, fuel and ammo drive what the commander
## is currently allowed to do.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/effects/Projectile.tscn")

# Health
const MAX_HP: float = 500.0

# Hover heights per mode and how fast the commander eases between them
const GROUND_HEIGHT: float = 1.5
const AIR_HEIGHT: float = 4.0
const HEIGHT_LERP_SPEED: float = 4.0

# Movement feel
const ACCELERATION: float = 40.0
const DECELERATION: float = 25.0
const ROTATION_SPEED: float = 10.0

# Fuel drain/refuel (per second)
const FUEL_DRAIN_AIR: float = 8.0
const FUEL_DRAIN_GROUND: float = 2.0
const REFUEL_RATE: float = 25.0

# Ammo cost/reload
const AMMO_FIRE_COST: float = 5.0
const RELOAD_RATE: float = 8.0
const FIRE_COOLDOWN: float = 0.35
const AIR_FIRE_SPREAD_DEGREES: float = 6.0

# Supply range shared by refuel/reload checks against friendly HQ/outposts
const SUPPLY_RANGE: float = 8.0

# The commander captures outposts slower than a dedicated capture unit would
const CAPTURE_SLOWDOWN: float = 1.5

# Transform animation
const SQUASH_SCALE: Vector3 = Vector3(1.3, 0.7, 1.3)

const PROJECTILE_FORWARD_OFFSET: float = 1.2

@export var team: int = Constants.Team.PLAYER

var mode: int = Constants.CommanderMode.GROUND
var hp: float = MAX_HP
var max_hp: float = MAX_HP
var fuel: float = Constants.MAX_PLAYER_FUEL
var ammo: float = Constants.MAX_PLAYER_AMMO
var carried_unit: Node = null

var _transform_locked_remaining: float = 0.0
var _fire_cooldown_remaining: float = 0.0
var _capturing_outpost: Node = null
var _capture_progress: float = 0.0

@onready var mesh_root: Node3D = $MeshRoot
@onready var ground_mesh: MeshInstance3D = $MeshRoot/GroundMesh
@onready var air_mesh: MeshInstance3D = $MeshRoot/AirMesh


func _ready() -> void:
	_apply_team_color()
	_update_mode_visuals()
	EventBus.commander_mode_changed.emit(mode)
	EventBus.commander_fuel_changed.emit(fuel)
	EventBus.commander_ammo_changed.emit(ammo)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_transform_animation()

	if Input.is_action_just_pressed(Constants.ACTION_TRANSFORM_MODE):
		_toggle_transform()

	if Input.is_action_just_pressed(Constants.ACTION_PICKUP_DROP):
		_toggle_pickup_drop()

	if Input.is_action_pressed(Constants.ACTION_FIRE_PRIMARY):
		_try_fire()

	var input_direction: Vector3 = _get_camera_relative_input()
	_update_fuel(delta, input_direction != Vector3.ZERO)
	_handle_movement(delta, input_direction)
	_update_height(delta)
	_update_ammo(delta)
	_update_capture(delta)

	if carried_unit != null:
		carried_unit.global_position = global_position


func take_damage(amount: float) -> void:
	hp = max(0.0, hp - amount)
	if hp <= 0.0:
		die()


func die() -> void:
	queue_free()


func _update_timers(delta: float) -> void:
	if _transform_locked_remaining > 0.0:
		_transform_locked_remaining -= delta
	if _fire_cooldown_remaining > 0.0:
		_fire_cooldown_remaining -= delta


func _get_camera_relative_input() -> Vector3:
	var raw_input := Vector2.ZERO
	raw_input.x = Input.get_action_strength(Constants.ACTION_MOVE_RIGHT) - Input.get_action_strength(Constants.ACTION_MOVE_LEFT)
	raw_input.y = Input.get_action_strength(Constants.ACTION_MOVE_BACK) - Input.get_action_strength(Constants.ACTION_MOVE_FORWARD)
	if raw_input == Vector2.ZERO:
		return Vector3.ZERO

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(raw_input.x, 0.0, raw_input.y).normalized()

	var camera_basis: Basis = camera.global_transform.basis
	var forward: Vector3 = -camera_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = camera_basis.x
	right.y = 0.0
	right = right.normalized()

	return ((right * raw_input.x) + (forward * -raw_input.y)).normalized()


func _handle_movement(delta: float, input_direction: Vector3) -> void:
	var speed: float = Constants.PLAYER_AIR_SPEED if mode == Constants.CommanderMode.AIR else Constants.PLAYER_GROUND_SPEED
	var target_velocity: Vector3 = input_direction * speed
	var acceleration: float = ACCELERATION if input_direction != Vector3.ZERO else DECELERATION

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	velocity.y = 0.0
	move_and_slide()

	if input_direction != Vector3.ZERO:
		var target_angle: float = atan2(-input_direction.x, -input_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, clamp(ROTATION_SPEED * delta, 0.0, 1.0))


func _update_height(delta: float) -> void:
	var target_height: float = AIR_HEIGHT if mode == Constants.CommanderMode.AIR else GROUND_HEIGHT
	position.y = lerp(position.y, target_height, clamp(HEIGHT_LERP_SPEED * delta, 0.0, 1.0))


func _update_fuel(delta: float, is_moving: bool) -> void:
	var previous_fuel: float = fuel
	if _is_near_friendly_supply():
		fuel = min(Constants.MAX_PLAYER_FUEL, fuel + REFUEL_RATE * delta)
	elif is_moving:
		var drain_rate: float = FUEL_DRAIN_AIR if mode == Constants.CommanderMode.AIR else FUEL_DRAIN_GROUND
		fuel = max(0.0, fuel - drain_rate * delta)

	if fuel != previous_fuel:
		EventBus.commander_fuel_changed.emit(fuel)

	if fuel <= 0.0 and mode == Constants.CommanderMode.AIR:
		_begin_transform(Constants.CommanderMode.GROUND)


func _update_ammo(delta: float) -> void:
	if ammo >= Constants.MAX_PLAYER_AMMO or not _is_near_friendly_supply():
		return
	ammo = min(Constants.MAX_PLAYER_AMMO, ammo + RELOAD_RATE * delta)
	EventBus.commander_ammo_changed.emit(ammo)


func _is_near_friendly_supply() -> bool:
	for building in GameState.get_team_buildings(team):
		if global_position.distance_to(building.global_position) <= SUPPLY_RANGE:
			return true
	return false


func _toggle_transform() -> void:
	if _transform_locked_remaining > 0.0:
		return
	var new_mode: int = Constants.CommanderMode.AIR if mode == Constants.CommanderMode.GROUND else Constants.CommanderMode.GROUND
	_begin_transform(new_mode)


func _begin_transform(new_mode: int) -> void:
	mode = new_mode
	_transform_locked_remaining = Constants.PLAYER_TRANSFORM_TIME
	# AIR mode flies over units/buildings/terrain instead of clearing their height.
	collision_mask = 0 if mode == Constants.CommanderMode.AIR else 1
	EventBus.commander_mode_changed.emit(mode)


func _update_transform_animation() -> void:
	if _transform_locked_remaining <= 0.0:
		mesh_root.scale = Vector3.ONE
		_update_mode_visuals()
		return

	# Squash peaks at the midpoint of the transform, where the mesh swap also
	# happens, then eases back out as the new form settles in.
	var progress: float = 1.0 - (_transform_locked_remaining / Constants.PLAYER_TRANSFORM_TIME)
	mesh_root.scale = Vector3.ONE.lerp(SQUASH_SCALE, sin(progress * PI))
	if progress >= 0.5:
		_update_mode_visuals()


func _update_mode_visuals() -> void:
	ground_mesh.visible = mode == Constants.CommanderMode.GROUND
	air_mesh.visible = mode == Constants.CommanderMode.AIR


func _apply_team_color() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Constants.team_color(team)
	ground_mesh.material_override = material
	air_mesh.material_override = material


func _update_capture(delta: float) -> void:
	if mode != Constants.CommanderMode.GROUND:
		_capturing_outpost = null
		_capture_progress = 0.0
		return

	var target: Node = _find_capturable_outpost()
	if target != _capturing_outpost:
		_capturing_outpost = target
		_capture_progress = 0.0

	if _capturing_outpost == null:
		return

	_capture_progress += delta
	if _capture_progress >= Constants.OUTPOST_CAPTURE_TIME * CAPTURE_SLOWDOWN:
		_capturing_outpost.capture(team)
		_capturing_outpost = null
		_capture_progress = 0.0


func _find_capturable_outpost() -> Node:
	for outpost in GameState.outposts:
		if not is_instance_valid(outpost) or outpost.get("team") == team:
			continue
		if global_position.distance_to(outpost.global_position) <= Constants.CAPTURE_RADIUS:
			return outpost
	return null


func _toggle_pickup_drop() -> void:
	if carried_unit != null:
		_drop_unit()
	elif mode == Constants.CommanderMode.AIR:
		_pickup_nearest_unit()


func _pickup_nearest_unit() -> void:
	var nearest: Node = null
	var nearest_distance: float = Constants.PICKUP_RANGE

	for unit in get_tree().get_nodes_in_group("units"):
		if unit.get("team") != team:
			continue
		var distance: float = global_position.distance_to(unit.global_position)
		if distance <= nearest_distance:
			nearest = unit
			nearest_distance = distance

	if nearest == null:
		return

	carried_unit = nearest
	nearest.set_carried(true)
	EventBus.unit_picked_up.emit(nearest)


func _drop_unit() -> void:
	var unit: Node = carried_unit
	carried_unit = null
	unit.global_position = global_position + (-global_transform.basis.z * Constants.DROP_RANGE)
	unit.set_carried(false)
	EventBus.unit_dropped.emit(unit)


func _try_fire() -> void:
	if _fire_cooldown_remaining > 0.0 or ammo < AMMO_FIRE_COST:
		return

	ammo -= AMMO_FIRE_COST
	EventBus.commander_ammo_changed.emit(ammo)
	_fire_cooldown_remaining = FIRE_COOLDOWN
	_spawn_projectile()


func _spawn_projectile() -> void:
	var fire_direction: Vector3 = -global_transform.basis.z
	if mode == Constants.CommanderMode.AIR:
		var spread: float = deg_to_rad(randf_range(-AIR_FIRE_SPREAD_DEGREES, AIR_FIRE_SPREAD_DEGREES))
		fire_direction = fire_direction.rotated(Vector3.UP, spread)

	var spawn_parent: Node = get_parent().get_node_or_null("EffectsRoot")
	if spawn_parent == null:
		spawn_parent = get_parent()

	var projectile: Node3D = PROJECTILE_SCENE.instantiate() as Node3D
	spawn_parent.add_child(projectile)
	projectile.global_position = global_position + (fire_direction * PROJECTILE_FORWARD_OFFSET)
	projectile.set("team", team)
	projectile.set("direction", fire_direction)
