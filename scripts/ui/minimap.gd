extends Control
class_name Minimap
## Minimap - Shows a scaled-down view of the entire game world
##
## Features:
## - Displays all units and buildings
## - Shows player camera view area
## - Color-coded by team
## - Updates in real-time

# Minimap size
@export var minimap_width: float = 200.0
@export var minimap_height: float = 150.0

# World size (set by game world)
var world_width: float = 4000.0
var world_height: float = 3000.0

# Scale factors
var scale_x: float = 1.0
var scale_y: float = 1.0

# References
var game_world: Node = null

# Colors
const BACKGROUND_COLOR = Color(0.1, 0.1, 0.1, 0.8)
const BORDER_COLOR = Color(0.4, 0.4, 0.4, 1.0)
const VIEW_RECT_COLOR = Color(1.0, 1.0, 1.0, 0.3)


func _ready() -> void:
	# Set minimap size
	custom_minimum_size = Vector2(minimap_width, minimap_height)
	size = Vector2(minimap_width, minimap_height)

	# Position in top-right corner with some padding
	position = Vector2(get_viewport_rect().size.x - minimap_width - 20, 20)

	# Calculate scale factors
	_update_scale()

	# Ensure we redraw each frame
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR, true)

	# Draw border
	draw_rect(Rect2(Vector2.ZERO, size), BORDER_COLOR, false, 2.0)

	if not game_world:
		return

	# Draw all units
	_draw_units()

	# Draw all buildings
	_draw_buildings()

	# Draw player camera view (if applicable)
	_draw_camera_view()


## Draw all units on minimap
func _draw_units() -> void:
	var units_node = game_world.get_node_or_null("Units")
	if not units_node:
		return

	for unit in units_node.get_children():
		if unit.has_method("is_dead") and unit.is_dead():
			continue

		var world_pos = unit.global_position
		var minimap_pos = _world_to_minimap(world_pos)
		var color = _get_unit_color(unit)

		# Draw unit as a small circle
		draw_circle(minimap_pos, 2.0, color)


## Draw all buildings on minimap
func _draw_buildings() -> void:
	var buildings_node = game_world.get_node_or_null("Buildings")
	if not buildings_node:
		return

	for building in buildings_node.get_children():
		if building.has_method("is_dead") and building.is_dead():
			continue

		var world_pos = building.global_position
		var minimap_pos = _world_to_minimap(world_pos)
		var color = _get_unit_color(building)

		# Draw building as a small square
		var rect_size = 4.0
		draw_rect(Rect2(minimap_pos - Vector2(rect_size/2, rect_size/2), Vector2(rect_size, rect_size)), color, true)


## Draw player camera view area
func _draw_camera_view() -> void:
	# Get the first active player's camera (for now)
	if not game_world.has_method("get_player_cameras"):
		return

	var cameras = game_world.player_cameras
	if cameras.is_empty():
		return

	var camera = cameras[0]
	if not camera:
		return

	# Get camera viewport size
	var viewport_size = get_viewport_rect().size
	var camera_pos = camera.global_position

	# For split screen, adjust viewport size
	# Assuming vertical split for 2 players
	if cameras.size() == 2:
		viewport_size.y /= 2
	elif cameras.size() >= 3:
		viewport_size /= 2

	# Calculate view rectangle in world coordinates
	var view_half_size = viewport_size / 2
	var view_top_left = camera_pos - view_half_size
	var view_bottom_right = camera_pos + view_half_size

	# Convert to minimap coordinates
	var minimap_top_left = _world_to_minimap(view_top_left)
	var minimap_bottom_right = _world_to_minimap(view_bottom_right)
	var minimap_rect_size = minimap_bottom_right - minimap_top_left

	# Draw view rectangle
	draw_rect(Rect2(minimap_top_left, minimap_rect_size), VIEW_RECT_COLOR, false, 1.5)


## Convert world position to minimap position
func _world_to_minimap(world_pos: Vector2) -> Vector2:
	var x = (world_pos.x / world_width) * minimap_width
	var y = (world_pos.y / world_height) * minimap_height
	return Vector2(x, y)


## Get color for a unit based on team
func _get_unit_color(entity) -> Color:
	if not "team_color" in entity:
		return Color.WHITE

	match entity.team_color:
		"Red":
			return Color(1.0, 0.2, 0.2, 1.0)
		"Blue":
			return Color(0.2, 0.5, 1.0, 1.0)
		"Green":
			return Color(0.2, 1.0, 0.2, 1.0)
		"Yellow":
			return Color(1.0, 1.0, 0.2, 1.0)
		_:
			return Color.WHITE


## Update scale factors when world size changes
func _update_scale() -> void:
	scale_x = minimap_width / world_width
	scale_y = minimap_height / world_height


## Set world size
func set_world_size(width: float, height: float) -> void:
	world_width = width
	world_height = height
	_update_scale()


## Set reference to game world
func set_game_world(world: Node) -> void:
	game_world = world
