extends Control
## Minimap showing units, buildings, and commanders as a stylized tactical
## readout: diamond building icons, a directional facing cone on each
## commander, a temporary red ring on any building recently hit
## (EventBus.building_damaged), and a gentle persistent pulse on the enemy
## HQ objective marker while the match is active. In local multiplayer each
## player's HUD embeds its own Minimap instance.

@export var world_extent: float = 60.0

# Which player this Minimap belongs to; set to ENEMY for P2 in local
# multiplayer so its input filtering and frame accent match its sibling HUD's.
@export var team: int = Constants.Team.PLAYER

@onready var frame_panel: Panel = $Frame

var _zoom_levels: Array[float] = [60.0, 40.0, 20.0]
var _zoom_index: int = 0

const _UNIT_RADIUS: float = 2.5
const _COMMANDER_RADIUS: float = 4.0
const _OUTPOST_RECT: float = 6.0
const _HQ_RECT: float = 9.0
const _REDRAW_INTERVAL: float = 1.0 / 8.0

const _BG_COLOR: Color = Color(0.055, 0.08, 0.12, 0.9)
const _CONE_LENGTH: float = 11.0
const _CONE_HALF_ANGLE: float = 0.5  # radians (~28.6 deg each side of forward)
const _UNDER_ATTACK_DURATION: float = 4.0
const _UNDER_ATTACK_RING_COLOR: Color = Color(1.0, 0.3, 0.25)
const _OBJECTIVE_PULSE_SPEED: float = 2.0
const _TICK_LENGTH: float = 14.0
const _TICK_DIRS_H: Array[float] = [1.0, -1.0, -1.0, 1.0]
const _TICK_DIRS_V: Array[float] = [1.0, 1.0, -1.0, -1.0]

var _redraw_timer: float = 0.0
var _pulse_phase: float = 0.0
var _under_attack_timers: Dictionary = {}  # building instance -> seconds remaining


func _ready() -> void:
	_zoom_index = clamp(SaveManager.minimap_size, 0, _zoom_levels.size() - 1)
	world_extent = _zoom_levels[_zoom_index]
	UIThemeFactory.apply_team_accent(frame_panel, team)
	EventBus.building_damaged.connect(_on_building_damaged)


func _process(delta: float) -> void:
	_pulse_phase += delta

	var expired: Array = []
	for building in _under_attack_timers:
		if not is_instance_valid(building):
			expired.append(building)
			continue
		_under_attack_timers[building] -= delta
		if _under_attack_timers[building] <= 0.0:
			expired.append(building)
	for building in expired:
		_under_attack_timers.erase(building)

	_redraw_timer -= delta
	if _redraw_timer <= 0.0:
		_redraw_timer = _REDRAW_INTERVAL
		queue_redraw()


func _on_building_damaged(building: Node, _amount: float, _attacker: Node) -> void:
	_under_attack_timers[building] = _UNDER_ATTACK_DURATION


func _unhandled_input(event: InputEvent) -> void:
	# Two Minimap instances exist in local multiplayer (one per player);
	# without this filter either player's zoom button would cycle both.
	# Mirrors the same filter in HUD.gd/BuildMenu.gd/CommandMenu.gd.
	if GameState.game_mode == Constants.GameMode.LOCAL_MULTIPLAYER:
		var is_joy_event: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if team == Constants.Team.PLAYER and is_joy_event:
			return
		if team == Constants.Team.ENEMY and not is_joy_event:
			return

	if Input.is_action_just_pressed(Constants.ACTION_MINIMAP_ZOOM):
		_cycle_zoom()


func _cycle_zoom() -> void:
	_zoom_index = (_zoom_index + 1) % _zoom_levels.size()
	world_extent = _zoom_levels[_zoom_index]
	SaveManager.minimap_size = _zoom_index
	SaveManager.save_settings()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _BG_COLOR, true)
	_draw_corner_ticks()

	_draw_buildings()
	_draw_camera_rect()
	_draw_units()
	_draw_commander()


func _draw_corner_ticks() -> void:
	var tick_color := Color(UIThemeFactory.team_accent(team), 0.9)
	var corners: Array[Vector2] = [
		Vector2.ZERO, Vector2(size.x, 0.0), size, Vector2(0.0, size.y)
	]
	for i in range(4):
		var c: Vector2 = corners[i]
		draw_line(c, c + Vector2(_TICK_LENGTH * _TICK_DIRS_H[i], 0.0), tick_color, 2.0)
		draw_line(c, c + Vector2(0.0, _TICK_LENGTH * _TICK_DIRS_V[i]), tick_color, 2.0)


func _draw_buildings() -> void:
	for outpost in GameState.outposts:
		if not is_instance_valid(outpost):
			continue
		var building_team: int = outpost.get("team") if outpost.get("team") != null else Constants.Team.NEUTRAL
		_draw_building_icon(outpost, IconFactory.IconType.OUTPOST, Constants.team_color(building_team), _OUTPOST_RECT)

	if GameState.player_hq != null and is_instance_valid(GameState.player_hq):
		_draw_building_icon(GameState.player_hq, IconFactory.IconType.HQ, Constants.COLOR_PLAYER, _HQ_RECT)
	if GameState.enemy_hq != null and is_instance_valid(GameState.enemy_hq):
		_draw_building_icon(GameState.enemy_hq, IconFactory.IconType.HQ, Constants.COLOR_ENEMY, _HQ_RECT, GameState.match_active)


## IconFactory HQ/Outpost icon (rather than a plain rect) with an optional
## persistent gentle pulse (the enemy HQ objective marker while the match is
## active) and a temporary red attack ring on any building recently hit.
func _draw_building_icon(building: Node, icon_type: int, color: Color, rect_size: float, is_objective: bool = false) -> void:
	var center: Vector2 = _world_to_minimap(building.global_position)
	var half: float = rect_size * 0.5

	if is_objective:
		var pulse: float = 0.5 + 0.5 * sin(_pulse_phase * _OBJECTIVE_PULSE_SPEED * TAU)
		half *= 1.0 + pulse * 0.35
		color = color.lerp(Color(1.0, 1.0, 1.0), pulse * 0.4)

	IconFactory.draw_icon(self, icon_type, Rect2(center - Vector2(half, half), Vector2(half * 2.0, half * 2.0)), color)

	if _under_attack_timers.has(building):
		var ratio: float = clamp(_under_attack_timers[building] / _UNDER_ATTACK_DURATION, 0.0, 1.0)
		var ring_pulse: float = 0.5 + 0.5 * sin(_pulse_phase * 6.0 * TAU)
		var ring_color := Color(
			_UNDER_ATTACK_RING_COLOR.r, _UNDER_ATTACK_RING_COLOR.g, _UNDER_ATTACK_RING_COLOR.b,
			ratio * (0.4 + ring_pulse * 0.6)
		)
		draw_arc(center, half + 4.0, 0.0, TAU, 16, ring_color, 2.0)


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


## Units stay plain team-colored dots rather than per-type IconFactory
## shapes: up to 60-a-side at a _UNIT_RADIUS this small, a wedge/turret/rack
## silhouette would be indistinguishable noise, not a readable icon. Color
## (ally/enemy) is the signal that actually matters at minimap scale;
## buildings and the commander get full icons/cones since there are only a
## handful of them and they're drawn bigger.
func _draw_units() -> void:
	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("is_destroyed"):
			continue
		var unit_team: int = unit.get("team") if unit.get("team") != null else Constants.Team.NEUTRAL
		var pos: Vector2 = _world_to_minimap(unit.global_position)
		draw_circle(pos, _UNIT_RADIUS, Constants.team_color(unit_team))
		draw_arc(pos, _UNIT_RADIUS, 0.0, TAU, 10, Color(0.0, 0.0, 0.0, 0.55), 1.0)


func _draw_commander() -> void:
	var commander: Node = GameState.player_commander
	if commander != null and is_instance_valid(commander):
		_draw_commander_marker(commander, Color(0.4, 0.85, 1.0))

	var enemy_cmd: Node = GameState.enemy_commander
	if enemy_cmd != null and is_instance_valid(enemy_cmd):
		_draw_commander_marker(enemy_cmd, Constants.COLOR_ENEMY)


## Solid circle at the commander's position plus a translucent facing cone
## derived from its actual world-space forward vector, so the cone always
## agrees with which way the commander will move/fire/aim.
func _draw_commander_marker(commander: Node, color: Color) -> void:
	var center: Vector2 = _world_to_minimap(commander.global_position)
	var forward_3d: Vector3 = -commander.global_transform.basis.z
	var forward_2d: Vector2 = Vector2(forward_3d.x, forward_3d.z)
	if forward_2d.length_squared() > 0.0001:
		forward_2d = forward_2d.normalized()
		var left: Vector2 = center + forward_2d.rotated(_CONE_HALF_ANGLE) * _CONE_LENGTH
		var right: Vector2 = center + forward_2d.rotated(-_CONE_HALF_ANGLE) * _CONE_LENGTH
		draw_colored_polygon(PackedVector2Array([center, left, right]), Color(color.r, color.g, color.b, 0.3))

	draw_circle(center, _COMMANDER_RADIUS, color)
	draw_arc(center, _COMMANDER_RADIUS, 0.0, TAU, 12, Color(1.0, 1.0, 1.0, 0.6), 1.0)


func _world_to_minimap(world_pos: Vector3) -> Vector2:
	var normalized: Vector2 = Vector2(world_pos.x, world_pos.z) / world_extent
	return (normalized * 0.5 + Vector2(0.5, 0.5)) * size
