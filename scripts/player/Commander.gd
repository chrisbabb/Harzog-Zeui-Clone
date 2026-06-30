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

# Fuel drain (per second)
const FUEL_DRAIN_AIR: float = 8.0
const FUEL_DRAIN_GROUND: float = 2.0

# Ammo cost/cooldown
const AMMO_FIRE_COST: float = 5.0
const FIRE_COOLDOWN: float = 0.35
const AIR_FIRE_SPREAD_DEGREES: float = 6.0

# AIR fires a faster, lighter, less accurate bolt that can hit anything;
# GROUND fires a slower, harder-hitting one that only hits ground targets,
# except an enemy commander caught hovering close by is fair game too.
const AIR_MODE_DAMAGE: float = 18.0
const GROUND_MODE_DAMAGE: float = 30.0
const AIR_MODE_PROJECTILE_SPEED: float = 45.0
const GROUND_MODE_PROJECTILE_SPEED: float = 30.0
const PROJECTILE_RANGE: float = 40.0
const GROUND_CLOSE_AIR_HIT_RANGE: float = 6.0

const MUZZLE_FLASH_DURATION: float = 0.08
const MUZZLE_FLASH_SIZE: float = 0.35
const MUZZLE_FLASH_COLOR: Color = Color(1.0, 0.9, 0.5)

const CONTRAIL_PARTICLE_AMOUNT: int = 24
const CONTRAIL_LIFETIME: float = 0.6
const CONTRAIL_PARTICLE_SIZE: float = 0.18
const CONTRAIL_COLOR: Color = Color(0.65, 0.85, 1.0, 0.55)

const DUST_PARTICLE_AMOUNT: int = 16
const DUST_LIFETIME: float = 0.5
const DUST_PARTICLE_SIZE: float = 0.22
const DUST_COLOR: Color = Color(0.55, 0.48, 0.35, 0.45)
const DUST_MOVE_SPEED_THRESHOLD: float = 1.0

const TEAM_STRIP_OUTER_RADIUS: float = 1.05
const TEAM_STRIP_INNER_RADIUS: float = 0.85
const TEAM_STRIP_HEIGHT: float = 0.1

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

var _is_dead: bool = false
var _transform_locked_remaining: float = 0.0
var _fire_cooldown_remaining: float = 0.0
var _body_material: StandardMaterial3D
var _flash_remaining: float = 0.0
var _muzzle_flash: MeshInstance3D
var _muzzle_flash_remaining: float = 0.0
var _contrail_particles: GPUParticles3D
var _dust_particles: GPUParticles3D

@onready var mesh_root: Node3D = $MeshRoot
@onready var ground_mesh: MeshInstance3D = $MeshRoot/GroundMesh
@onready var air_mesh: MeshInstance3D = $MeshRoot/AirMesh


func _ready() -> void:
	_apply_team_color()
	_create_muzzle_flash()
	_create_team_strip()
	_create_contrail_particles()
	_create_dust_particles()
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
	global_position = NavigationManager.clamp_to_battlefield(global_position)
	_update_height(delta)
	_update_particle_visuals()

	if carried_unit != null:
		carried_unit.global_position = global_position


func take_damage(amount: float, attacker: Node = null) -> void:
	hp = max(0.0, hp - amount)
	_flash_remaining = Constants.DAMAGE_FLASH_DURATION
	if hp <= 0.0:
		die()


func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	if team == Constants.Team.PLAYER:
		GameState.player_commander = null
	else:
		GameState.enemy_commander = null
	EventBus.commander_died.emit(self)
	queue_free()


func _update_timers(delta: float) -> void:
	if _transform_locked_remaining > 0.0:
		_transform_locked_remaining -= delta
	if _fire_cooldown_remaining > 0.0:
		_fire_cooldown_remaining -= delta
	_update_flash(delta)
	_update_muzzle_flash(delta)


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
	if is_moving:
		var drain_rate: float = FUEL_DRAIN_AIR if mode == Constants.CommanderMode.AIR else FUEL_DRAIN_GROUND
		fuel = max(0.0, fuel - drain_rate * delta)

	if fuel != previous_fuel:
		EventBus.commander_fuel_changed.emit(fuel)

	if fuel <= 0.0 and mode == Constants.CommanderMode.AIR:
		_begin_transform(Constants.CommanderMode.GROUND)


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
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Constants.team_color(team)
	ground_mesh.material_override = _body_material
	air_mesh.material_override = _body_material


func _update_flash(delta: float) -> void:
	if _flash_remaining <= 0.0:
		return
	_flash_remaining -= delta
	_body_material.albedo_color = Constants.DAMAGE_FLASH_COLOR if _flash_remaining > 0.0 else Constants.team_color(team)


## Built in code rather than the .tscn, like Unit.gd's order label/health
## bar, so Commander.tscn stays untouched. A small unshaded sphere a step
## ahead of the hull, only shown for an instant right after firing.
func _create_muzzle_flash() -> void:
	_muzzle_flash = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = MUZZLE_FLASH_SIZE
	mesh.height = MUZZLE_FLASH_SIZE * 2.0
	_muzzle_flash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.albedo_color = MUZZLE_FLASH_COLOR
	material.emission = MUZZLE_FLASH_COLOR
	_muzzle_flash.material_override = material
	_muzzle_flash.position = Vector3(0.0, 0.0, -PROJECTILE_FORWARD_OFFSET)
	_muzzle_flash.visible = false
	add_child(_muzzle_flash)


func _update_muzzle_flash(delta: float) -> void:
	if _muzzle_flash_remaining <= 0.0:
		return
	_muzzle_flash_remaining -= delta
	if _muzzle_flash_remaining <= 0.0:
		_muzzle_flash.visible = false


## A glowing team-colored ring at the commander's base, built in code like
## the muzzle flash above so Commander.tscn stays untouched.
func _create_team_strip() -> void:
	var strip := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = TEAM_STRIP_INNER_RADIUS
	mesh.outer_radius = TEAM_STRIP_OUTER_RADIUS
	strip.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.albedo_color = Constants.team_color(team)
	material.emission = Constants.team_color(team)
	strip.material_override = material
	strip.position = Vector3(0.0, TEAM_STRIP_HEIGHT, 0.0)
	add_child(strip)


## AIR mode trails a faint contrail behind the jet; GROUND mode kicks up dust
## while actually moving. Both are toggled per-frame in _update_particle_visuals
## and use local_coords = false so emitted particles stay put in world space
## instead of following the commander, producing a proper trailing look.
func _create_contrail_particles() -> void:
	_contrail_particles = GPUParticles3D.new()
	_contrail_particles.amount = CONTRAIL_PARTICLE_AMOUNT
	_contrail_particles.lifetime = CONTRAIL_LIFETIME
	_contrail_particles.local_coords = false
	_contrail_particles.emitting = false
	_contrail_particles.draw_pass_1 = _build_particle_quad_mesh(CONTRAIL_PARTICLE_SIZE)
	_contrail_particles.process_material = _build_trail_process_material(CONTRAIL_COLOR)
	_contrail_particles.position = Vector3(0.0, 0.0, PROJECTILE_FORWARD_OFFSET)
	add_child(_contrail_particles)


func _create_dust_particles() -> void:
	_dust_particles = GPUParticles3D.new()
	_dust_particles.amount = DUST_PARTICLE_AMOUNT
	_dust_particles.lifetime = DUST_LIFETIME
	_dust_particles.local_coords = false
	_dust_particles.emitting = false
	_dust_particles.draw_pass_1 = _build_particle_quad_mesh(DUST_PARTICLE_SIZE)
	_dust_particles.process_material = _build_dust_process_material(DUST_COLOR)
	_dust_particles.position = Vector3(0.0, -GROUND_HEIGHT, 0.0)
	add_child(_dust_particles)


func _update_particle_visuals() -> void:
	_contrail_particles.emitting = mode == Constants.CommanderMode.AIR
	var ground_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
	_dust_particles.emitting = mode == Constants.CommanderMode.GROUND and ground_speed > DUST_MOVE_SPEED_THRESHOLD


func _build_particle_quad_mesh(size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	return mesh


func _build_trail_process_material(color: Color) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 0.0, 1.0)
	material.spread = 10.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.5
	material.gravity = Vector3.ZERO
	material.scale_min = 0.6
	material.scale_max = 1.2
	material.color_ramp = _build_fade_gradient(color)
	return material


func _build_dust_process_material(color: Color) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 50.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.5
	material.gravity = Vector3(0.0, -1.0, 0.0)
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.color_ramp = _build_fade_gradient(color)
	return material


func _build_fade_gradient(color: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _toggle_pickup_drop() -> void:
	if carried_unit != null:
		_drop_unit()
	elif mode == Constants.CommanderMode.AIR:
		_pickup_nearest_unit()


func _pickup_nearest_unit() -> void:
	var nearest: Node = null
	var nearest_distance: float = Constants.PICKUP_RANGE

	for unit in get_tree().get_nodes_in_group("units"):
		if unit.get("team") != team or unit.get("is_destroyed"):
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


## Units whose order the command menu is currently allowed to change: the
## carried unit if any, otherwise friendly units within ORDER_RANGE while
## grounded. This is the Herzog-like constraint that forces the player to be
## near a unit (or holding it) to redirect it.
func get_reorderable_units() -> Array[Node]:
	if carried_unit != null and is_instance_valid(carried_unit):
		var carried: Array[Node] = [carried_unit]
		return carried

	var nearby: Array[Node] = []
	if mode != Constants.CommanderMode.GROUND:
		return nearby

	for unit in get_tree().get_nodes_in_group("units"):
		if unit.get("team") == team and not unit.get("is_destroyed") and global_position.distance_to(unit.global_position) <= Constants.ORDER_RANGE:
			nearby.append(unit)
	return nearby


func _try_fire() -> void:
	if _fire_cooldown_remaining > 0.0 or ammo < AMMO_FIRE_COST:
		return

	ammo -= AMMO_FIRE_COST
	EventBus.commander_ammo_changed.emit(ammo)
	_fire_cooldown_remaining = FIRE_COOLDOWN
	_spawn_projectile()
	_trigger_muzzle_flash()


func _spawn_projectile() -> void:
	var is_air_mode: bool = mode == Constants.CommanderMode.AIR
	var fire_direction: Vector3 = -global_transform.basis.z
	if is_air_mode:
		var spread: float = deg_to_rad(randf_range(-AIR_FIRE_SPREAD_DEGREES, AIR_FIRE_SPREAD_DEGREES))
		fire_direction = fire_direction.rotated(Vector3.UP, spread)

	var projectile: Node3D = PROJECTILE_SCENE.instantiate() as Node3D
	_get_effects_root().add_child(projectile)
	projectile.global_position = global_position + (fire_direction * PROJECTILE_FORWARD_OFFSET)
	projectile.set("team", team)
	projectile.set("damage", AIR_MODE_DAMAGE if is_air_mode else GROUND_MODE_DAMAGE)
	projectile.set("speed", AIR_MODE_PROJECTILE_SPEED if is_air_mode else GROUND_MODE_PROJECTILE_SPEED)
	projectile.set("target_position", global_position + (fire_direction * PROJECTILE_RANGE))
	projectile.set("can_hit_air", is_air_mode or _enemy_commander_is_close())
	projectile.set("can_hit_ground", true)
	projectile.set("source", self)


func _trigger_muzzle_flash() -> void:
	_muzzle_flash.visible = true
	_muzzle_flash_remaining = MUZZLE_FLASH_DURATION


## GROUND mode normally can't hit air targets, but an enemy commander
## hovering this close overhead is still fair game.
func _enemy_commander_is_close() -> bool:
	var hostile: Node = _enemy_commander()
	return hostile != null and is_instance_valid(hostile) \
		and global_position.distance_to(hostile.global_position) <= GROUND_CLOSE_AIR_HIT_RANGE


func _enemy_commander() -> Node:
	return GameState.enemy_commander if team == Constants.Team.PLAYER else GameState.player_commander


func _get_effects_root() -> Node:
	var effects_root: Node = get_parent().get_node_or_null("EffectsRoot")
	return effects_root if effects_root != null else get_parent()
