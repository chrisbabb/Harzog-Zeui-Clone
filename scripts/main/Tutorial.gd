extends Node3D
## Gameplay scene controller for the interactive tutorial. Builds a small,
## fixed practice battlefield (one player HQ, one neutral outpost, one inert
## target dummy -- no enemy HQ, no enemy commander, no EnemyAI node at all,
## which is what "disables" enemy AI for the tutorial), spawns the player
## commander, and exposes a single reusable highlight marker that
## TutorialOverlay.gd points at whatever the player should interact with next.

const COMMANDER_SCENE: PackedScene = preload("res://scenes/player/Commander.tscn")
const COMMANDER_SPAWN_OFFSET: Vector3 = Vector3(8.0, 0.0, 0.0)

const HQ_POSITION: Vector3 = Vector3(-70.0, 0.0, 0.0)
const OUTPOST_POSITION: Vector3 = Vector3(-10.0, 0.0, 0.0)
const DUMMY_POSITION: Vector3 = Vector3(55.0, 0.0, 0.0)

const SHAKE_DECAY_PER_SEC: float = 6.0

const HIGHLIGHT_HEIGHT: float = 4.0
const HIGHLIGHT_BOB_SPEED: float = 2.5
const HIGHLIGHT_BOB_HEIGHT: float = 0.4
const HIGHLIGHT_SPIN_SPEED: float = 2.0
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.85, 0.2)

@onready var world_root: Node3D = $WorldRoot
@onready var camera_rig: Node3D = $CameraRig

var commander: Node3D = null
var target_dummy: Node3D = null

var _follow_position: Vector3 = Vector3.ZERO
var _shake_strength: float = 0.0

var _highlight_marker: Node3D = null
var _highlight_base_position: Vector3 = Vector3.ZERO
var _highlight_time: float = 0.0


func _ready() -> void:
	Engine.time_scale = 1.0
	GameState.reset_match_state()
	GameState.selected_starting_credits = Constants.STARTING_MONEY
	Economy.reset()
	EventBus.camera_shake_requested.connect(_on_camera_shake_requested)

	_build_battlefield()
	_spawn_commander()
	_build_highlight_marker()

	_follow_position = _clamp_to_arena(commander.global_position)
	camera_rig.global_position = _follow_position


func _process(delta: float) -> void:
	if not is_instance_valid(commander):
		commander = null
	if commander != null:
		var target: Vector3 = _clamp_to_arena(commander.global_position)
		var follow_factor: float = clamp(delta * Constants.CAMERA_FOLLOW_SPEED, 0.0, 1.0)
		_follow_position = _follow_position.lerp(target, follow_factor)
	camera_rig.global_position = _follow_position + _shake_offset(delta)

	_update_highlight(delta)


# ---------------------------------------------------------------------------
# Battlefield setup
# ---------------------------------------------------------------------------

func _build_battlefield() -> void:
	var buildings_root: Node3D = world_root.get_node("BuildingsRoot")
	buildings_root.add_child(MapGenerator.create_hq(Constants.Team.PLAYER, HQ_POSITION))
	buildings_root.add_child(MapGenerator.create_outpost(OUTPOST_POSITION))

	target_dummy = TutorialTargetDummy.new()
	world_root.add_child(target_dummy)
	target_dummy.global_position = DUMMY_POSITION

	NavigationManager.rebake_navigation(self)


func _spawn_commander() -> void:
	commander = COMMANDER_SCENE.instantiate()
	world_root.add_child(commander)
	commander.global_position = GameState.player_hq.global_position + COMMANDER_SPAWN_OFFSET
	GameState.player_commander = commander


# ---------------------------------------------------------------------------
# Camera follow/shake (mirrors Game.gd)
# ---------------------------------------------------------------------------

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
		_shake_strength = max(_shake_strength, strength)


func _shake_offset(delta: float) -> Vector3:
	if _shake_strength <= 0.0:
		return Vector3.ZERO
	_shake_strength = max(0.0, _shake_strength - SHAKE_DECAY_PER_SEC * delta)
	return Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * _shake_strength


# ---------------------------------------------------------------------------
# Highlight marker -- TutorialOverlay.gd calls set_highlight_target()/
# clear_highlight() once per step entry via the duck-typed
# get_tree().current_scene.call(...) convention used elsewhere in the
# codebase for scene-specific behavior that doesn't belong on an autoload.
# ---------------------------------------------------------------------------

func _build_highlight_marker() -> void:
	_highlight_marker = Node3D.new()
	_highlight_marker.name = "HighlightMarker"

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.albedo_color = HIGHLIGHT_COLOR
	material.emission = HIGHLIGHT_COLOR

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.8
	mesh.height = 1.6
	mesh.material = material

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	_highlight_marker.add_child(mesh_instance)

	_highlight_marker.visible = false
	world_root.add_child(_highlight_marker)


func set_highlight_target(world_position: Vector3) -> void:
	_highlight_base_position = world_position + Vector3(0.0, HIGHLIGHT_HEIGHT, 0.0)
	_highlight_marker.position = _highlight_base_position
	_highlight_marker.visible = true


func clear_highlight() -> void:
	_highlight_marker.visible = false


func _update_highlight(delta: float) -> void:
	if not _highlight_marker.visible:
		return
	_highlight_time += delta
	var bob: float = sin(_highlight_time * HIGHLIGHT_BOB_SPEED) * HIGHLIGHT_BOB_HEIGHT
	_highlight_marker.position = _highlight_base_position + Vector3(0.0, bob, 0.0)
	_highlight_marker.rotate_y(HIGHLIGHT_SPIN_SPEED * delta)
