extends StaticBody2D
class_name MiniBase
## MiniBase - Small capturable base that can be controlled by peons
##
## Features:
## - Neutral by default
## - Can be captured by peons
## - Provides strategic value

# Ownership
var owner_slot: int = -1  # -1 means neutral
var team_color: String = "Neutral"
var is_neutral: bool = true

# Capture system
var capture_progress: float = 0.0
var capture_time: float = 3.0  # Seconds to capture
var capturing_unit = null

# Visual
var visual_rect: ColorRect = null


func _ready() -> void:
	add_to_group("mini_bases")
	add_to_group("buildings")
	_create_visual()


func _process(delta: float) -> void:
	# Handle capture progress
	if capturing_unit and is_instance_valid(capturing_unit):
		# Check if capturing unit is still nearby
		var dist_sq = (capturing_unit.global_position - global_position).length_squared()
		if dist_sq <= 100.0 * 100.0:  # Within 100 units
			capture_progress += delta
			if capture_progress >= capture_time:
				_complete_capture()
		else:
			# Unit moved away, reset capture
			capturing_unit = null
			capture_progress = 0.0
	else:
		# No one capturing, slowly decay progress
		if capture_progress > 0:
			capture_progress -= delta * 0.5
			if capture_progress < 0:
				capture_progress = 0


## Create visual representation
func _create_visual() -> void:
	# Create base square
	visual_rect = ColorRect.new()
	visual_rect.size = Vector2(60, 60)
	visual_rect.position = Vector2(-30, -30)
	visual_rect.color = Color(0.5, 0.5, 0.5, 1.0)  # Gray for neutral
	add_child(visual_rect)

	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(60, 60)
	collision.shape = shape
	add_child(collision)

	# Add label
	var label = Label.new()
	label.text = "Mini Base"
	label.position = Vector2(-25, -50)
	label.add_theme_font_size_override("font_size", 10)
	add_child(label)


## Attempt to start capturing this base
func try_capture(unit) -> bool:
	# Only peons can capture
	if not "unit_type" in unit or unit.unit_type != "peon":
		return false

	# Check if it's an enemy or neutral base
	if not is_neutral and "team_color" in unit and unit.team_color == team_color:
		return false  # Already owned by this team

	# Start capturing
	capturing_unit = unit
	capture_progress = 0.0
	return true


## Complete the capture
func _complete_capture() -> void:
	if not capturing_unit or not is_instance_valid(capturing_unit):
		return

	# Get new owner from capturing unit
	if "owner_slot" in capturing_unit and "team_color" in capturing_unit:
		owner_slot = capturing_unit.owner_slot
		team_color = capturing_unit.team_color
		is_neutral = false

		# Update visual
		_update_visual()

		print("Mini base captured by Player %d (%s)!" % [owner_slot, team_color])

	# Reset capture state
	capturing_unit = null
	capture_progress = 0.0


## Update visual based on ownership
func _update_visual() -> void:
	if not visual_rect:
		return

	if is_neutral:
		visual_rect.color = Color(0.5, 0.5, 0.5, 1.0)  # Gray
	else:
		match team_color:
			"Red":
				visual_rect.color = Color(1.0, 0.3, 0.3, 1.0)
			"Blue":
				visual_rect.color = Color(0.3, 0.5, 1.0, 1.0)
			"Green":
				visual_rect.color = Color(0.3, 1.0, 0.3, 1.0)
			"Yellow":
				visual_rect.color = Color(1.0, 1.0, 0.3, 1.0)
			_:
				visual_rect.color = Color(0.5, 0.5, 0.5, 1.0)


## Set initial ownership (for testing)
func set_owner_info(slot: int, color: String) -> void:
	owner_slot = slot
	team_color = color
	is_neutral = false
	_update_visual()
