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

var current_order: int = Constants.UnitOrder.HOLD_POSITION
var order_target_position: Vector3 = Vector3.ZERO
var order_target_building: Node = null

var carried_by: Node = null
var is_carried: bool = false

var current_enemy_target: Node = null
var attack_cooldown: float = 0.0

var _nearby_bodies: Array[Node] = []
var _was_navigation_finished: bool = true

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var detection_area: Area3D = $DetectionArea
@onready var detection_shape: CollisionShape3D = $DetectionArea/CollisionShape3D


func _ready() -> void:
	_load_stats()
	_apply_team_color()
	_apply_detection_radius()
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = Constants.UNIT_NAVIGATION_ARRIVAL_DISTANCE
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	add_to_group("units")
	_refresh_order_target()
	EventBus.unit_created.emit(self)


func _physics_process(delta: float) -> void:
	if is_carried:
		return
	_update_timers(delta)
	_update_combat(delta)
	_update_movement(delta)


func give_order(order: int, target_position: Vector3 = Vector3.ZERO, target_building: Node = null) -> void:
	current_order = order
	order_target_position = target_position
	order_target_building = target_building
	_refresh_order_target()
	EventBus.unit_order_changed.emit(self, current_order)


func move_to(destination: Vector3) -> void:
	give_order(Constants.UnitOrder.ADVANCE_TO_TARGET, destination)


func stop() -> void:
	give_order(Constants.UnitOrder.HOLD_POSITION)


func take_damage(amount: float) -> void:
	hp = max(0.0, hp - amount)
	if hp <= 0.0:
		die()


func die() -> void:
	EventBus.unit_destroyed.emit(self)
	queue_free()


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


func _update_timers(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown -= delta


func _update_combat(delta: float) -> void:
	if supply_radius > 0.0:
		_update_supply_aura(delta)
		return
	if ground_damage <= 0.0 and air_damage <= 0.0:
		return

	current_enemy_target = _find_target()
	if current_enemy_target != null and attack_cooldown <= 0.0 and ammo > 0.0:
		_fire_at(current_enemy_target)


func _find_target() -> Node:
	var nearest: Node = null
	var nearest_distance: float = INF
	for body in _nearby_bodies:
		if not _is_valid_target(body):
			continue
		var distance: float = global_position.distance_to(body.global_position)
		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance
	return nearest


func _is_valid_target(body: Node) -> bool:
	if not is_instance_valid(body) or body.get("team") != GameState.get_enemy_team(team):
		return false
	if body.is_in_group("units") or body == GameState.player_commander or body == GameState.enemy_commander:
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
	target.take_damage(_damage_for_target(target))


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
	var material := StandardMaterial3D.new()
	material.albedo_color = Constants.team_color(team)
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = material


func _apply_detection_radius() -> void:
	var shape: SphereShape3D = detection_shape.shape.duplicate() as SphereShape3D
	shape.radius = max(max(range, supply_radius), 0.1)
	detection_shape.shape = shape


func _own_commander() -> Node:
	return GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander


func _on_detection_body_entered(body: Node) -> void:
	if body != self and body not in _nearby_bodies:
		_nearby_bodies.append(body)


func _on_detection_body_exited(body: Node) -> void:
	_nearby_bodies.erase(body)
	if body == current_enemy_target:
		current_enemy_target = null
