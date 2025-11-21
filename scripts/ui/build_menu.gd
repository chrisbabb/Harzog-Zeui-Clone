extends Control
class_name BuildMenu
## BuildMenu - UI for building units
##
## Features:
## - Shows available units and their costs
## - Click to build units
## - Toggle with B key

@export var player_slot: int = 1  # Which player's build queue to use

# UI elements
var background: ColorRect = null
var title_label: Label = null
var unit_buttons: Dictionary = {}  # unit_type -> Button
var is_visible_menu: bool = false


func _ready() -> void:
	# Start hidden
	visible = false
	is_visible_menu = false

	# Create background
	background = ColorRect.new()
	background.size = Vector2(300, 200)
	background.color = Color(0.1, 0.1, 0.1, 0.9)
	add_child(background)

	# Create title
	title_label = Label.new()
	title_label.text = "Build Menu (Press B to close)"
	title_label.position = Vector2(10, 10)
	title_label.add_theme_font_size_override("font_size", 16)
	add_child(title_label)

	# Create unit buttons
	_create_unit_buttons()

	# Position in center of screen
	position = Vector2(400, 250)
	size = Vector2(300, 200)


func _create_unit_buttons() -> void:
	var y_offset = 50

	# Create button for each unit type
	for unit_type in GameManager.UNIT_DATA.keys():
		var unit_data = GameManager.UNIT_DATA[unit_type]

		var button = Button.new()
		button.text = "%s (Cost: %d, Time: %.0fs)" % [unit_type.capitalize(), unit_data.cost, unit_data.build_time]
		button.position = Vector2(10, y_offset)
		button.size = Vector2(280, 30)
		button.pressed.connect(_on_unit_button_pressed.bind(unit_type))
		add_child(button)

		unit_buttons[unit_type] = button
		y_offset += 35


func _on_unit_button_pressed(unit_type: String) -> void:
	# Try to start building
	if GameManager.start_building_unit(player_slot, unit_type):
		print("Started building %s" % unit_type)
		# Close menu after starting build
		toggle_menu()
	else:
		print("Failed to start building %s" % unit_type)


func _process(_delta: float) -> void:
	# Update button states based on resources
	_update_button_states()

	# Toggle menu with B key (player-specific action)
	var action_name = "p%d_build_menu" % player_slot
	if Input.is_action_just_pressed(action_name):
		toggle_menu()


func _update_button_states() -> void:
	var resources = GameManager.get_player_resources(player_slot)
	var is_building = GameManager.get_current_build(player_slot).size() > 0

	for unit_type in unit_buttons.keys():
		var button = unit_buttons[unit_type]
		var unit_data = GameManager.UNIT_DATA[unit_type]

		# Disable if not enough resources or already building
		var can_afford = resources >= unit_data.cost
		var can_build = not is_building

		button.disabled = not (can_afford and can_build)

		# Update button color
		if button.disabled:
			button.modulate = Color(0.5, 0.5, 0.5, 1.0)
		else:
			button.modulate = Color(1.0, 1.0, 1.0, 1.0)


func toggle_menu() -> void:
	is_visible_menu = not is_visible_menu
	visible = is_visible_menu
