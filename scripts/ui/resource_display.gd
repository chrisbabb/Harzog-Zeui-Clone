extends Control
class_name ResourceDisplay
## ResourceDisplay - Shows player resources and generation rate
##
## Features:
## - Displays current resource count
## - Shows resource generation rate
## - Updates in real-time

@export var player_slot: int = 1  # Which player's resources to display

# UI elements
var resource_label: Label = null
var generation_label: Label = null
var background: ColorRect = null


func _ready() -> void:
	# Create background panel
	background = ColorRect.new()
	background.size = Vector2(200, 60)
	background.color = Color(0.1, 0.1, 0.1, 0.8)
	add_child(background)

	# Create resource count label
	resource_label = Label.new()
	resource_label.position = Vector2(10, 10)
	resource_label.add_theme_font_size_override("font_size", 18)
	resource_label.text = "Resources: 0"
	add_child(resource_label)

	# Create generation rate label
	generation_label = Label.new()
	generation_label.position = Vector2(10, 35)
	generation_label.add_theme_font_size_override("font_size", 14)
	generation_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	generation_label.text = "+1/sec (1 base)"
	add_child(generation_label)

	# Position in top-left corner with padding
	position = Vector2(20, 20)

	# Set size
	custom_minimum_size = Vector2(200, 60)
	size = Vector2(200, 60)


func _process(_delta: float) -> void:
	_update_display()


## Update the resource display
func _update_display() -> void:
	if not resource_label or not generation_label:
		return

	# Get current resources
	var resources = GameManager.get_player_resources(player_slot)
	resource_label.text = "Resources: %d" % int(resources)

	# Get base count for generation rate
	var base_count = GameManager.player_base_counts.get(player_slot, 1)
	var generation_rate = base_count * GameManager.RESOURCES_PER_BASE_PER_SECOND
	generation_label.text = "+%.1f/sec (%d bases)" % [generation_rate, base_count]
