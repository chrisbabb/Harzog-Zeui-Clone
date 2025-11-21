extends Control
class_name BuildProgressIndicator
## BuildProgressIndicator - Shows current build progress outside menu
##
## Features:
## - Displays current unit being built
## - Shows time remaining
## - Shows completed units count

@export var player_slot: int = 1

# UI elements
var background: ColorRect = null
var build_label: Label = null
var completed_label: Label = null


func _ready() -> void:
	# Create background
	background = ColorRect.new()
	background.size = Vector2(250, 70)
	background.color = Color(0.1, 0.1, 0.1, 0.8)
	add_child(background)

	# Create current build label
	build_label = Label.new()
	build_label.position = Vector2(10, 10)
	build_label.add_theme_font_size_override("font_size", 14)
	build_label.text = "Not building"
	add_child(build_label)

	# Create completed units label
	completed_label = Label.new()
	completed_label.position = Vector2(10, 35)
	completed_label.add_theme_font_size_override("font_size", 14)
	completed_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	completed_label.text = "Completed: 0"
	add_child(completed_label)

	# Position below resource display
	position = Vector2(20, 100)
	size = Vector2(250, 70)


func _process(_delta: float) -> void:
	_update_display()


func _update_display() -> void:
	if not build_label or not completed_label:
		return

	# Update current build
	var current_build = GameManager.get_current_build(player_slot)

	if current_build.is_empty():
		build_label.text = "Not building (Press B)"
		build_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	else:
		var unit_type = current_build.unit_type
		var progress = current_build.progress
		var total_time = current_build.total_time
		var time_remaining = total_time - progress

		build_label.text = "Building: %s (%.1fs)" % [unit_type.capitalize(), time_remaining]
		build_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3, 1.0))

	# Update completed units count
	var completed_count = GameManager.get_completed_units_count(player_slot)
	completed_label.text = "Completed: %d (ready for pickup)" % completed_count
