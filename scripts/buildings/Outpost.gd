extends StaticBody3D
## Capturable forward outpost. Starts neutral; whichever team holds the
## capture zone uncontested long enough takes ownership. Friendly outposts
## then provide weaker resupply than the main HQ to nearby commanders/units.

const REPAIR_RATE: float = 20.0
const REFUEL_RATE: float = 12.0
const RELOAD_RATE: float = 4.0
const DELIVERY_DELAY: float = 2.5
const HEALTH_BAR_HEIGHT: float = 5.3
const HEALTH_BAR_SIZE: Vector3 = Vector3(2.4, 0.25, 0.25)
const RING_ROTATION_SPEED: float = 0.4
const RING_PULSE_SPEED: float = 6.0
const RING_PULSE_SCALE: float = 0.08
const RING_PULSE_EMISSION_BASE: float = 1.5
const RING_PULSE_EMISSION_AMPLITUDE: float = 0.5

## Outposts can only produce lighter/support units, unlike the HQ which builds everything.
const BUILDABLE_UNIT_TYPES: Array[int] = [
	Constants.UnitType.SCOUT_BUGGY,
	Constants.UnitType.TANK,
	Constants.UnitType.MISSILE_CRAWLER,
	Constants.UnitType.SUPPLY_TRUCK,
	Constants.UnitType.CAPTURE_DRONE,
]

@export var team: int = Constants.Team.NEUTRAL
@export var max_hp: float = Constants.OUTPOST_MAX_HP
@export var armor: String = "heavy"
@export var refuel_radius: float = 10.0
@export var repair_radius: float = 8.0
@export var production_radius: float = 10.0

var hp: float
var capture_progress_player: float = 0.0
var capture_progress_enemy: float = 0.0
var capture_radius: float = Constants.CAPTURE_RADIUS
var unit_delivery_queue: Array = []
var _delivery_timer: float = 0.0
var _body_material: StandardMaterial3D
var _flash_remaining: float = 0.0
var _health_bar: MeshInstance3D
var _health_bar_material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _ring_mesh: MeshInstance3D = null
var _visual_root: Node3D = null

@onready var capture_zone: Area3D = $CaptureZone
@onready var capture_zone_shape: CollisionShape3D = $CaptureZone/CollisionShape3D
@onready var unit_spawn_point: Marker3D = $UnitSpawnPoint
@onready var progress_bar_mesh: MeshInstance3D = $ProgressBarMesh

var _progress_bar_material: StandardMaterial3D


func _ready() -> void:
	hp = max_hp
	_apply_capture_radius()
	_progress_bar_material = StandardMaterial3D.new()
	progress_bar_mesh.material_override = _progress_bar_material
	_build_visual()
	_create_health_bar()
	update_team_material()
	GameState.register_outpost(self)
	add_to_group("buildings")
	add_to_group("outposts")


func _physics_process(delta: float) -> void:
	_update_capture(delta)
	_update_progress_bar()
	_update_supply(delta)
	_update_delivery(delta)
	_update_flash(delta)
	_update_health_bar()
	_update_ring_animation(delta)


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
	EventBus.commander_fuel_changed.emit(commander.get("team"), new_fuel)


func reload_commander(commander: Node, delta: float) -> void:
	var ammo: float = commander.get("ammo")
	if ammo >= Constants.MAX_PLAYER_AMMO:
		return
	var new_ammo: float = min(Constants.MAX_PLAYER_AMMO, ammo + RELOAD_RATE * delta)
	commander.set("ammo", new_ammo)
	EventBus.commander_ammo_changed.emit(commander.get("team"), new_ammo)


func update_team_material() -> void:
	if _body_material != null:
		_body_material.albedo_color = Constants.team_color(team)
	_health_bar_material.albedo_color = Constants.team_color(team)
	if _ring_material != null:
		# MaterialLibrary's emissive accents are intentionally brighter than
		# Constants.team_color() (a flat body tint), so re-derive from the
		# same source the factory used initially rather than
		# Constants.team_color() directly -- otherwise a captured outpost's
		# ring color would shift on every recapture instead of matching.
		var emissive_source: StandardMaterial3D = MaterialLibrary.emissive_for_team(team)
		_ring_material.albedo_color = emissive_source.albedo_color
		_ring_material.emission = emissive_source.emission


func can_produce(unit_type: int) -> bool:
	return unit_type in BUILDABLE_UNIT_TYPES


func get_queue_size() -> int:
	return unit_delivery_queue.size()


func get_spawn_position() -> Vector3:
	return unit_spawn_point.global_position


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


func _update_capture(delta: float) -> void:
	if capture_zone.is_contested():
		return

	var capturing_team: int = capture_zone.get_capturing_team()
	if capturing_team == -1 or capturing_team == team:
		return

	var gain: float = capture_zone.get_capture_rate(capturing_team) * delta / Constants.OUTPOST_CAPTURE_TIME
	if _add_capture_progress(capturing_team, gain) >= 1.0:
		_complete_capture(capturing_team)


func _add_capture_progress(capturing_team: int, gain: float) -> float:
	if capturing_team == Constants.Team.PLAYER:
		capture_progress_player += gain
		return capture_progress_player
	capture_progress_enemy += gain
	return capture_progress_enemy


func _complete_capture(new_team: int) -> void:
	team = new_team
	capture_progress_player = 0.0
	capture_progress_enemy = 0.0
	update_team_material()
	EventBus.building_captured.emit(self, team)


func _update_progress_bar() -> void:
	var progress: float = max(capture_progress_player, capture_progress_enemy)
	progress_bar_mesh.visible = progress > 0.0
	if not progress_bar_mesh.visible:
		return

	var active_team: int = Constants.Team.PLAYER if capture_progress_player >= capture_progress_enemy else Constants.Team.ENEMY
	progress_bar_mesh.scale.x = clamp(progress, 0.05, 1.0)
	_progress_bar_material.albedo_color = Constants.team_color(active_team)


func _update_supply(delta: float) -> void:
	if team == Constants.Team.NEUTRAL:
		return

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


func _apply_capture_radius() -> void:
	var shape: CylinderShape3D = capture_zone_shape.shape.duplicate() as CylinderShape3D
	shape.radius = capture_radius
	capture_zone_shape.shape = shape


func _update_delivery(delta: float) -> void:
	if unit_delivery_queue.is_empty():
		return

	_delivery_timer -= delta
	if _delivery_timer <= 0.0:
		deliver_next_unit()
		if not unit_delivery_queue.is_empty():
			_delivery_timer = DELIVERY_DELAY


func _destroy() -> void:
	EventBus.building_destroyed.emit(self)
	GameState.outposts.erase(self)
	queue_free()


## Clears the .tscn's placeholder TowerMesh/RingMesh (ProgressBarMesh stays
## -- it's a gameplay overlay, not part of the structural visual) and builds
## this outpost's final-style visual via BuildingVisualFactory.
## _body_material/_ring_material become the returned "Hull"/"CaptureRing"
## meshes' own materials, private duplicates BuildingVisualFactory made from
## MaterialLibrary: update_team_material()/_update_flash() mutate
## _body_material, and _update_ring_animation() below mutates _ring_material
## every frame while contested. This is a procedural final-style placeholder
## model -- meant to be replaced by an authored Blender asset later without
## touching any other system.
func _build_visual() -> void:
	var old_tower: Node = get_node_or_null("TowerMesh")
	if old_tower != null:
		old_tower.queue_free()
	var old_ring: Node = get_node_or_null("RingMesh")
	if old_ring != null:
		old_ring.queue_free()

	_visual_root = BuildingVisualFactory.create_outpost_visual(team)
	add_child(_visual_root)

	var hull: MeshInstance3D = _visual_root.get_node_or_null("Hull")
	if hull != null:
		_body_material = hull.material_override as StandardMaterial3D

	_ring_mesh = _visual_root.get_node_or_null("CaptureRing")
	if _ring_mesh != null:
		_ring_material = _ring_mesh.material_override as StandardMaterial3D


## Built in code rather than the .tscn (like Unit.gd's order label/health
## bar) so Outpost.tscn stays untouched; hidden until the outpost first
## takes damage. Placed above the existing capture-progress bar.
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


func _update_flash(delta: float) -> void:
	if _flash_remaining <= 0.0:
		return
	_flash_remaining -= delta
	_body_material.albedo_color = Constants.DAMAGE_FLASH_COLOR if _flash_remaining > 0.0 else Constants.team_color(team)


## Ring always turns slowly so a contested outpost reads as "alive" even
## when idle; it additionally pulses brighter/larger while actively being
## captured (a capturing team exists and the zone isn't deadlocked/contested).
func _update_ring_animation(delta: float) -> void:
	if _ring_mesh == null:
		return
	_ring_mesh.rotate_y(RING_ROTATION_SPEED * delta)

	var being_captured: bool = capture_zone.get_capturing_team() != -1 and not capture_zone.is_contested()
	if not being_captured:
		_ring_mesh.scale = Vector3.ONE
		_ring_material.emission_energy_multiplier = 1.0
		return

	var pulse: float = sin(Time.get_ticks_msec() / 1000.0 * RING_PULSE_SPEED)
	_ring_mesh.scale = Vector3.ONE * (1.0 + pulse * RING_PULSE_SCALE)
	_ring_material.emission_energy_multiplier = RING_PULSE_EMISSION_BASE + pulse * RING_PULSE_EMISSION_AMPLITUDE
