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

@export var team: int = Constants.Team.PLAYER
@export var max_hp: float = Constants.HQ_MAX_HP
@export var armor: String = "heavy"
@export var refuel_radius: float = 14.0
@export var repair_radius: float = 12.0
@export var production_radius: float = 14.0

var building_type: int = Constants.BuildingType.HQ
var hp: float
var is_destroyed: bool = false
var unit_delivery_queue: Array = []
var _delivery_timer: float = 0.0
var _health_bar: MeshInstance3D
var _health_bar_material: StandardMaterial3D
var _visual_root: Node3D = null
var _animator: BuildingAnimator = null
var _damage_states: DamageStateController = null

@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	hp = max_hp
	_build_visual()
	_create_health_bar()
	update_team_material()
	GameState.register_hq(self)
	add_to_group("buildings")


func _physics_process(delta: float) -> void:
	# A destroyed HQ is a wreck mid-destruction-sequence: no more supply,
	# production, or animation -- only DamageStateController's tween/emitters.
	if is_destroyed:
		return
	_update_supply(delta)
	_update_delivery(delta)
	_update_health_bar()
	_animator.update(delta, hp / max_hp if max_hp > 0.0 else 0.0, get_queue_size() > 0)
	_damage_states.update(delta, hp / max_hp if max_hp > 0.0 else 0.0)


func setup(new_team: int, new_position: Vector3) -> void:
	team = new_team
	position = new_position


func take_damage(amount: float, attacker: Node = null) -> void:
	if is_destroyed:
		return
	var applied: float = amount * Constants.armor_multiplier(armor)
	hp = max(0.0, hp - applied)
	_animator.on_damaged()
	VFXManager.spawn_damage_number(global_position + Vector3(0.0, 9.0, 0.0), applied)
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
	EventBus.commander_fuel_changed.emit(commander.get("team"), new_fuel)


func reload_commander(commander: Node, delta: float) -> void:
	var ammo: float = commander.get("ammo")
	if ammo >= Constants.MAX_PLAYER_AMMO:
		return
	var new_ammo: float = min(Constants.MAX_PLAYER_AMMO, ammo + RELOAD_RATE * delta)
	commander.set("ammo", new_ammo)
	EventBus.commander_ammo_changed.emit(commander.get("team"), new_ammo)


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
	_animator.set_team(team)
	_health_bar_material.albedo_color = Constants.team_color(team)


func _update_supply(delta: float) -> void:
	var commander: Node = GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander
	if commander != null and is_instance_valid(commander):
		var distance: float = global_position.distance_to(commander.global_position)
		if distance <= repair_radius:
			repair_commander(commander, delta)
		if distance <= refuel_radius:
			refuel_commander(commander, delta)
			reload_commander(commander, delta)

	var team_group: String = "player_units" if team == Constants.Team.PLAYER else "enemy_units"
	for unit in get_tree().get_nodes_in_group(team_group):
		if global_position.distance_to(unit.global_position) <= repair_radius:
			_heal(unit, REPAIR_RATE * delta)


func _heal(target: Node, amount: float) -> void:
	var hp_value: float = target.get("hp")
	var max_value: float = target.get("max_hp")
	target.set("hp", min(max_value, hp_value + amount))


## Latched alongside GameState.end_match's own single-fire guard: multiple
## lethal hits landing on the same frame must not emit building_destroyed or
## end the match more than once. Destruction is a staged sequence (internal
## flashes -> main explosion -> collapse -> plume) run by
## DamageStateController; GameState.end_match fires at the main-explosion
## beat inside it, and the node deliberately stays in the tree as a wreck
## behind the match-end screen instead of queue_free-ing.
func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	EventBus.building_destroyed.emit(self)
	_health_bar.visible = false
	unit_delivery_queue.clear()
	_damage_states.play_hq_destruction(GameState.get_enemy_team(team))


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


## Clears the .tscn's placeholder BodyMesh/TowerMesh and builds this HQ's
## final-style visual via BuildingVisualFactory, then hands the result to a
## fresh BuildingAnimator that owns all further per-frame motion/flash
## animation for this HQ (see BuildingAnimator.gd). This is a procedural
## final-style placeholder model -- meant to be replaced by an authored
## Blender asset later without touching any other system.
func _build_visual() -> void:
	var old_body: Node = get_node_or_null("BodyMesh")
	if old_body != null:
		old_body.queue_free()
	var old_tower: Node = get_node_or_null("TowerMesh")
	if old_tower != null:
		old_tower.queue_free()

	_visual_root = BuildingVisualFactory.create_hq_visual(team)
	add_child(_visual_root)

	_animator = BuildingAnimator.new()
	_animator.setup(_visual_root, building_type, team)

	_damage_states = DamageStateController.new()
	_damage_states.setup_building(self, _visual_root, building_type, team, _animator)
