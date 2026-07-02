extends Node
## Autoload singleton tracking the live state of an in-progress match: the
## match clock, the registered HQs/outposts, the commander references, and
## whatever unit type/order is currently selected in the build/command UI.

var match_active: bool = false
var elapsed_time: float = 0.0

# True while MatchCinematics is running an intro/end sequence: the player
# commander ignores input, Game.gd stops driving the camera, and the HUD
# ignores menu hotkeys. Stays true from match end until the scene changes.
var cinematic_active: bool = false

var player_hq: Node = null
var enemy_hq: Node = null
var outposts: Array[Node] = []

var player_commander: Node = null
var enemy_commander: Node = null

var selected_unit_type: int = Constants.UnitType.SCOUT_BUGGY
var selected_order: int = Constants.UnitOrder.HOLD_POSITION

var winner: int = -1

var player_unit_count: int = 0
var enemy_unit_count: int = 0

# Skirmish setup: chosen once on the setup screen, then read by MapGenerator,
# Economy, EnemyAI, and Game for the whole match. Intentionally left out of
# reset_match_state() so a "Restart Match" keeps the player's chosen settings.
var selected_map: int = Constants.MapPreset.GREEN_DIVIDE
var selected_difficulty: int = 1 # Normal
var selected_starting_credits: int = Constants.STARTING_MONEY
var selected_match_speed: int = Constants.MatchSpeed.NORMAL
var selected_outpost_count: int = 7
var game_mode: int = Constants.GameMode.SINGLE_PLAYER
var split_direction: int = Constants.SplitDirection.VERTICAL

## Seeds TerrainVisualGenerator's RNG so a given match's decoration layout
## (rocks, wrecks, roads-adjacent clutter, ...) is reproducible -- same seed,
## same battlefield dressing. Assigned fresh in configure_skirmish() but,
## like the fields above, intentionally left out of reset_match_state() so
## a "Restart Match" regenerates the identical layout rather than a new one.
var map_seed: int = 0

# Per-player UI selections; P1 uses selected_*, P2 uses p2_selected_*
var p2_selected_unit_type: int = Constants.UnitType.SCOUT_BUGGY
var p2_selected_order: int = Constants.UnitOrder.HOLD_POSITION


func _ready() -> void:
	EventBus.unit_created.connect(_on_unit_created)
	EventBus.unit_destroyed.connect(_on_unit_destroyed)


func _process(delta: float) -> void:
	if match_active:
		elapsed_time += delta


func start_match() -> void:
	match_active = true
	winner = -1
	EventBus.match_started.emit()


## Single-fire by design: the guard makes a second call (both HQs dying in
## the same engagement, or one HQ absorbing two lethal hits in one frame) a
## no-op, so match_ended can never be emitted twice -- and never with a
## contradictory winner.
func end_match(winning_team: int) -> void:
	if not match_active:
		return
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


func get_unit_count(team: int) -> int:
	return player_unit_count if team == Constants.Team.PLAYER else enemy_unit_count


func _on_unit_created(unit: Node) -> void:
	if unit.get("team") == Constants.Team.PLAYER:
		player_unit_count += 1
	elif unit.get("team") == Constants.Team.ENEMY:
		enemy_unit_count += 1


func _on_unit_destroyed(unit: Node) -> void:
	if unit.get("team") == Constants.Team.PLAYER:
		player_unit_count = max(0, player_unit_count - 1)
	elif unit.get("team") == Constants.Team.ENEMY:
		enemy_unit_count = max(0, enemy_unit_count - 1)


func get_enemy_team(team: int) -> int:
	return Constants.Team.ENEMY if team == Constants.Team.PLAYER else Constants.Team.PLAYER


func configure_skirmish(map: int, difficulty: int, starting_credits: int, match_speed: int, outpost_count: int, mode: int = Constants.GameMode.SINGLE_PLAYER, split: int = Constants.SplitDirection.VERTICAL) -> void:
	selected_map = map
	selected_difficulty = difficulty
	selected_starting_credits = starting_credits
	selected_match_speed = match_speed
	selected_outpost_count = outpost_count
	game_mode = mode
	split_direction = split
	map_seed = randi()


func get_selected_unit_type(team: int) -> int:
	return p2_selected_unit_type if team == Constants.Team.ENEMY else selected_unit_type


func set_selected_unit_type(team: int, unit_type: int) -> void:
	if team == Constants.Team.ENEMY:
		p2_selected_unit_type = unit_type
	else:
		selected_unit_type = unit_type


func get_selected_order(team: int) -> int:
	return p2_selected_order if team == Constants.Team.ENEMY else selected_order


func set_selected_order(team: int, order: int) -> void:
	if team == Constants.Team.ENEMY:
		p2_selected_order = order
	else:
		selected_order = order


func reset_match_state() -> void:
	match_active = false
	cinematic_active = false
	elapsed_time = 0.0
	player_hq = null
	enemy_hq = null
	outposts.clear()
	player_commander = null
	enemy_commander = null
	selected_unit_type = Constants.UnitType.SCOUT_BUGGY
	selected_order = Constants.UnitOrder.HOLD_POSITION
	p2_selected_unit_type = Constants.UnitType.SCOUT_BUGGY
	p2_selected_order = Constants.UnitOrder.HOLD_POSITION
	winner = -1
	player_unit_count = 0
	enemy_unit_count = 0
