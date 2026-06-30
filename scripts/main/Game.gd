extends Node3D
## Gameplay scene controller.
## Spawns both commanders, starts the match, and keeps the camera rig smoothly
## following the player commander within the arena bounds.
## Handles 15-second respawn for whichever commander dies, unless that
## team's HQ is already destroyed (in which case the match is already over).

const COMMANDER_SCENE: PackedScene = preload("res://scenes/player/Commander.tscn")
const ENEMY_COMMANDER_SCENE: PackedScene = preload("res://scenes/player/EnemyCommander.tscn")
const COMMANDER_SPAWN_OFFSET: Vector3 = Vector3(8.0, 0.0, 0.0)
const COMMANDER_RESPAWN_TIME: float = 15.0

@onready var world_root: Node3D = $WorldRoot
@onready var camera_rig: Node3D = $CameraRig

var commander: Node3D = null
var _player_respawn_timer: float = 0.0
var _enemy_respawn_timer: float = 0.0


func _ready() -> void:
	EventBus.commander_died.connect(_on_commander_died)
	MapGenerator.generate_battlefield(self)
	_spawn_commander()
	_spawn_enemy_commander()
	camera_rig.global_position = _clamp_to_arena(commander.global_position)
	GameState.start_match()


func _process(delta: float) -> void:
	if not is_instance_valid(commander):
		commander = null
	if commander != null:
		var target: Vector3 = _clamp_to_arena(commander.global_position)
		var follow_factor: float = clamp(delta * Constants.CAMERA_FOLLOW_SPEED, 0.0, 1.0)
		camera_rig.global_position = camera_rig.global_position.lerp(target, follow_factor)

	if _player_respawn_timer > 0.0:
		_player_respawn_timer -= delta
		if _player_respawn_timer <= 0.0 and GameState.match_active:
			if GameState.player_hq != null and is_instance_valid(GameState.player_hq):
				_spawn_commander()

	if _enemy_respawn_timer > 0.0:
		_enemy_respawn_timer -= delta
		if _enemy_respawn_timer <= 0.0 and GameState.match_active:
			if GameState.enemy_hq != null and is_instance_valid(GameState.enemy_hq):
				_spawn_enemy_commander()


func _on_commander_died(dead_commander: Node) -> void:
	if dead_commander.get("team") == Constants.Team.PLAYER:
		commander = null
		_player_respawn_timer = COMMANDER_RESPAWN_TIME
	else:
		_enemy_respawn_timer = COMMANDER_RESPAWN_TIME


func _spawn_commander() -> void:
	commander = COMMANDER_SCENE.instantiate()
	world_root.add_child(commander)
	commander.global_position = GameState.player_hq.global_position + COMMANDER_SPAWN_OFFSET
	GameState.player_commander = commander


func _spawn_enemy_commander() -> void:
	var enemy_commander: Node3D = ENEMY_COMMANDER_SCENE.instantiate()
	world_root.add_child(enemy_commander)
	enemy_commander.global_position = GameState.enemy_hq.global_position - COMMANDER_SPAWN_OFFSET
	GameState.enemy_commander = enemy_commander


func _clamp_to_arena(world_position: Vector3) -> Vector3:
	var half_length: float = Constants.ARENA_LENGTH * 0.5 - Constants.CAMERA_CLAMP_MARGIN.x
	var half_width: float = Constants.ARENA_WIDTH * 0.5 - Constants.CAMERA_CLAMP_MARGIN.y
	return Vector3(
		clamp(world_position.x, -half_length, half_length),
		0.0,
		clamp(world_position.z, -half_width, half_width)
	)
