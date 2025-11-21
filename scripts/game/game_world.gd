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

# UI elements
var minimap: Control = null

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

	# Spawn test enemies for each player
	_spawn_test_enemies()

	# Spawn mini bases across the map
	_spawn_mini_bases()

	# Create minimap UI
	_create_minimap()


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

		# Set main base reference for respawning
		hero.set_main_base(base)

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


## Spawn test enemies for combat testing
func _spawn_test_enemies() -> void:
	# Spawn enemies near each AI player's base
	for i in range(GameManager.active_players.size()):
		var player = GameManager.active_players[i]

		# Only spawn enemies for AI players
		if not player.type.begins_with("AI_"):
			continue

		var base_pos = BASE_SPAWN_POSITIONS[i]
		var enemy_color = player.color
		var owner_slot = player.slot_index

		# Spawn 3 ground soldiers in a line
		for j in range(3):
			var soldier = _spawn_unit("ground_soldier", base_pos + Vector2(-200, -100 + j * 80), owner_slot, enemy_color)
			$Units.add_child(soldier)

		# Spawn 2 tanks
		var tank1 = _spawn_unit("tank", base_pos + Vector2(-150, -150), owner_slot, enemy_color)
		$Units.add_child(tank1)
		var tank2 = _spawn_unit("tank", base_pos + Vector2(-150, 150), owner_slot, enemy_color)
		$Units.add_child(tank2)

		# Spawn 2 missile soldiers (for anti-air)
		var missile_soldier1 = _spawn_unit("missile_soldier", base_pos + Vector2(-250, 0), owner_slot, enemy_color)
		$Units.add_child(missile_soldier1)
		var missile_soldier2 = _spawn_unit("missile_soldier", base_pos + Vector2(-250, 100), owner_slot, enemy_color)
		$Units.add_child(missile_soldier2)

		# Spawn 1 gun turret near base
		var turret = _spawn_unit("gun_turret", base_pos + Vector2(-100, 0), owner_slot, enemy_color)
		$Buildings.add_child(turret)

		print("Spawned test enemies for Player %d (%s)" % [player.slot_index, player.color])


## Spawn a unit of specified type
func _spawn_unit(unit_type: String, position: Vector2, owner_slot: int, team_color: String) -> Node:
	var scene_path = "res://scenes/units/%s.tscn" % unit_type
	var unit_scene = load(scene_path)
	var unit = unit_scene.instantiate()

	unit.position = position
	unit.set_owner_info(owner_slot, team_color)

	# Color the unit based on team
	if unit.has_node("Visual"):
		var visual = unit.get_node("Visual")
		visual.color = _get_color_from_string(team_color)

	return unit


## Spawn mini bases across the map
func _spawn_mini_bases() -> void:
	# Spawn mini bases in strategic locations across the map
	# Avoid spawning too close to player main bases
	var mini_base_scene = preload("res://scenes/buildings/mini_base.tscn")

	# Define mini base spawn positions (spread across the map)
	var mini_base_positions = [
		Vector2(2000, 750),   # Center-top
		Vector2(2000, 2250),  # Center-bottom
		Vector2(1000, 1500),  # Left-center
		Vector2(3000, 1500),  # Right-center
		Vector2(1000, 750),   # Top-left
		Vector2(3000, 750),   # Top-right
		Vector2(1000, 2250),  # Bottom-left
		Vector2(3000, 2250),  # Bottom-right
		Vector2(2000, 1500),  # Dead center
	]

	for pos in mini_base_positions:
		var mini_base = mini_base_scene.instantiate()
		mini_base.position = pos
		$Buildings.add_child(mini_base)

	print("Spawned %d mini bases" % mini_base_positions.size())


## Create and setup minimap
func _create_minimap() -> void:
	# Load the minimap script
	var minimap_script = load("res://scripts/ui/minimap.gd")

	# Create a CanvasLayer to hold the minimap (so it stays on screen)
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "MinimapLayer"
	ui_layer.layer = 100  # High layer to ensure it's on top
	add_child(ui_layer)

	# Create minimap instance
	minimap = minimap_script.new()
	minimap.set_world_size(world_width, world_height)
	minimap.set_game_world(self)
	ui_layer.add_child(minimap)

	print("Minimap created")


## Get player cameras (for minimap access)
func get_player_cameras() -> Array:
	return player_cameras


func _process(_delta: float) -> void:
	# Update camera positions to handle toroidal wrapping
	for i in range(player_cameras.size()):
		var camera = player_cameras[i]
		if camera and camera.get_parent():
			# Ensure camera follows hero correctly across world boundaries
			var hero_pos = camera.get_parent().global_position
			camera.global_position = hero_pos
