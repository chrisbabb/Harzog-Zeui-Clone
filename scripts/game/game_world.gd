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
var player_heroes: Array = []  # References to player heroes

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

	# Spawn mini bases across the map
	_spawn_mini_bases()

	# Initialize resource system
	GameManager.initialize_resources()

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
		player_heroes.append(hero)  # Store reference

		# Set main base reference for respawning
		hero.set_main_base(base)

		# Attach camera to hero
		if i < player_cameras.size():
			var camera = player_cameras[i]
			camera.reparent(hero)
			camera.position = Vector2.ZERO


## Create a main base for a player
func _create_main_base(player: Dictionary, position: Vector2) -> Node2D:
	# Create as StaticBody2D so it can block units
	var base = StaticBody2D.new()
	base.position = position
	base.z_index = 0  # Ensure bases render below air units

	# Set collision layers - bases are on ground layer
	base.collision_layer = 1  # Ground layer (blocks ground units)
	base.collision_mask = 0   # Bases don't need to detect anything

	# Set the script FIRST so properties are defined
	base.set_script(preload("res://scripts/buildings/main_base.gd"))

	# Now set the properties directly (after script is set)
	base.owner_slot = player.slot_index
	base.team_color = player.color
	base.max_health = 1000.0
	base.current_health = 1000.0

	base.add_to_group("main_bases")
	base.add_to_group("buildings")

	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(100, 100)
	collision.shape = shape
	base.add_child(collision)

	# Add visual representation (placeholder)
	var sprite = ColorRect.new()
	sprite.size = Vector2(100, 100)
	sprite.position = Vector2(-50, -50)
	sprite.color = _get_color_from_string(player.color)
	base.add_child(sprite)

	# Add health bar
	var health_bar = ProgressBar.new()
	health_bar.size = Vector2(100, 10)
	health_bar.position = Vector2(-50, -65)
	health_bar.min_value = 0
	health_bar.max_value = 1000.0
	health_bar.value = 1000.0
	health_bar.show_percentage = false
	health_bar.name = "HealthBar"
	base.add_child(health_bar)

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

	# Create a CanvasLayer to hold the UI elements (so they stay on screen)
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer"
	ui_layer.layer = 100  # High layer to ensure it's on top
	add_child(ui_layer)

	# Create minimap instance
	minimap = minimap_script.new()
	minimap.set_world_size(world_width, world_height)
	minimap.set_game_world(self)
	ui_layer.add_child(minimap)

	# Create resource display for player 1
	var resource_display_script = load("res://scripts/ui/resource_display.gd")
	var resource_display = resource_display_script.new()
	resource_display.player_slot = 1  # Show player 1's resources
	ui_layer.add_child(resource_display)

	# Create build progress indicator for player 1
	var build_progress_script = load("res://scripts/ui/build_progress_indicator.gd")
	var build_progress = build_progress_script.new()
	build_progress.player_slot = 1
	ui_layer.add_child(build_progress)

	# Create build menu for player 1
	var build_menu_script = load("res://scripts/ui/build_menu.gd")
	var build_menu = build_menu_script.new()
	build_menu.player_slot = 1
	ui_layer.add_child(build_menu)

	# Create cargo indicator for player 1
	var cargo_indicator_script = load("res://scripts/ui/cargo_indicator.gd")
	var cargo_indicator = cargo_indicator_script.new()
	if player_heroes.size() > 0:
		cargo_indicator.set_hero(player_heroes[0])  # Player 1's hero
	ui_layer.add_child(cargo_indicator)

	print("UI elements created (minimap, resources, build menu, cargo)")


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


## Handle main base destruction (win condition)
func on_base_destroyed(destroyed_player_slot: int) -> void:
	print("Player %d's main base was destroyed!" % destroyed_player_slot)

	# Find remaining players
	var remaining_players = []
	for player in GameManager.active_players:
		if player.slot_index != destroyed_player_slot:
			remaining_players.append(player)

	# Check win condition
	if remaining_players.size() == 1:
		var winner = remaining_players[0]
		_show_victory_screen(winner)
	elif remaining_players.size() == 0:
		_show_draw_screen()


## Show victory screen
func _show_victory_screen(winner: Dictionary) -> void:
	print("======================")
	print("VICTORY!")
	print("Player %d (%s) WINS!" % [winner.slot_index, winner.color])
	print("======================")

	# Pause the game
	get_tree().paused = true

	# Create victory UI overlay
	var ui_layer = get_node_or_null("UILayer")
	if not ui_layer:
		return

	# Create semi-transparent dark background
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.position = Vector2.ZERO
	overlay.z_index = 1000
	ui_layer.add_child(overlay)

	# Create victory panel
	var panel = PanelContainer.new()
	panel.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 300, get_viewport().get_visible_rect().size.y / 2 - 150)
	panel.size = Vector2(600, 300)
	panel.z_index = 1001
	ui_layer.add_child(panel)

	# Create vertical box layout for panel contents
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	# Add spacing at top
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(top_spacer)

	# Victory title
	var title_label = Label.new()
	title_label.text = "VICTORY!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))  # Gold color
	vbox.add_child(title_label)

	# Winner announcement
	var winner_label = Label.new()
	winner_label.text = "Player %d (%s) Wins!" % [winner.slot_index, winner.color]
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 32)
	winner_label.add_theme_color_override("font_color", _get_color_from_string(winner.color))
	vbox.add_child(winner_label)

	# Add spacing
	var middle_spacer = Control.new()
	middle_spacer.custom_minimum_size = Vector2(0, 40)
	vbox.add_child(middle_spacer)

	# Return to Main Menu button
	var menu_button = Button.new()
	menu_button.text = "Return to Main Menu"
	menu_button.custom_minimum_size = Vector2(300, 60)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_button.add_theme_font_size_override("font_size", 24)
	menu_button.pressed.connect(_on_return_to_menu_pressed)
	vbox.add_child(menu_button)


## Show draw screen (all bases destroyed simultaneously)
func _show_draw_screen() -> void:
	print("======================")
	print("DRAW - All bases destroyed!")
	print("======================")

	# Create draw UI overlay
	var ui_layer = get_node_or_null("UILayer")
	if ui_layer:
		var draw_label = Label.new()
		draw_label.text = "DRAW - All bases destroyed!"
		draw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		draw_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		draw_label.position = Vector2(get_viewport().get_visible_rect().size.x / 2 - 200, get_viewport().get_visible_rect().size.y / 2 - 50)
		draw_label.size = Vector2(400, 100)
		draw_label.add_theme_font_size_override("font_size", 32)
		draw_label.add_theme_color_override("font_color", Color.WHITE)
		ui_layer.add_child(draw_label)


## Handle return to main menu button press
func _on_return_to_menu_pressed() -> void:
	# Unpause the game
	get_tree().paused = false

	# Change to main menu scene
	# If main menu exists, load it; otherwise reload current scene
	if ResourceLoader.exists("res://scenes/ui/main_menu.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	else:
		# Fallback: just reload the game
		get_tree().reload_current_scene()
