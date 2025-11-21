extends ProgressBar
class_name CooldownIndicator
## CooldownIndicator - Shows attack cooldown progress for units
##
## Displays a bar below the unit showing when they can fire again
## - Full bar = ready to fire
## - Empty bar = on cooldown

var tracked_unit: UnitBase = null
@export var offset_y: float = 35.0  # How far below the unit to display


func _ready() -> void:
	# Configure the progress bar appearance
	size = Vector2(50, 8)
	min_value = 0
	max_value = 1.0
	value = 1.0  # Start at full (ready to fire)
	show_percentage = false

	# Style the cooldown bar
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark background
	style_bg.border_width_left = 1
	style_bg.border_width_right = 1
	style_bg.border_width_top = 1
	style_bg.border_width_bottom = 1
	style_bg.border_color = Color(0.4, 0.4, 0.4, 1.0)

	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.2, 0.8, 0.3, 0.9)  # Green for ready

	add_theme_stylebox_override("background", style_bg)
	add_theme_stylebox_override("fill", style_fg)


func _process(_delta: float) -> void:
	if not tracked_unit or not is_instance_valid(tracked_unit):
		visible = false
		return

	# Position below the unit
	global_position = tracked_unit.global_position + Vector2(-size.x / 2, offset_y)

	# Update cooldown progress
	_update_cooldown_display()


## Update the cooldown bar based on unit's attack cooldown
func _update_cooldown_display() -> void:
	if not tracked_unit:
		return

	# Calculate cooldown progress (0.0 = just fired, 1.0 = ready to fire)
	var cooldown_progress = 0.0
	if tracked_unit.attack_cooldown > 0:
		cooldown_progress = tracked_unit.time_since_attack / tracked_unit.attack_cooldown
		cooldown_progress = clamp(cooldown_progress, 0.0, 1.0)
	else:
		cooldown_progress = 1.0  # Always ready if no cooldown

	value = cooldown_progress

	# Change color based on readiness
	var style_fg = StyleBoxFlat.new()
	if cooldown_progress >= 1.0:
		# Ready to fire - bright green
		style_fg.bg_color = Color(0.2, 0.9, 0.3, 0.9)
	elif cooldown_progress >= 0.7:
		# Almost ready - yellow-green
		style_fg.bg_color = Color(0.7, 0.9, 0.3, 0.9)
	else:
		# On cooldown - red-orange
		style_fg.bg_color = Color(0.9, 0.3, 0.2, 0.9)

	add_theme_stylebox_override("fill", style_fg)


## Set which unit to track
func set_tracked_unit(unit: UnitBase) -> void:
	tracked_unit = unit
