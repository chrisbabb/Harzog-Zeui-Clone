extends Node3D
## Split-screen local multiplayer controller.
## Builds the viewport split dynamically (vertical = left|right, horizontal =
## top|bottom based on GameState.split_direction), spawns two human Commanders
## (P1 keyboard/mouse, P2 controller), and drives respawn without an EnemyAI.

const COMMANDER_SCENE: PackedScene = preload("res://scenes/player/Commander.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const COMMANDER_SPAWN_OFFSET: Vector3 = Vector3(8.0, 0.0, 0.0)
const COMMANDER_RESPAWN_TIME: float = 15.0
const CAMERA_OFFSET: Vector3 = Vector3(10.61, 25.98, 10.61)
const CAMERA_ROTATION_DEG: Vector3 = Vector3(-60.0, 45.0, 0.0)
const CAMERA_SIZE: float = 42.0
const SHAKE_DECAY_PER_SEC: float = 6.0

@onready var world_root: Node3D = $WorldRoot

var _p1_commander: Node = null
var _p2_commander: Node = null
var _p1_camera_rig: Node3D = null
var _p2_camera_rig: Node3D = null
var _p1_follow: Vector3 = Vector3.ZERO
var _p2_follow: Vector3 = Vector3.ZERO
var _p1_shake: float = 0.0
var _p2_shake: float = 0.0
var _p1_respawn_timer: float = 0.0
var _p2_respawn_timer: float = 0.0


func _ready() -> void:
	Engine.time_scale = Constants.MATCH_SPEED_MULTIPLIERS.get(GameState.selected_match_speed, 1.0)
	EventBus.commander_died.connect(_on_commander_died)
	EventBus.camera_shake_requested.connect(_on_camera_shake_requested)

	_build_split_viewports()
	MapGenerator.generate_battlefield(self)
	_spawn_p1_commander()
	_spawn_p2_commander()
	_p1_follow = _clamp_to_arena(_p1_commander.global_position)
	_p2_follow = _clamp_to_arena(_p2_commander.global_position)
	_p1_camera_rig.global_position = _p1_follow
	_p2_camera_rig.global_position = _p2_follow
	GameState.start_match()


func _process(delta: float) -> void:
	if is_instance_valid(_p1_commander):
		var t: Vector3 = _clamp_to_arena(_p1_commander.global_position)
		_p1_follow = _p1_follow.lerp(t, clamp(delta * Constants.CAMERA_FOLLOW_SPEED, 0.0, 1.0))
	_p1_shake = max(0.0, _p1_shake - SHAKE_DECAY_PER_SEC * delta)
	var s1: Vector3 = Vector3.ZERO
	if _p1_shake > 0.0:
		s1 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * _p1_shake
	_p1_camera_rig.global_position = _p1_follow + s1

	if is_instance_valid(_p2_commander):
		var t: Vector3 = _clamp_to_arena(_p2_commander.global_position)
		_p2_follow = _p2_follow.lerp(t, clamp(delta * Constants.CAMERA_FOLLOW_SPEED, 0.0, 1.0))
	_p2_shake = max(0.0, _p2_shake - SHAKE_DECAY_PER_SEC * delta)
	var s2: Vector3 = Vector3.ZERO
	if _p2_shake > 0.0:
		s2 = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * _p2_shake
	_p2_camera_rig.global_position = _p2_follow + s2

	_tick_respawn(delta)


func _tick_respawn(delta: float) -> void:
	if _p1_respawn_timer > 0.0:
		_p1_respawn_timer -= delta
		if _p1_respawn_timer <= 0.0 and GameState.match_active:
			if GameState.player_hq != null and is_instance_valid(GameState.player_hq):
				_spawn_p1_commander()

	if _p2_respawn_timer > 0.0:
		_p2_respawn_timer -= delta
		if _p2_respawn_timer <= 0.0 and GameState.match_active:
			if GameState.enemy_hq != null and is_instance_valid(GameState.enemy_hq):
				_spawn_p2_commander()


func _on_commander_died(dead_commander: Node) -> void:
	if dead_commander == _p1_commander:
		_p1_commander = null
		_p1_respawn_timer = COMMANDER_RESPAWN_TIME
	elif dead_commander == _p2_commander:
		_p2_commander = null
		_p2_respawn_timer = COMMANDER_RESPAWN_TIME


func _spawn_p1_commander() -> void:
	_p1_commander = COMMANDER_SCENE.instantiate()
	_p1_commander.set("team", Constants.Team.PLAYER)
	_p1_commander.set("player_index", 0)
	world_root.add_child(_p1_commander)
	_p1_commander.global_position = GameState.player_hq.global_position + COMMANDER_SPAWN_OFFSET
	GameState.player_commander = _p1_commander


func _spawn_p2_commander() -> void:
	_p2_commander = COMMANDER_SCENE.instantiate()
	_p2_commander.set("team", Constants.Team.ENEMY)
	_p2_commander.set("player_index", 1)
	world_root.add_child(_p2_commander)
	_p2_commander.global_position = GameState.enemy_hq.global_position - COMMANDER_SPAWN_OFFSET
	GameState.enemy_commander = _p2_commander


func _build_split_viewports() -> void:
	var is_horizontal: bool = GameState.split_direction == Constants.SplitDirection.HORIZONTAL
	var split_container: BoxContainer
	if is_horizontal:
		split_container = VBoxContainer.new()
	else:
		split_container = HBoxContainer.new()
	split_container.name = "ViewportSplit"
	split_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(split_container)

	_p1_camera_rig = _add_viewport_half(split_container, Constants.Team.PLAYER)
	_p2_camera_rig = _add_viewport_half(split_container, Constants.Team.ENEMY)


func _add_viewport_half(parent: BoxContainer, team: int) -> Node3D:
	var vp_container := SubViewportContainer.new()
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_container.stretch = true
	parent.add_child(vp_container)

	var viewport := SubViewport.new()
	vp_container.add_child(viewport)

	var camera_rig := Node3D.new()
	camera_rig.name = "P%dCameraRig" % (1 if team == Constants.Team.PLAYER else 2)
	viewport.add_child(camera_rig)

	var camera := Camera3D.new()
	camera.position = CAMERA_OFFSET
	camera.rotation_degrees = CAMERA_ROTATION_DEG
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera_rig.add_child(camera)
	camera.make_current()

	var hud: Node = HUD_SCENE.instantiate()
	hud.set("team", team)
	if team == Constants.Team.ENEMY:
		# BuildMenu/CommandMenu/PauseMenu/Minimap all filter input by device
		# (keyboard vs. joypad) once their team matches this HUD's -- see the
		# matching filter in HUD.gd's own _unhandled_input.
		for child_name in ["BuildMenu", "CommandMenu", "PauseMenu", "Minimap"]:
			var child: Node = hud.get_node_or_null(child_name)
			if child:
				child.set("team", team)
	viewport.add_child(hud)

	return camera_rig


func _clamp_to_arena(world_position: Vector3) -> Vector3:
	var half_length: float = Constants.ARENA_LENGTH * 0.5 - Constants.CAMERA_CLAMP_MARGIN.x
	var half_width: float = Constants.ARENA_WIDTH * 0.5 - Constants.CAMERA_CLAMP_MARGIN.y
	return Vector3(
		clamp(world_position.x, -half_length, half_length),
		0.0,
		clamp(world_position.z, -half_width, half_width)
	)


func _on_camera_shake_requested(strength: float) -> void:
	if SaveManager.camera_shake:
		_p1_shake = max(_p1_shake, strength)
		_p2_shake = max(_p2_shake, strength)
