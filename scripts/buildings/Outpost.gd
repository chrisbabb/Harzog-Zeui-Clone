extends StaticBody3D
## Capturable forward outpost. Starts neutral; whichever team holds the
## capture zone uncontested long enough takes ownership. Friendly outposts
## then provide weaker resupply than the main HQ to nearby commanders/units.

const REPAIR_RATE: float = 20.0
const REFUEL_RATE: float = 12.0
const RELOAD_RATE: float = 4.0

@export var team: int = Constants.Team.NEUTRAL
@export var max_hp: float = Constants.OUTPOST_MAX_HP
@export var refuel_radius: float = 10.0
@export var repair_radius: float = 8.0

var hp: float
var capture_progress_player: float = 0.0
var capture_progress_enemy: float = 0.0
var capture_radius: float = Constants.CAPTURE_RADIUS

@onready var tower_mesh: MeshInstance3D = $TowerMesh
@onready var ring_mesh: MeshInstance3D = $RingMesh
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
	update_team_material()
	GameState.register_outpost(self)


func _physics_process(delta: float) -> void:
	_update_capture(delta)
	_update_progress_bar()
	_update_supply(delta)


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


func update_team_material() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Constants.team_color(team)
	tower_mesh.material_override = material
	ring_mesh.material_override = material


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

	for unit in get_tree().get_nodes_in_group("units"):
		if unit.get("team") != team:
			continue
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


func _destroy() -> void:
	EventBus.building_destroyed.emit(self)
	GameState.outposts.erase(self)
	queue_free()
