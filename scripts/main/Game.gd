extends Node3D
## Gameplay scene controller.
## Generates the battlefield, spawns the player commander, and keeps the
## camera rig smoothly following the commander within the arena bounds.
## Match end-on-HQ-destruction and continuous income are already wired
## through Base.gd/GameState/Economy; this script only needs to kick the
## match off and drive the camera.

const COMMANDER_SCENE: PackedScene = preload("res://scenes/player/Commander.tscn")
const COMMANDER_SPAWN_OFFSET: Vector3 = Vector3(8.0, 0.0, 0.0)

@onready var world_root: Node3D = $WorldRoot
@onready var camera_rig: Node3D = $CameraRig

var commander: Node3D = null


func _ready() -> void:
	MapGenerator.generate_battlefield(self)
	_spawn_commander()
	camera_rig.global_position = _clamp_to_arena(commander.global_position)
	GameState.start_match()


func _process(delta: float) -> void:
	if commander == null:
		return
	var target: Vector3 = _clamp_to_arena(commander.global_position)
	var follow_factor: float = clamp(delta * Constants.CAMERA_FOLLOW_SPEED, 0.0, 1.0)
	camera_rig.global_position = camera_rig.global_position.lerp(target, follow_factor)


func _spawn_commander() -> void:
	commander = COMMANDER_SCENE.instantiate()
	world_root.add_child(commander)
	commander.global_position = GameState.player_hq.global_position + COMMANDER_SPAWN_OFFSET
	GameState.player_commander = commander


func _clamp_to_arena(world_position: Vector3) -> Vector3:
	var half_length: float = Constants.ARENA_LENGTH * 0.5 - Constants.CAMERA_CLAMP_MARGIN.x
	var half_width: float = Constants.ARENA_WIDTH * 0.5 - Constants.CAMERA_CLAMP_MARGIN.y
	return Vector3(
		clamp(world_position.x, -half_length, half_length),
		0.0,
		clamp(world_position.z, -half_width, half_width)
	)
