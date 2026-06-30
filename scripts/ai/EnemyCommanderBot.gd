extends CharacterBody3D
## AI-controlled enemy commander. Mirrors the player Commander's stats and
## capabilities but driven by a state-machine instead of player input.
## Intentionally avoids emitting player-HUD signals (commander_fuel/ammo/mode_changed).

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/effects/Projectile.tscn")

const MAX_HP: float = 500.0
const GROUND_HEIGHT: float = 1.5
const AIR_HEIGHT: float = 4.0
const HEIGHT_LERP_SPEED: float = 4.0

const MOVE_SPEED: float = 16.0
const ACCELERATION: float = 40.0
const DECELERATION: float = 30.0
const ROTATION_SPEED: float = 6.0

const FUEL_DRAIN_AIR: float = 8.0
const FUEL_DRAIN_GROUND: float = 2.0
const AMMO_FIRE_COST: float = 5.0
const FIRE_COOLDOWN: float = 0.5
const AIR_MODE_DAMAGE: float = 18.0
const GROUND_MODE_DAMAGE: float = 30.0
const AIR_MODE_PROJECTILE_SPEED: float = 45.0
const GROUND_MODE_PROJECTILE_SPEED: float = 30.0
const PROJECTILE_RANGE: float = 40.0
const PROJECTILE_FORWARD_OFFSET: float = 1.2
const MUZZLE_FLASH_DURATION: float = 0.08
const MUZZLE_FLASH_SIZE: float = 0.35
const MUZZLE_FLASH_COLOR: Color = Color(1.0, 0.9, 0.5)

const TEAM_STRIP_OUTER_RADIUS: float = 1.05
const TEAM_STRIP_INNER_RADIUS: float = 0.85
const TEAM_STRIP_HEIGHT: float = 0.1

const CONTRAIL_PARTICLE_AMOUNT: int = 24
const CONTRAIL_LIFETIME: float = 0.6
const CONTRAIL_PARTICLE_SIZE: float = 0.18
const CONTRAIL_COLOR: Color = Color(0.65, 0.85, 1.0, 0.55)

const DUST_PARTICLE_AMOUNT: int = 16
const DUST_LIFETIME: float = 0.5
const DUST_PARTICLE_SIZE: float = 0.22
const DUST_COLOR: Color = Color(0.55, 0.48, 0.35, 0.45)
const DUST_MOVE_SPEED_THRESHOLD: float = 1.0

const DETECTION_RADIUS: float = 35.0
const ATTACK_RANGE: float = 28.0
const OUTPOST_APPROACH_RANGE: float = 10.0
const ARRIVAL_THRESHOLD: float = 5.0
const LOGISTICS_RADIUS: float = 35.0
const LOGISTICS_INTERVAL: float = 18.0
const LOGISTICS_HOVER_TIME: float = 2.5
const RETREAT_HP_RATIO: float = 0.35
const RETREAT_FUEL_RATIO: float = 0.20
const RETREAT_AMMO_RATIO: float = 0.15
const RESUPPLY_HP_RATIO: float = 0.80
const RESUPPLY_FUEL_RATIO: float = 0.60
const RESUPPLY_AMMO_RATIO: float = 0.60

@export var team: int = Constants.Team.ENEMY

var mode: int = Constants.CommanderMode.AIR
var hp: float = MAX_HP
var max_hp: float = MAX_HP
var fuel: float = Constants.MAX_PLAYER_FUEL
var ammo: float = Constants.MAX_PLAYER_AMMO
var is_destroyed: bool = false

enum AIState { PATROL, ATTACK, HARASS, RETREAT, LOGISTICS }
var _state: AIState = AIState.PATROL
var _patrol_target: Node = null
var _patrol_toward_frontline: bool = true
var _harass_target: Node = null
var _retreat_target: Node = null
var _logistics_target: Node = null
var _logistics_hover_timer: float = 0.0
var _logistics_timer: float = 0.0

var _fire_cooldown: float = 0.0
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
	collision_mask = 0
	_logistics_timer = LOGISTICS_INTERVAL


func _physics_process(delta: float) -> void:
	if not GameState.match_active:
		return
	_update_timers(delta)
	_drain_fuel(delta)
	_tick_ai(delta)
	global_position = NavigationManager.clamp_to_battlefield(global_position)
	_update_height(delta)
	_update_flash(delta)
	_update_muzzle_flash(delta)
	_update_particle_visuals()


func take_damage(amount: float, _attacker: Node = null) -> void:
	hp = max(0.0, hp - amount)
	_flash_remaining = Constants.DAMAGE_FLASH_DURATION
	if hp <= 0.0:
		die()


func die() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	GameState.enemy_commander = null
	EventBus.commander_died.emit(self)
	queue_free()


func _update_timers(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _logistics_timer > 0.0:
		_logistics_timer -= delta


func _drain_fuel(delta: float) -> void:
	if velocity.length() > 0.5:
		var rate: float = FUEL_DRAIN_AIR if mode == Constants.CommanderMode.AIR else FUEL_DRAIN_GROUND
		fuel = max(0.0, fuel - rate * delta)
	if fuel <= 0.0 and mode == Constants.CommanderMode.AIR:
		_set_mode(Constants.CommanderMode.GROUND)


# ---------------------------------------------------------------------------
# AI state machine
# ---------------------------------------------------------------------------

func _tick_ai(delta: float) -> void:
	if _should_retreat():
		if _state != AIState.RETREAT:
			_enter_retreat()
	elif _state == AIState.RETREAT and _is_resupplied():
		_enter_patrol()

	match _state:
		AIState.PATROL:   _tick_patrol(delta)
		AIState.ATTACK:   _tick_attack(delta)
		AIState.HARASS:   _tick_harass(delta)
		AIState.RETREAT:  _tick_retreat(delta)
		AIState.LOGISTICS: _tick_logistics(delta)


func _should_retreat() -> bool:
	return hp / max_hp < RETREAT_HP_RATIO \
		or fuel / Constants.MAX_PLAYER_FUEL < RETREAT_FUEL_RATIO \
		or ammo / Constants.MAX_PLAYER_AMMO < RETREAT_AMMO_RATIO


func _is_resupplied() -> bool:
	return hp / max_hp >= RESUPPLY_HP_RATIO \
		and fuel / Constants.MAX_PLAYER_FUEL >= RESUPPLY_FUEL_RATIO \
		and ammo / Constants.MAX_PLAYER_AMMO >= RESUPPLY_AMMO_RATIO


# ---------------------------------------------------------------------------
# PATROL: alternate between enemy HQ and frontline outpost
# ---------------------------------------------------------------------------

func _enter_patrol() -> void:
	_state = AIState.PATROL
	_set_mode(Constants.CommanderMode.AIR)
	_patrol_toward_frontline = true
	_pick_patrol_target()


func _pick_patrol_target() -> void:
	if _patrol_toward_frontline:
		var frontline: Node = TacticalDirector.get_frontline_outpost(Constants.Team.ENEMY)
		_patrol_target = frontline if frontline != null else GameState.enemy_hq
	else:
		_patrol_target = GameState.enemy_hq


func _tick_patrol(delta: float) -> void:
	var player_cmd: Node = GameState.player_commander
	if player_cmd != null and is_instance_valid(player_cmd):
		if global_position.distance_to(player_cmd.global_position) <= DETECTION_RADIUS:
			_state = AIState.ATTACK
			return

	if _logistics_timer <= 0.0:
		var logi_target: Node = _find_logistics_target()
		if logi_target != null:
			_enter_logistics(logi_target)
			return

	if _patrol_target == null or not is_instance_valid(_patrol_target):
		_pick_patrol_target()

	if _patrol_target != null and is_instance_valid(_patrol_target):
		var dist: float = global_position.distance_to(_patrol_target.global_position)
		if dist <= ARRIVAL_THRESHOLD:
			_patrol_toward_frontline = not _patrol_toward_frontline
			_pick_patrol_target()
			if randf() < 0.30:
				_try_enter_harass()
		else:
			_move_toward(_patrol_target.global_position, delta)
	else:
		_stop_moving(delta)


# ---------------------------------------------------------------------------
# ATTACK: pursue and fire at player commander
# ---------------------------------------------------------------------------

func _tick_attack(delta: float) -> void:
	var player_cmd: Node = GameState.player_commander
	if player_cmd == null or not is_instance_valid(player_cmd):
		_enter_patrol()
		return

	var dist: float = global_position.distance_to(player_cmd.global_position)
	if dist > DETECTION_RADIUS * 1.5:
		_enter_patrol()
		return

	_face_target(player_cmd.global_position, delta)
	if dist <= ATTACK_RANGE:
		_stop_moving(delta)
		_try_fire(player_cmd.global_position)
	else:
		_move_toward(player_cmd.global_position, delta)


# ---------------------------------------------------------------------------
# HARASS: approach a player outpost and fire at it from close range
# ---------------------------------------------------------------------------

func _try_enter_harass() -> void:
	var nearest: Node = null
	var nearest_dist: float = INF
	for outpost in GameState.outposts:
		if not is_instance_valid(outpost):
			continue
		if outpost.get("team") != Constants.Team.PLAYER:
			continue
		var d: float = global_position.distance_to(outpost.global_position)
		if d < nearest_dist:
			nearest = outpost
			nearest_dist = d
	if nearest != null:
		_harass_target = nearest
		_state = AIState.HARASS
		_set_mode(Constants.CommanderMode.AIR)


func _tick_harass(delta: float) -> void:
	if _harass_target == null or not is_instance_valid(_harass_target) \
			or _harass_target.get("team") != Constants.Team.PLAYER:
		_enter_patrol()
		return

	var player_cmd: Node = GameState.player_commander
	if player_cmd != null and is_instance_valid(player_cmd):
		if global_position.distance_to(player_cmd.global_position) <= DETECTION_RADIUS:
			_state = AIState.ATTACK
			return

	var dist: float = global_position.distance_to(_harass_target.global_position)
	if dist <= OUTPOST_APPROACH_RANGE:
		_set_mode(Constants.CommanderMode.GROUND)
		_face_target(_harass_target.global_position, delta)
		_stop_moving(delta)
		_try_fire(_harass_target.global_position)
	else:
		_move_toward(_harass_target.global_position, delta)


# ---------------------------------------------------------------------------
# RETREAT: fly to nearest friendly building and wait for resupply
# ---------------------------------------------------------------------------

func _enter_retreat() -> void:
	_state = AIState.RETREAT
	_set_mode(Constants.CommanderMode.AIR)
	_retreat_target = GameState.get_nearest_friendly_production_building(
		Constants.Team.ENEMY, global_position
	)


func _tick_retreat(delta: float) -> void:
	if _retreat_target == null or not is_instance_valid(_retreat_target):
		_retreat_target = GameState.get_nearest_friendly_production_building(
			Constants.Team.ENEMY, global_position
		)
		if _retreat_target == null:
			_stop_moving(delta)
			return

	var dist: float = global_position.distance_to(_retreat_target.global_position)
	if dist > ARRIVAL_THRESHOLD:
		_move_toward(_retreat_target.global_position, delta)
	else:
		_stop_moving(delta)


# ---------------------------------------------------------------------------
# LOGISTICS: fly to a nearby enemy unit and improve its order
# ---------------------------------------------------------------------------

func _enter_logistics(target: Node) -> void:
	_logistics_target = target
	_state = AIState.LOGISTICS
	_set_mode(Constants.CommanderMode.AIR)
	_logistics_hover_timer = 0.0
	_logistics_timer = LOGISTICS_INTERVAL


func _find_logistics_target() -> Node:
	var nearest: Node = null
	var nearest_dist: float = LOGISTICS_RADIUS
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("is_destroyed"):
			continue
		if unit.get("team") != Constants.Team.ENEMY:
			continue
		var d: float = global_position.distance_to(unit.global_position)
		if d < nearest_dist:
			nearest = unit
			nearest_dist = d
	return nearest


func _tick_logistics(delta: float) -> void:
	if _logistics_target == null or not is_instance_valid(_logistics_target) \
			or _logistics_target.get("is_destroyed"):
		_enter_patrol()
		return

	if _logistics_hover_timer > 0.0:
		_logistics_hover_timer -= delta
		_stop_moving(delta)
		if _logistics_hover_timer <= 0.0:
			var unit_type: int = _logistics_target.get("unit_type") if \
				_logistics_target.get("unit_type") != null else -1
			_logistics_target.call("give_order", _pick_order_for_unit(unit_type))
			_enter_patrol()
	else:
		var dist: float = global_position.distance_to(_logistics_target.global_position)
		if dist <= ARRIVAL_THRESHOLD:
			_logistics_hover_timer = LOGISTICS_HOVER_TIME
		else:
			_move_toward(_logistics_target.global_position, delta)


func _pick_order_for_unit(unit_type: int) -> int:
	var owned: int = 0
	for outpost in GameState.outposts:
		if is_instance_valid(outpost) and outpost.get("team") == Constants.Team.ENEMY:
			owned += 1
	match unit_type:
		Constants.UnitType.CAPTURE_DRONE:
			return Constants.UnitOrder.CAPTURE_OUTPOST
		Constants.UnitType.SUPPLY_TRUCK:
			return Constants.UnitOrder.SUPPORT_ALLIES
		Constants.UnitType.MISSILE_CRAWLER, Constants.UnitType.ANTI_AIR:
			return Constants.UnitOrder.DEFEND_OUTPOST
		Constants.UnitType.ARTILLERY:
			return Constants.UnitOrder.ATTACK_BASE if owned >= 3 else Constants.UnitOrder.DEFEND_OUTPOST
		_:
			return Constants.UnitOrder.ATTACK_BASE if owned >= 2 else Constants.UnitOrder.CAPTURE_OUTPOST


# ---------------------------------------------------------------------------
# Movement helpers
# ---------------------------------------------------------------------------

func _move_toward(target_pos: Vector3, delta: float) -> void:
	var flat_dir: Vector3 = Vector3(target_pos.x - global_position.x, 0.0,
		target_pos.z - global_position.z)
	if flat_dir.length() < 0.1:
		_stop_moving(delta)
		return
	flat_dir = flat_dir.normalized()
	_face_target(target_pos, delta)
	velocity.x = move_toward(velocity.x, flat_dir.x * MOVE_SPEED, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, flat_dir.z * MOVE_SPEED, ACCELERATION * delta)
	velocity.y = 0.0
	move_and_slide()


func _stop_moving(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
	velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)
	velocity.y = 0.0
	move_and_slide()


func _face_target(target_pos: Vector3, delta: float) -> void:
	var flat_dir: Vector3 = Vector3(target_pos.x - global_position.x, 0.0,
		target_pos.z - global_position.z)
	if flat_dir.length() < 0.01:
		return
	flat_dir = flat_dir.normalized()
	var target_angle: float = atan2(-flat_dir.x, -flat_dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, clamp(ROTATION_SPEED * delta, 0.0, 1.0))


func _update_height(delta: float) -> void:
	var target_h: float = AIR_HEIGHT if mode == Constants.CommanderMode.AIR else GROUND_HEIGHT
	position.y = lerp(position.y, target_h, clamp(HEIGHT_LERP_SPEED * delta, 0.0, 1.0))


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

func _try_fire(target_pos: Vector3) -> void:
	if _fire_cooldown > 0.0 or ammo < AMMO_FIRE_COST:
		return
	ammo -= AMMO_FIRE_COST
	_fire_cooldown = FIRE_COOLDOWN
	_spawn_projectile(target_pos)
	_trigger_muzzle_flash()


func _spawn_projectile(target_pos: Vector3) -> void:
	var is_air: bool = mode == Constants.CommanderMode.AIR
	var fire_dir: Vector3 = Vector3(target_pos.x - global_position.x, 0.0,
		target_pos.z - global_position.z).normalized()

	var projectile: Node3D = PROJECTILE_SCENE.instantiate() as Node3D
	_get_effects_root().add_child(projectile)
	projectile.global_position = global_position + fire_dir * PROJECTILE_FORWARD_OFFSET
	projectile.set("team", team)
	projectile.set("damage", AIR_MODE_DAMAGE if is_air else GROUND_MODE_DAMAGE)
	projectile.set("speed", AIR_MODE_PROJECTILE_SPEED if is_air else GROUND_MODE_PROJECTILE_SPEED)
	projectile.set("target_position", global_position + fire_dir * PROJECTILE_RANGE)
	projectile.set("can_hit_air", is_air)
	projectile.set("can_hit_ground", true)
	projectile.set("source", self)


func _trigger_muzzle_flash() -> void:
	_muzzle_flash.visible = true
	_muzzle_flash_remaining = MUZZLE_FLASH_DURATION


# ---------------------------------------------------------------------------
# Mode
# ---------------------------------------------------------------------------

func _set_mode(new_mode: int) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	collision_mask = 0 if mode == Constants.CommanderMode.AIR else 1
	_update_mode_visuals()


func _update_mode_visuals() -> void:
	ground_mesh.visible = mode == Constants.CommanderMode.GROUND
	air_mesh.visible = mode == Constants.CommanderMode.AIR


# ---------------------------------------------------------------------------
# Visuals
# ---------------------------------------------------------------------------

func _apply_team_color() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Constants.team_color(team)
	ground_mesh.material_override = _body_material
	air_mesh.material_override = _body_material


func _create_muzzle_flash() -> void:
	_muzzle_flash = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = MUZZLE_FLASH_SIZE
	mesh.height = MUZZLE_FLASH_SIZE * 2.0
	_muzzle_flash.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.albedo_color = MUZZLE_FLASH_COLOR
	mat.emission = MUZZLE_FLASH_COLOR
	_muzzle_flash.material_override = mat
	_muzzle_flash.position = Vector3(0.0, 0.0, -PROJECTILE_FORWARD_OFFSET)
	_muzzle_flash.visible = false
	add_child(_muzzle_flash)


func _update_flash(delta: float) -> void:
	if _flash_remaining <= 0.0:
		return
	_flash_remaining -= delta
	_body_material.albedo_color = Constants.DAMAGE_FLASH_COLOR \
		if _flash_remaining > 0.0 else Constants.team_color(team)


func _update_muzzle_flash(delta: float) -> void:
	if _muzzle_flash_remaining <= 0.0:
		return
	_muzzle_flash_remaining -= delta
	if _muzzle_flash_remaining <= 0.0:
		_muzzle_flash.visible = false


## A glowing team-colored ring at the commander's base, built in code like
## the muzzle flash above so EnemyCommander.tscn stays untouched.
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


func _get_effects_root() -> Node:
	var root: Node = get_parent().get_node_or_null("EffectsRoot")
	return root if root != null else get_parent()
