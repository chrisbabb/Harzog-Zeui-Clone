extends Node
## Autoload singleton tracking the live state of an in-progress match: the
## match clock, the registered HQs/outposts, the commander references, and
## whatever unit type/order is currently selected in the build/command UI.

var match_active: bool = false
var elapsed_time: float = 0.0

var player_hq: Node = null
var enemy_hq: Node = null
var outposts: Array[Node] = []

var player_commander: Node = null
var enemy_commander: Node = null

var selected_unit_type: int = Constants.UnitType.SCOUT_BUGGY
var selected_order: int = Constants.UnitOrder.HOLD_POSITION

var winner: int = -1


func _process(delta: float) -> void:
	if match_active:
		elapsed_time += delta


func start_match() -> void:
	match_active = true
	winner = -1
	EventBus.match_started.emit()


func end_match(winning_team: int) -> void:
	match_active = false
	winner = winning_team
	EventBus.match_ended.emit(winning_team)


func register_outpost(outpost: Node) -> void:
	if outpost not in outposts:
		outposts.append(outpost)


func register_hq(base: Node) -> void:
	if base.get("team") == Constants.Team.PLAYER:
		player_hq = base
	else:
		enemy_hq = base


func get_team_buildings(team: int) -> Array[Node]:
	var buildings: Array[Node] = []
	var hq: Node = player_hq if team == Constants.Team.PLAYER else enemy_hq
	if hq != null and is_instance_valid(hq):
		buildings.append(hq)
	for outpost in outposts:
		if is_instance_valid(outpost) and outpost.get("team") == team:
			buildings.append(outpost)
	return buildings


func get_nearest_friendly_production_building(team: int, position: Vector3) -> Node:
	var nearest: Node = null
	var nearest_distance: float = INF
	for building in get_team_buildings(team):
		var distance: float = building.global_position.distance_to(position)
		if distance < nearest_distance:
			nearest = building
			nearest_distance = distance
	return nearest


func get_enemy_team(team: int) -> int:
	return Constants.Team.ENEMY if team == Constants.Team.PLAYER else Constants.Team.PLAYER


func reset_match_state() -> void:
	match_active = false
	elapsed_time = 0.0
	player_hq = null
	enemy_hq = null
	outposts.clear()
	player_commander = null
	enemy_commander = null
	selected_unit_type = Constants.UnitType.SCOUT_BUGGY
	selected_order = Constants.UnitOrder.HOLD_POSITION
	winner = -1
