extends Control
## Minimap showing units, buildings, commander, and camera viewport rectangle.

@export var world_extent: float = 60.0

var _zoom_levels: Array[float] = [60.0, 40.0, 20.0]
var _zoom_index: int = 0

const _UNIT_RADIUS: float = 2.5
const _COMMANDER_RADIUS: float = 4.0
const _OUTPOST_RECT: float = 6.0
const _HQ_RECT: float = 9.0


func _ready() -> void:
	_zoom_index = clamp(SaveManager.minimap_size, 0, _zoom_levels.size() - 1)
	world_extent = _zoom_levels[_zoom_index]


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(Constants.ACTION_MINIMAP_ZOOM):
		_cycle_zoom()


func _cycle_zoom() -> void:
	_zoom_index = (_zoom_index + 1) % _zoom_levels.size()
	world_extent = _zoom_levels[_zoom_index]
	SaveManager.minimap_size = _zoom_index
	SaveManager.save_settings()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.05), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.4, 0.6, 0.4), false, 2.0)

	_draw_buildings()
	_draw_camera_rect()
	_draw_units()
	_draw_commander()


func _draw_buildings() -> void:
	for outpost in GameState.outposts:
		if not is_instance_valid(outpost):
			continue
		var team: int = outpost.get("team") if outpost.get("team") != null else Constants.Team.NEUTRAL
		_draw_world_rect(outpost.global_position, Constants.team_color(team), _OUTPOST_RECT)

	if GameState.player_hq != null and is_instance_valid(GameState.player_hq):
		_draw_world_rect(GameState.player_hq.global_position, Constants.COLOR_PLAYER, _HQ_RECT)
	if GameState.enemy_hq != null and is_instance_valid(GameState.enemy_hq):
		_draw_world_rect(GameState.enemy_hq.global_position, Constants.COLOR_ENEMY, _HQ_RECT)


func _draw_camera_rect() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var screen_corners: Array[Vector2] = [
		Vector2(0.0, 0.0),
		Vector2(vp_size.x, 0.0),
		Vector2(vp_size.x, vp_size.y),
		Vector2(0.0, vp_size.y),
	]

	var minimap_corners: PackedVector2Array = PackedVector2Array()
	for sc in screen_corners:
		var origin: Vector3 = camera.project_ray_origin(sc)
		var direction: Vector3 = camera.project_ray_normal(sc)
		if abs(direction.y) < 0.001:
			return
		var t: float = -origin.y / direction.y
		if t < 0.0:
			return
		minimap_corners.append(_world_to_minimap(origin + direction * t))

	for i in range(minimap_corners.size()):
		draw_line(
			minimap_corners[i],
			minimap_corners[(i + 1) % minimap_corners.size()],
			Color(0.9, 0.9, 0.9, 0.7),
			1.0
		)


func _draw_units() -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("is_destroyed"):
			continue
		var team: int = unit.get("team") if unit.get("team") != null else Constants.Team.NEUTRAL
		draw_circle(_world_to_minimap(unit.global_position), _UNIT_RADIUS, Constants.team_color(team))


func _draw_commander() -> void:
	var commander: Node = GameState.player_commander
	if commander != null and is_instance_valid(commander):
		draw_circle(_world_to_minimap(commander.global_position), _COMMANDER_RADIUS, Color(0.4, 0.85, 1.0))

	var enemy_cmd: Node = GameState.enemy_commander
	if enemy_cmd != null and is_instance_valid(enemy_cmd):
		draw_circle(_world_to_minimap(enemy_cmd.global_position), _COMMANDER_RADIUS, Constants.COLOR_ENEMY)


func _world_to_minimap(world_pos: Vector3) -> Vector2:
	var normalized: Vector2 = Vector2(world_pos.x, world_pos.z) / world_extent
	return (normalized * 0.5 + Vector2(0.5, 0.5)) * size


func _draw_world_rect(world_pos: Vector3, color: Color, rect_size: float) -> void:
	var center: Vector2 = _world_to_minimap(world_pos)
	var half: float = rect_size * 0.5
	draw_rect(Rect2(center - Vector2(half, half), Vector2(rect_size, rect_size)), color, true)
