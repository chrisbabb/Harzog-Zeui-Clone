extends StaticBody3D
## A team's main HQ. Cannot be captured -- only destroyed, which ends the
## match. Provides full-strength resupply to nearby friendly commander/units
## and can queue freshly purchased units for delivery at its spawn point.

const UNIT_SCENE: PackedScene = preload("res://scenes/units/Unit.tscn")

const REPAIR_RATE: float = 40.0
const REFUEL_RATE: float = 25.0
const RELOAD_RATE: float = 8.0

@export var team: int = Constants.Team.PLAYER
@export var max_hp: float = Constants.HQ_MAX_HP
@export var refuel_radius: float = 14.0
@export var repair_radius: float = 12.0

var building_type: int = Constants.BuildingType.HQ
var hp: float
var unit_delivery_queue: Array = []

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var tower_mesh: MeshInstance3D = $TowerMesh
@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	hp = max_hp
	update_team_material()
	GameState.register_hq(self)


func _physics_process(delta: float) -> void:
	_update_supply(delta)


func setup(new_team: int, new_position: Vector3) -> void:
	team = new_team
	position = new_position


func take_damage(amount: float, attacker: Node = null) -> void:
	hp = max(0.0, hp - amount)
	EventBus.building_damaged.emit(self, amount, attacker)
	if hp <= 0.0:
		_destroy()


func repair_commander(commander: Node, delta: float) -> void:
	_heal(commander, REPAIR_RATE * delta)


func refuel_commander(commander: Node, delta: float) -> void:
	var fuel: float = commander.get("fuel")
	if fuel >= Constants.MAX_PLAYER_FUEL:
		return
	var new_fuel: float = min(Constants.MAX_PLAYER_FUEL, fuel + REFUEL_RATE * delta)
	commander.set("fuel", new_fuel)
	EventBus.commander_fuel_changed.emit(new_fuel)


func reload_commander(commander: Node, delta: float) -> void:
	var ammo: float = commander.get("ammo")
	if ammo >= Constants.MAX_PLAYER_AMMO:
		return
	var new_ammo: float = min(Constants.MAX_PLAYER_AMMO, ammo + RELOAD_RATE * delta)
	commander.set("ammo", new_ammo)
	EventBus.commander_ammo_changed.emit(new_ammo)


func enqueue_unit(unit_type: int, order: int) -> void:
	unit_delivery_queue.append({"unit_type": unit_type, "order": order})


func deliver_next_unit() -> Node:
	if unit_delivery_queue.is_empty():
		return null

	var entry: Dictionary = unit_delivery_queue.pop_front()
	var unit: Node3D = UNIT_SCENE.instantiate() as Node3D
	unit.set("team", team)
	unit.set("unit_type", entry["unit_type"])
	unit.set("current_order", entry["order"])

	var units_root: Node = get_parent().get_parent().get_node_or_null("UnitsRoot")
	if units_root == null:
		units_root = get_parent()
	units_root.add_child(unit)
	unit.global_position = get_spawn_position()

	return unit


func get_spawn_position() -> Vector3:
	return spawn_point.global_position


func update_team_material() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Constants.team_color(team)
	body_mesh.material_override = material
	tower_mesh.material_override = material


func _update_supply(delta: float) -> void:
	var commander: Node = GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander
	if commander != null and is_instance_valid(commander):
		var distance: float = global_position.distance_to(commander.global_position)
		if distance <= repair_radius:
			repair_commander(commander, delta)
		if distance <= refuel_radius:
			refuel_commander(commander, delta)
			reload_commander(commander, delta)

	for unit in get_tree().get_nodes_in_group("units"):
		if unit.get("team") != team:
			continue
		if global_position.distance_to(unit.global_position) <= repair_radius:
			_heal(unit, REPAIR_RATE * delta)


func _heal(target: Node, amount: float) -> void:
	var hp_value: Variant = target.get("hp")
	if hp_value != null:
		var max_value: float = target.get("max_hp")
		target.set("hp", min(max_value, hp_value + amount))
		return
	var health_value: Variant = target.get("current_health")
	if health_value != null:
		var max_health_value: float = target.get("max_health")
		target.set("current_health", min(max_health_value, health_value + amount))


func _destroy() -> void:
	EventBus.building_destroyed.emit(self)
	var winning_team: int = GameState.get_enemy_team(team)
	GameState.end_match(winning_team)
	queue_free()
