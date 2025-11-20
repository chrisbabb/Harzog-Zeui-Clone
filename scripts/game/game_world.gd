extends Node2D
## GameWorld - Main game scene with toroidal world and split-screen support
##
## Handles:
## - World initialization
## - Split-screen viewports for 1-4 players
## - Player/AI spawning
## - Main bases spawning
## - Toroidal world boundaries

# World dimensions
@export var world_width: float = 4000.0
@export var world_height: float = 3000.0

# Split-screen viewports
var player_viewports: Array = []
var player_cameras: Array = []

# Spawn positions for main bases (one for each player)
const BASE_SPAWN_POSITIONS = [
	Vector2(500, 500),      # Player 1
	Vector2(3500, 500),     # Player 2
	Vector2(500, 2500),     # Player 3
	Vector2(3500, 2500)     # Player 4
]


func _ready() -> void:
	print("GameWorld initialized")

	# Set toroidal world size
	ToroidalWorld.set_world_size(world_width, world_height)

	# Setup split-screen based on number of active players
	_setup_split_screen()

	# Spawn players and their bases
	_spawn_players_and_bases()

	# Initialize AI players
	_initialize_ai_players()


## Setup split-screen viewports based on number of players
func _setup_split_screen() -> void:
	var num_players = GameManager.active_players.size()

	# Simplified for now - just create cameras
	# TODO: Implement proper split-screen with SubViewports for 2+ players
	for i in range(num_players):
		var camera = Camera2D.new()
		camera.enabled = (i == 0)  # Only first camera enabled for now
		camera.name = "Camera2D_P%d" % (i + 1)
		add_child(camera)
		player_cameras.append(camera)


## Spawn players and their main bases
func _spawn_players_and_bases() -> void:
	for i in range(GameManager.active_players.size()):
		var player = GameManager.active_players[i]
		var spawn_pos = BASE_SPAWN_POSITIONS[i]

		# Spawn main base
		var base = _create_main_base(player, spawn_pos)
		$Buildings.add_child(base)
		player.main_base = base

		# Spawn transformer hero
		var hero = _create_transformer_hero(player, spawn_pos + Vector2(100, 0))
		$Units.add_child(hero)

		# Attach camera to hero
		if i < player_cameras.size():
			var camera = player_cameras[i]
			camera.reparent(hero)
			camera.position = Vector2.ZERO


## Create a main base for a player
func _create_main_base(player: Dictionary, position: Vector2) -> Node2D:
	# TODO: Load actual base scene
	var base = Node2D.new()
	base.position = position
	base.set_meta("owner_slot", player.slot_index)
	base.set_meta("team_color", player.color)
	base.add_to_group("main_bases")
	base.add_to_group("buildings")

	# Add visual representation (placeholder)
	var sprite = ColorRect.new()
	sprite.size = Vector2(100, 100)
	sprite.position = Vector2(-50, -50)
	sprite.color = _get_color_from_string(player.color)
	base.add_child(sprite)

	return base


## Create a transformer hero for a player
func _create_transformer_hero(player: Dictionary, position: Vector2) -> TransformerHero:
	# Load the actual TransformerHero scene
	var hero_scene = preload("res://scenes/units/transformer_hero.tscn")
	var hero = hero_scene.instantiate() as TransformerHero

	hero.position = position
	hero.set_owner_info(player.slot_index, player.color)

	# Color the hero based on team
	if hero.has_node("Visual"):
		var visual = hero.get_node("Visual")
		visual.color = _get_color_from_string(player.color)

	# If this is a human player, attach a PlayerController
	if player.type == "Human":
		var controller = preload("res://scripts/game/player_controller.gd").new()
		controller.player_index = player.slot_index
		controller.name = "PlayerController"
		hero.add_child(controller)
		print("Added PlayerController for Player %d (Human)" % player.slot_index)

	return hero


## Initialize AI players
func _initialize_ai_players() -> void:
	for player in GameManager.active_players:
		if player.type.begins_with("AI_"):
			var difficulty = AIManager.string_to_difficulty(player.type)
			AIManager.register_ai_player(player.slot_index, difficulty)


## Convert color string to Color
func _get_color_from_string(color_string: String) -> Color:
	match color_string:
		"Red":
			return Color.RED
		"Blue":
			return Color.BLUE
		"Green":
			return Color.GREEN
		"Yellow":
			return Color.YELLOW
		"Purple":
			return Color.PURPLE
		"Orange":
			return Color.ORANGE
		_:
			return Color.WHITE


func _process(_delta: float) -> void:
	# Update camera positions to handle toroidal wrapping
	for i in range(player_cameras.size()):
		var camera = player_cameras[i]
		if camera and camera.get_parent():
			# Ensure camera follows hero correctly across world boundaries
			var hero_pos = camera.get_parent().global_position
			camera.global_position = hero_pos
