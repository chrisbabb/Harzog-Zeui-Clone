extends StaticBody3D
## A team's main HQ. Cannot be captured -- only destroyed, which ends the
## match. Provides full-strength resupply to nearby friendly commander/units
## and can queue freshly purchased units for delivery at its spawn point.

const REPAIR_RATE: float = 40.0
const REFUEL_RATE: float = 25.0
const RELOAD_RATE: float = 8.0
const DELIVERY_DELAY: float = 1.5
const HEALTH_BAR_HEIGHT: float = 11.0
const HEALTH_BAR_SIZE: Vector3 = Vector3(4.0, 0.3, 0.3)
const TEAM_STRIP_OUTER_RADIUS: float = 3.7
const TEAM_STRIP_INNER_RADIUS: float = 3.4
const TEAM_STRIP_HEIGHT: float = 0.15

@export var team: int = Constants.Team.PLAYER
@export var max_hp: float = Constants.HQ_MAX_HP
@export var armor: String = "heavy"
@export var refuel_radius: float = 14.0
@export var repair_radius: float = 12.0
@export var production_radius: float = 14.0

var building_type: int = Constants.BuildingType.HQ
var hp: float
var unit_delivery_queue: Array = []
var _delivery_timer: float = 0.0
var _body_material: StandardMaterial3D
var _flash_remaining: float = 0.0
var _health_bar: MeshInstance3D
var _health_bar_material: StandardMaterial3D
var _team_strip_material: StandardMaterial3D

@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var tower_mesh: MeshInstance3D = $TowerMesh
@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	hp = max_hp
	_create_health_bar()
	_create_team_strip()
	update_team_material()
	GameState.register_hq(self)


func _physics_process(delta: float) -> void:
	_update_supply(delta)
	_update_delivery(delta)
	_update_flash(delta)
	_update_health_bar()


func setup(new_team: int, new_position: Vector3) -> void:
	team = new_team
	position = new_position


func take_damage(amount: float, attacker: Node = null) -> void:
	hp = max(0.0, hp - amount * Constants.armor_multiplier(armor))
	_flash_remaining = Constants.DAMAGE_FLASH_DURATION
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
	if commander.get("team") == Constants.Team.PLAYER:
		EventBus.commander_fuel_changed.emit(new_fuel)


func reload_commander(commander: Node, delta: float) -> void:
	var ammo: float = commander.get("ammo")
	if ammo >= Constants.MAX_PLAYER_AMMO:
		return
	var new_ammo: float = min(Constants.MAX_PLAYER_AMMO, ammo + RELOAD_RATE * delta)
	commander.set("ammo", new_ammo)
	if commander.get("team") == Constants.Team.PLAYER:
		EventBus.commander_ammo_changed.emit(new_ammo)


func can_produce(_unit_type: int) -> bool:
	return true


func get_queue_size() -> int:
	return unit_delivery_queue.size()


func enqueue_unit(unit_type: int, order: int) -> void:
	if unit_delivery_queue.is_empty():
		_delivery_timer = DELIVERY_DELAY
	unit_delivery_queue.append({"unit_type": unit_type, "order": order})


func deliver_next_unit() -> Node:
	if unit_delivery_queue.is_empty():
		return null

	var entry: Dictionary = unit_delivery_queue.pop_front()
	var unit: Node3D = UnitDatabase.get_unit_scene(entry["unit_type"]).instantiate() as Node3D
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


func _update_delivery(delta: float) -> void:
	if unit_delivery_queue.is_empty():
		return

	_delivery_timer -= delta
	if _delivery_timer <= 0.0:
		deliver_next_unit()
		if not unit_delivery_queue.is_empty():
			_delivery_timer = DELIVERY_DELAY


func update_team_material() -> void:
	if _body_material == null:
		_body_material = StandardMaterial3D.new()
		body_mesh.material_override = _body_material
		tower_mesh.material_override = _body_material
	_body_material.albedo_color = Constants.team_color(team)
	_health_bar_material.albedo_color = Constants.team_color(team)
	_team_strip_material.albedo_color = Constants.team_color(team)
	_team_strip_material.emission = Constants.team_color(team)


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
	var hp_value: float = target.get("hp")
	var max_value: float = target.get("max_hp")
	target.set("hp", min(max_value, hp_value + amount))


func _destroy() -> void:
	EventBus.building_destroyed.emit(self)
	var winning_team: int = GameState.get_enemy_team(team)
	GameState.end_match(winning_team)
	queue_free()


## Built in code rather than the .tscn (like Unit.gd's order label/health
## bar) so Base.tscn stays untouched; hidden until the HQ first takes damage.
func _create_health_bar() -> void:
	_health_bar = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = HEALTH_BAR_SIZE
	_health_bar.mesh = mesh
	_health_bar_material = StandardMaterial3D.new()
	_health_bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_health_bar_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar.material_override = _health_bar_material
	_health_bar.position = Vector3(0.0, HEALTH_BAR_HEIGHT, 0.0)
	_health_bar.visible = false
	add_child(_health_bar)


func _update_health_bar() -> void:
	var ratio: float = hp / max_hp if max_hp > 0.0 else 0.0
	_health_bar.visible = ratio < 1.0
	if _health_bar.visible:
		_health_bar.scale.x = clamp(ratio, 0.05, 1.0)


## A glowing team-colored ring around the HQ's base, built in code like the
## health bar above so Base.tscn stays untouched.
func _create_team_strip() -> void:
	var strip := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = TEAM_STRIP_INNER_RADIUS
	mesh.outer_radius = TEAM_STRIP_OUTER_RADIUS
	strip.mesh = mesh
	_team_strip_material = StandardMaterial3D.new()
	_team_strip_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_team_strip_material.emission_enabled = true
	strip.material_override = _team_strip_material
	strip.position = Vector3(0.0, TEAM_STRIP_HEIGHT, 0.0)
	add_child(strip)


func _update_flash(delta: float) -> void:
	if _flash_remaining <= 0.0:
		return
	_flash_remaining -= delta
	_body_material.albedo_color = Constants.DAMAGE_FLASH_COLOR if _flash_remaining > 0.0 else Constants.team_color(team)
