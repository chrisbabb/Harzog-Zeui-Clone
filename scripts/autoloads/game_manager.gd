extends Node
## GameManager - Global game state and match management
##
## Handles:
## - Match setup and configuration
## - Player/AI slot management
## - Team assignment (color-based)
## - Win/loss conditions
## - Transitioning between menus and gameplay

# Match configuration
var match_config: Dictionary = {
	"players": [],  # Array of player configs
	"terrain_type": "Dirt",  # Dirt, Snow, Forest
	"max_players": 4
}

# Game state
enum GameState {
	MAIN_MENU,
	MATCH_SETUP,
	SETTINGS,
	IN_GAME,
	GAME_OVER
}

var current_state: GameState = GameState.MAIN_MENU

# Available colors for teams
const AVAILABLE_COLORS = ["Red", "Blue", "Green", "Yellow", "Purple", "Orange"]

# Active players in current match
var active_players: Array = []

# Resource system - resources per player slot
var player_resources: Dictionary = {}  # slot_index -> resource_count
var player_base_counts: Dictionary = {}  # slot_index -> number of bases owned

# Resource generation settings
const RESOURCES_PER_BASE_PER_SECOND: float = 1.0

# Build system
var player_build_queues: Dictionary = {}  # slot_index -> {current_build: {...}, completed_units: [...]}

# Unit costs and build times
const UNIT_DATA = {
	"peon": {
		"cost": 10,
		"build_time": 5.0,
		"scene": "res://scenes/units/peon.tscn"
	},
	"soldier": {
		"cost": 10,
		"build_time": 7.0,
		"scene": "res://scenes/units/soldier.tscn"
	}
}


func _ready() -> void:
	print("GameManager initialized")


func _process(delta: float) -> void:
	if current_state == GameState.IN_GAME:
		_update_resource_generation(delta)
		_update_build_queues(delta)


## Create a new player slot configuration
func create_player_slot(slot_index: int, player_type: String, color: String, input_device: String = "") -> Dictionary:
	return {
		"slot_index": slot_index,
		"type": player_type,  # "Human", "AI_Easy", "AI_Normal", "AI_Hard", "Empty"
		"color": color,
		"input_device": input_device,  # For human players
		"is_eliminated": false,
		"main_base": null  # Will be set during game initialization
	}


## Validate match configuration before starting
func validate_match_config() -> bool:
	var non_empty_slots = 0
	for player in match_config.players:
		if player.type != "Empty":
			non_empty_slots += 1

	if non_empty_slots < 1 or non_empty_slots > 4:
		push_error("Invalid number of players: %d (must be 1-4)" % non_empty_slots)
		return false

	return true


## Start a new match with current configuration
func start_match() -> void:
	if not validate_match_config():
		return

	active_players.clear()
	for player in match_config.players:
		if player.type != "Empty":
			active_players.append(player)

	current_state = GameState.IN_GAME

	# Load game scene
	get_tree().change_scene_to_file("res://scenes/game/game_world.tscn")


## Return to main menu
func return_to_main_menu() -> void:
	current_state = GameState.MAIN_MENU
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


## Check if a player is eliminated
func eliminate_player(player_slot: int) -> void:
	for player in active_players:
		if player.slot_index == player_slot:
			player.is_eliminated = true
			check_win_condition()
			break


## Check win conditions
func check_win_condition() -> void:
	var teams_alive: Dictionary = {}

	for player in active_players:
		if not player.is_eliminated:
			if not teams_alive.has(player.color):
				teams_alive[player.color] = []
			teams_alive[player.color].append(player)

	# If only one team remains, they win
	if teams_alive.size() == 1:
		var winning_team = teams_alive.keys()[0]
		print("Team %s wins!" % winning_team)
		end_game(winning_team)


## End the game
func end_game(winning_team: String) -> void:
	current_state = GameState.GAME_OVER
	# TODO: Show victory screen
	print("Game over! Winner: Team %s" % winning_team)


## Initialize resources for all active players
func initialize_resources() -> void:
	player_resources.clear()
	player_base_counts.clear()
	player_build_queues.clear()

	for player in active_players:
		player_resources[player.slot_index] = 0.0
		player_base_counts[player.slot_index] = 1  # Start with main base
		player_build_queues[player.slot_index] = {
			"current_build": null,  # {unit_type, progress, total_time}
			"completed_units": []    # Array of unit_type strings
		}

	print("Resources initialized for %d players" % active_players.size())


## Update resource generation based on owned bases
func _update_resource_generation(delta: float) -> void:
	for player in active_players:
		if player.is_eliminated:
			continue

		var slot = player.slot_index
		var base_count = player_base_counts.get(slot, 0)
		var resources_to_add = base_count * RESOURCES_PER_BASE_PER_SECOND * delta

		player_resources[slot] = player_resources.get(slot, 0.0) + resources_to_add


## Set the number of bases owned by a player
func set_player_base_count(player_slot: int, count: int) -> void:
	player_base_counts[player_slot] = count
	print("Player %d now owns %d bases" % [player_slot, count])


## Get a player's current resources
func get_player_resources(player_slot: int) -> float:
	return player_resources.get(player_slot, 0.0)


## Spend resources for a player (returns true if successful)
func spend_resources(player_slot: int, amount: float) -> bool:
	var current = player_resources.get(player_slot, 0.0)
	if current >= amount:
		player_resources[player_slot] = current - amount
		return true
	return false


## Add resources to a player (for testing or special events)
func add_resources(player_slot: int, amount: float) -> void:
	player_resources[player_slot] = player_resources.get(player_slot, 0.0) + amount


# ============================================
# BUILD SYSTEM
# ============================================

## Start building a unit
func start_building_unit(player_slot: int, unit_type: String) -> bool:
	if not UNIT_DATA.has(unit_type):
		push_error("Unknown unit type: %s" % unit_type)
		return false

	var unit_data = UNIT_DATA[unit_type]
	var build_queue = player_build_queues.get(player_slot)

	if not build_queue:
		push_error("No build queue for player %d" % player_slot)
		return false

	# Check if already building
	if build_queue.current_build != null:
		print("Player %d is already building something" % player_slot)
		return false

	# Check resources
	if not spend_resources(player_slot, unit_data.cost):
		print("Player %d doesn't have enough resources (need %d)" % [player_slot, unit_data.cost])
		return false

	# Start building
	build_queue.current_build = {
		"unit_type": unit_type,
		"progress": 0.0,
		"total_time": unit_data.build_time
	}

	print("Player %d started building %s (cost: %d, time: %.1fs)" % [player_slot, unit_type, unit_data.cost, unit_data.build_time])
	return true


## Update build queues (called every frame)
func _update_build_queues(delta: float) -> void:
	for player in active_players:
		if player.is_eliminated:
			continue

		var slot = player.slot_index
		var build_queue = player_build_queues.get(slot)

		if not build_queue or build_queue.current_build == null:
			continue

		# Update build progress
		var current_build = build_queue.current_build
		current_build.progress += delta

		# Check if build is complete
		if current_build.progress >= current_build.total_time:
			_complete_build(slot, current_build.unit_type)


## Complete a build and add to completed units
func _complete_build(player_slot: int, unit_type: String) -> void:
	var build_queue = player_build_queues.get(player_slot)

	if not build_queue:
		return

	# Add to completed units
	build_queue.completed_units.append(unit_type)

	# Clear current build
	build_queue.current_build = null

	print("Player %d completed building %s! Ready for pickup." % [player_slot, unit_type])


## Get current build info for a player
func get_current_build(player_slot: int) -> Dictionary:
	var build_queue = player_build_queues.get(player_slot)

	if not build_queue or build_queue.current_build == null:
		return {}

	return build_queue.current_build


## Get completed units count
func get_completed_units_count(player_slot: int) -> int:
	var build_queue = player_build_queues.get(player_slot)

	if not build_queue:
		return 0

	return build_queue.completed_units.size()


## Pickup a completed unit (returns unit type or empty string)
func pickup_completed_unit(player_slot: int) -> String:
	var build_queue = player_build_queues.get(player_slot)

	if not build_queue or build_queue.completed_units.is_empty():
		return ""

	var unit_type = build_queue.completed_units.pop_front()
	print("Player %d picked up %s" % [player_slot, unit_type])
	return unit_type


## Check if player has completed units waiting
func has_completed_units(player_slot: int) -> bool:
	return get_completed_units_count(player_slot) > 0
