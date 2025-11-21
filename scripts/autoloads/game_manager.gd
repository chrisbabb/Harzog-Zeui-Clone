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


func _ready() -> void:
	print("GameManager initialized")


func _process(delta: float) -> void:
	if current_state == GameState.IN_GAME:
		_update_resource_generation(delta)


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

	for player in active_players:
		player_resources[player.slot_index] = 0.0
		player_base_counts[player.slot_index] = 1  # Start with main base

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
