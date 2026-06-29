extends CharacterBody3D
## Generic ground unit driven by stats loaded from data/units.json.
## Moves via NavigationAgent3D toward whatever target current_order
## resolves to (see UnitOrder.gd), opportunistically attacks the nearest
## valid enemy that wanders into its detection radius regardless of order,
## and can be picked up/dropped by its own team's commander.

const SLOW_SPEED_MULTIPLIER: float = 0.35
const FUEL_DRAIN_RATE: float = 3.0
const AMMO_PER_SHOT: float = 1.0
const DIRECT_STEER_EPSILON: float = 0.05
const SUPPLY_REPAIR_RATE: float = 10.0
const SUPPLY_REFUEL_RATE: float = 8.0
const SUPPLY_RELOAD_RATE: float = 3.0
const ORDER_LABEL_HEIGHT: float = 2.2
const PROJECTILE_SPEED: float = 28.0
const ARTILLERY_PROJECTILE_SPEED: float = 16.0
const ARTILLERY_PROJECTILE_SCALE: float = 1.8
const HEALTH_BAR_HEIGHT: float = 2.6
const HEALTH_BAR_SIZE: Vector3 = Vector3(1.2, 0.15, 0.05)
const WRECK_FADE_DURATION: float = 5.0
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/effects/Projectile.tscn")

@export var team: int = Constants.Team.PLAYER
@export var unit_type: int = Constants.UnitType.TANK

var hp: float
var max_hp: float
var fuel: float
var max_fuel: float
var ammo: float
var max_ammo: float
var speed: float
var range: float
var ground_damage: float
var air_damage: float
var fire_rate: float
var supply_radius: float = 0.0
var armor: String = "light"

var current_order: int = Constants.UnitOrder.HOLD_POSITION
var order_target_position: Vector3 = Vector3.ZERO
var order_target_building: Node = null

var carried_by: Node = null
var is_carried: bool = false

var current_enemy_target: Node = null
var attack_cooldown: float = 0.0
var is_destroyed: bool = false

var _nearby_bodies: Array[Node] = []
var _was_navigation_finished: bool = true
var _order_label: Label3D = null
var _body_material: StandardMaterial3D
var _flash_remaining: float = 0.0
var _health_bar: MeshInstance3D = null
var _health_bar_material: StandardMaterial3D
var _wreck_remaining: float = 0.0

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var detection_area: Area3D = $DetectionArea
@onready var detection_shape: CollisionShape3D = $DetectionArea/CollisionShape3D
@onready var muzzle: Node3D = get_node_or_null("Muzzle")


func _ready() -> void:
	_load_stats()
	_apply_team_color()
	_apply_detection_radius()
	_create_order_label()
	_create_health_bar()
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = Constants.UNIT_NAVIGATION_ARRIVAL_DISTANCE
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	add_to_group("units")
	_refresh_order_target()
	_update_order_label()
	EventBus.unit_created.emit(self)


func _physics_process(delta: float) -> void:
	if is_carried:
		return
	if is_destroyed:
		_update_wreck(delta)
		return
	_update_timers(delta)
	_update_combat(delta)
	_update_movement(delta)
	_update_health_bar()


func give_order(order: int, target_position: Vector3 = Vector3.ZERO, target_building: Node = null) -> void:
	current_order = order
	order_target_position = target_position
	order_target_building = target_building
	_refresh_order_target()
	_update_order_label()
	EventBus.unit_order_changed.emit(self, current_order)


func move_to(destination: Vector3) -> void:
	give_order(Constants.UnitOrder.ADVANCE_TO_TARGET, destination)


func stop() -> void:
	give_order(Constants.UnitOrder.HOLD_POSITION)


func take_damage(amount: float, attacker: Node = null) -> void:
	if is_destroyed:
		return
	hp = max(0.0, hp - amount * Constants.armor_multiplier(armor))
	_flash_remaining = Constants.DAMAGE_FLASH_DURATION
	if hp <= 0.0:
		die()


func die() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	EventBus.unit_destroyed.emit(self)
	detection_area.monitoring = false
	_nearby_bodies.clear()
	current_enemy_target = null
	_order_label.visible = false
	if _health_bar != null:
		_health_bar.visible = false
	_body_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wreck_remaining = WRECK_FADE_DURATION


func set_carried(carried: bool) -> void:
	is_carried = carried
	carried_by = _own_commander() if carried else null
	visible = not carried
	collision_shape.disabled = carried
	detection_area.monitoring = not carried
	if carried:
		velocity = Vector3.ZERO
		_nearby_bodies.clear()
		current_enemy_target = null
	else:
		_refresh_order_target()


func _load_stats() -> void:
	var data: Dictionary = UnitDatabase.get_unit_data(unit_type)
	max_hp = data.get("hp", 100.0)
	hp = max_hp
	max_fuel = data.get("fuel", 100.0)
	fuel = max_fuel
	max_ammo = data.get("ammo", 0.0)
	ammo = max_ammo
	speed = data.get("speed", Constants.UNIT_DEFAULT_SPEED)
	range = data.get("range", 0.0)
	ground_damage = data.get("ground_damage", 0.0)
	air_damage = data.get("air_damage", 0.0)
	fire_rate = data.get("fire_rate", 1.0)
	supply_radius = data.get("supply_radius", 0.0)
	armor = data.get("armor", "light")


func _update_timers(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	_update_flash(delta)


func _update_combat(delta: float) -> void:
	if supply_radius > 0.0:
		_update_supply_aura(delta)
		return
	if ground_damage <= 0.0 and air_damage <= 0.0:
		return

	current_enemy_target = _find_target()
	if current_enemy_target != null and attack_cooldown <= 0.0 and ammo > 0.0:
		_fire_at(current_enemy_target)


## Priority order: 1) an airborne enemy commander, if we can hit air at all;
## 2/3) the nearest enemy unit/commander in range, except an enemy actively
## capturing one of our outposts always outranks a plain skirmish target;
## 4) the HQ/outpost we were ordered to attack, once nothing more urgent
## qualifies.
func _find_target() -> Node:
	var air_target: Node = _find_air_commander_target()
	if air_target != null:
		return air_target

	var skirmish_target: Node = _find_skirmish_target()
	if skirmish_target != null:
		return skirmish_target

	return _find_ordered_attack_target()


func _find_air_commander_target() -> Node:
	if air_damage <= 0.0:
		return null
	var hostile_commander: Node = _enemy_commander()
	if hostile_commander == null or hostile_commander not in _nearby_bodies:
		return null
	if hostile_commander.get("mode") != Constants.CommanderMode.AIR:
		return null
	return hostile_commander if _is_valid_target(hostile_commander) else null


func _find_skirmish_target() -> Node:
	var nearest_enemy: Node = null
	var nearest_distance: float = INF
	var outpost_threat: Node = null
	var outpost_threat_distance: float = INF

	for body in _nearby_bodies:
		if not _is_valid_target(body) or not _is_unit_or_commander(body):
			continue
		var distance: float = global_position.distance_to(body.global_position)
		if distance < nearest_distance:
			nearest_enemy = body
			nearest_distance = distance
		if _is_capturing_friendly_outpost(body) and distance < outpost_threat_distance:
			outpost_threat = body
			outpost_threat_distance = distance

	return outpost_threat if outpost_threat != null else nearest_enemy


func _find_ordered_attack_target() -> Node:
	if current_order != Constants.UnitOrder.ATTACK_BASE:
		return null
	var hq: Node = order_target_building
	if is_instance_valid(hq) and hq in _nearby_bodies and _is_valid_target(hq):
		return hq
	return null


func _is_unit_or_commander(body: Node) -> bool:
	return body.is_in_group("units") or body == GameState.player_commander or body == GameState.enemy_commander


## True if body is an enemy currently inside the capture radius of one of
## our outposts with an order to capture it -- worth interrupting a
## skirmish for, since losing the outpost is costlier than one kill.
func _is_capturing_friendly_outpost(body: Node) -> bool:
	if body.get("current_order") != Constants.UnitOrder.CAPTURE_OUTPOST:
		return false
	for outpost in GameState.outposts:
		if is_instance_valid(outpost) and outpost.get("team") == team \
			and outpost.global_position.distance_to(body.global_position) <= Constants.CAPTURE_RADIUS:
			return true
	return false


func _enemy_commander() -> Node:
	return GameState.enemy_commander if team == Constants.Team.PLAYER else GameState.player_commander


func _is_valid_target(body: Node) -> bool:
	if not is_instance_valid(body) or body.get("team") != GameState.get_enemy_team(team):
		return false
	if body.get("is_destroyed") == true:
		return false
	if _is_unit_or_commander(body):
		return _damage_for_target(body) > 0.0
	# Anything else on the detection layer is assumed to be a building.
	return ground_damage > 0.0 and body.has_method("take_damage")


## air_damage only ever applies to a commander currently flying in AIR
## mode; everything else (grounded commander, units, buildings) takes
## ground_damage.
func _damage_for_target(body: Node) -> float:
	var is_commander: bool = body == GameState.player_commander or body == GameState.enemy_commander
	if is_commander and body.get("mode") == Constants.CommanderMode.AIR:
		return air_damage
	return ground_damage


func _fire_at(target: Node) -> void:
	ammo -= AMMO_PER_SHOT
	attack_cooldown = fire_rate
	_spawn_projectile(target)


## Artillery lobs a slower, larger, visually arcing shell; everyone else
## fires a flat, fast bolt straight at the target.
func _spawn_projectile(target: Node) -> void:
	var is_artillery: bool = unit_type == Constants.UnitType.ARTILLERY
	var projectile: Node3D = PROJECTILE_SCENE.instantiate() as Node3D
	_get_effects_root().add_child(projectile)
	projectile.global_position = muzzle.global_position if muzzle != null else global_position
	projectile.set("team", team)
	projectile.set("damage", _damage_for_target(target))
	projectile.set("speed", ARTILLERY_PROJECTILE_SPEED if is_artillery else PROJECTILE_SPEED)
	projectile.set("target_position", target.global_position)
	projectile.set("can_hit_air", air_damage > 0.0)
	projectile.set("can_hit_ground", ground_damage > 0.0)
	projectile.set("source", self)
	projectile.set("is_arcing", is_artillery)
	if is_artillery:
		projectile.scale = Vector3.ONE * ARTILLERY_PROJECTILE_SCALE


func _get_effects_root() -> Node:
	var effects_root: Node = get_parent().get_parent().get_node_or_null("EffectsRoot")
	return effects_root if effects_root != null else get_parent()


func _update_supply_aura(delta: float) -> void:
	for body in _nearby_bodies:
		if is_instance_valid(body) and body.get("team") == team and body.is_in_group("units"):
			_resupply(body, delta)


func _resupply(body: Node, delta: float) -> void:
	body.set("hp", min(body.get("max_hp"), body.get("hp") + SUPPLY_REPAIR_RATE * delta))
	body.set("fuel", min(body.get("max_fuel"), body.get("fuel") + SUPPLY_REFUEL_RATE * delta))
	body.set("ammo", min(body.get("max_ammo"), body.get("ammo") + SUPPLY_RELOAD_RATE * delta))


func _update_movement(delta: float) -> void:
	if navigation_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		if not _was_navigation_finished:
			_refresh_order_target()
		_was_navigation_finished = true
		return

	_was_navigation_finished = false
	var direction: Vector3 = _steering_direction(navigation_agent.get_next_path_position())
	if direction == Vector3.ZERO:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var current_speed: float = speed if fuel > 0.0 else speed * SLOW_SPEED_MULTIPLIER
	velocity = direction * current_speed
	move_and_slide()
	_update_fuel(delta)


## Steers toward the next path waypoint; if the nav agent can't produce a
## real path yet (e.g. navmesh not baked/ready), falls back to heading
## straight at the raw target instead of stalling in place.
func _steering_direction(next_path_position: Vector3) -> Vector3:
	var to_waypoint: Vector3 = next_path_position - global_position
	to_waypoint.y = 0.0
	if to_waypoint.length() > DIRECT_STEER_EPSILON:
		return to_waypoint.normalized()

	var to_target: Vector3 = navigation_agent.target_position - global_position
	to_target.y = 0.0
	return to_target.normalized() if to_target.length() > DIRECT_STEER_EPSILON else Vector3.ZERO


func _update_fuel(delta: float) -> void:
	fuel = max(0.0, fuel - FUEL_DRAIN_RATE * delta)


func _refresh_order_target() -> void:
	navigation_agent.target_position = UnitOrder.resolve_movement_target(self)


## Unit scenes vary in how many visual parts they have (hull, turret,
## wheels, ...), so every MeshInstance3D in the scene is tinted rather than
## assuming a single fixed mesh node.
func _apply_team_color() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Constants.team_color(team)
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = _body_material


func _apply_detection_radius() -> void:
	var shape: SphereShape3D = detection_shape.shape.duplicate() as SphereShape3D
	shape.radius = max(max(range, supply_radius), 0.1)
	detection_shape.shape = shape


func _create_order_label() -> void:
	_order_label = Label3D.new()
	_order_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_order_label.position = Vector3(0.0, ORDER_LABEL_HEIGHT, 0.0)
	add_child(_order_label)


func _update_order_label() -> void:
	_order_label.text = Constants.UNIT_ORDER_ABBREVIATIONS.get(current_order, "")


## Built in code rather than the .tscn (like the order label above) so all
## 8 unit scenes stay untouched; hidden until the unit first takes damage.
func _create_health_bar() -> void:
	_health_bar = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = HEALTH_BAR_SIZE
	_health_bar.mesh = mesh
	_health_bar_material = StandardMaterial3D.new()
	_health_bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_health_bar_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar_material.albedo_color = Constants.team_color(team)
	_health_bar.material_override = _health_bar_material
	_health_bar.position = Vector3(0.0, HEALTH_BAR_HEIGHT, 0.0)
	_health_bar.visible = false
	add_child(_health_bar)


func _update_health_bar() -> void:
	var ratio: float = hp / max_hp if max_hp > 0.0 else 0.0
	_health_bar.visible = ratio < 1.0
	if _health_bar.visible:
		_health_bar.scale.x = clamp(ratio, 0.05, 1.0)


func _update_flash(delta: float) -> void:
	if _flash_remaining <= 0.0:
		return
	_flash_remaining -= delta
	_body_material.albedo_color = Constants.DAMAGE_FLASH_COLOR if _flash_remaining > 0.0 else Constants.team_color(team)


func _update_wreck(delta: float) -> void:
	_wreck_remaining -= delta
	_body_material.albedo_color.a = clamp(_wreck_remaining / WRECK_FADE_DURATION, 0.0, 1.0)
	if _wreck_remaining <= 0.0:
		queue_free()


func _own_commander() -> Node:
	return GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander


func _on_detection_body_entered(body: Node) -> void:
	if body != self and body not in _nearby_bodies:
		_nearby_bodies.append(body)


func _on_detection_body_exited(body: Node) -> void:
	_nearby_bodies.erase(body)
	if body == current_enemy_target:
		current_enemy_target = null
