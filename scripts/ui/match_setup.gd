extends Control
## MatchSetup - Configure players, teams, and terrain before starting a match

# Player type options
const PLAYER_TYPES = ["Human", "AI_Easy", "AI_Normal", "AI_Hard", "Empty"]

# Terrain types
const TERRAIN_TYPES = ["Dirt", "Snow", "Forest"]

# References to UI elements
var player_configs: Array = []


func _ready() -> void:
	GameManager.current_state = GameManager.GameState.MATCH_SETUP
	_setup_player_options()
	_setup_terrain_options()


## Setup player type and color dropdowns
func _setup_player_options() -> void:
	for i in range(1, 5):
		var player_container = $MarginContainer/VBoxContainer/PlayerSetup.get_node("Player%d" % i)
		var type_option = player_container.get_node("TypeOption")
		var color_option = player_container.get_node("ColorOption")

		# Setup type dropdown
		type_option.clear()
		for player_type in PLAYER_TYPES:
			type_option.add_item(player_type)

		# Set default: Player 1 is Human, Player 2 is AI_Normal, others are Empty
		if i == 1:
			type_option.selected = PLAYER_TYPES.find("Human")
		elif i == 2:
			type_option.selected = PLAYER_TYPES.find("AI_Normal")
		else:
			type_option.selected = PLAYER_TYPES.find("Empty")

		# Setup color dropdown
		color_option.clear()
		for color in GameManager.AVAILABLE_COLORS:
			color_option.add_item(color)

		# Set default colors (Red, Blue, Green, Yellow)
		if i <= GameManager.AVAILABLE_COLORS.size():
			color_option.selected = i - 1


## Setup terrain type dropdown
func _setup_terrain_options() -> void:
	var terrain_option = $MarginContainer/VBoxContainer/TerrainSetup/TerrainOption
	terrain_option.clear()
	for terrain in TERRAIN_TYPES:
		terrain_option.add_item(terrain)
	terrain_option.selected = 0  # Default to Dirt


## Back to main menu
func _on_back_pressed() -> void:
	GameManager.return_to_main_menu()


## Start the match
func _on_start_pressed() -> void:
	if _validate_setup():
		_configure_match()
		GameManager.start_match()
	else:
		# Show error message (TODO: Add proper error dialog)
		print("Invalid match setup!")


## Validate match configuration
func _validate_setup() -> bool:
	var non_empty_count = 0

	for i in range(1, 5):
		var player_container = $MarginContainer/VBoxContainer/PlayerSetup.get_node("Player%d" % i)
		var type_option = player_container.get_node("TypeOption")

		if type_option.get_item_text(type_option.selected) != "Empty":
			non_empty_count += 1

	# Must have at least 1 player
	if non_empty_count < 1:
		push_error("Must have at least 1 player")
		return false

	return true


## Configure match settings in GameManager
func _configure_match() -> void:
	GameManager.match_config.players.clear()

	# Configure players
	for i in range(1, 5):
		var player_container = $MarginContainer/VBoxContainer/PlayerSetup.get_node("Player%d" % i)
		var type_option = player_container.get_node("TypeOption")
		var color_option = player_container.get_node("ColorOption")

		var player_type = type_option.get_item_text(type_option.selected)
		var player_color = color_option.get_item_text(color_option.selected)

		# Determine input device for human players
		var input_device = ""
		if player_type == "Human":
			input_device = "KeyboardMouse" if i == 1 else "Controller%d" % (i - 1)

		var player_config = GameManager.create_player_slot(i, player_type, player_color, input_device)
		GameManager.match_config.players.append(player_config)

	# Configure terrain
	var terrain_option = $MarginContainer/VBoxContainer/TerrainSetup/TerrainOption
	GameManager.match_config.terrain_type = terrain_option.get_item_text(terrain_option.selected)

	print("Match configured:")
	print("  Players: ", GameManager.match_config.players)
	print("  Terrain: ", GameManager.match_config.terrain_type)
