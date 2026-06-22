extends Control
## Placeholder minimap. Draws simple dots for registered units/buildings
## projected from world XZ coordinates onto the minimap rect.

@export var world_extent: float = 60.0

var _zoom_levels: Array[float] = [60.0, 40.0, 20.0]
var _zoom_index: int = 0


func _ready() -> void:
	world_extent = _zoom_levels[_zoom_index]


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(Constants.ACTION_MINIMAP_ZOOM):
		_cycle_zoom()


func _cycle_zoom() -> void:
	_zoom_index = (_zoom_index + 1) % _zoom_levels.size()
	world_extent = _zoom_levels[_zoom_index]


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.05), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.6, 0.4), false, 2.0)

	for unit in GameState.registered_units:
		if not is_instance_valid(unit):
			continue
		_draw_world_dot(unit.global_position, _team_color(unit.get("team")))

	for building in GameState.registered_buildings:
		if not is_instance_valid(building):
			continue
		_draw_world_dot(building.global_position, _team_color(building.get("team")), 5.0)


func _draw_world_dot(world_position: Vector3, color: Color, radius: float = 3.0) -> void:
	var normalized := Vector2(world_position.x, world_position.z) / world_extent
	var point := (normalized * 0.5 + Vector2(0.5, 0.5)) * size
	draw_circle(point, radius, color)


func _team_color(team) -> Color:
	if team == Constants.Team.PLAYER:
		return Color(0.3, 0.6, 1.0)
	elif team == Constants.Team.ENEMY:
		return Color(1.0, 0.3, 0.3)
	return Color(0.8, 0.8, 0.3)
