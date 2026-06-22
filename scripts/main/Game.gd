extends Node3D
## Placeholder gameplay scene controller.
## Spawns the player commander and each team's main base, then keeps the
## camera rig following the commander.

const COMMANDER_SCENE: PackedScene = preload("res://scenes/player/Commander.tscn")
const BASE_SCENE: PackedScene = preload("res://scenes/buildings/Base.tscn")

@onready var world_root: Node3D = $WorldRoot
@onready var units_root: Node3D = $WorldRoot/UnitsRoot
@onready var buildings_root: Node3D = $WorldRoot/BuildingsRoot
@onready var player_spawn: Marker3D = $WorldRoot/PlayerSpawn
@onready var enemy_spawn: Marker3D = $WorldRoot/EnemySpawn
@onready var camera_rig: Node3D = $CameraRig

var commander: Node3D = null


func _ready() -> void:
	_spawn_base(player_spawn.global_position, Constants.Team.PLAYER)
	_spawn_base(enemy_spawn.global_position, Constants.Team.ENEMY)
	_spawn_commander(player_spawn.global_position)
	GameState.start_match()


func _process(_delta: float) -> void:
	if commander == null:
		return
	camera_rig.global_position = Vector3(commander.global_position.x, 0.0, commander.global_position.z)


func _spawn_commander(spawn_position: Vector3) -> void:
	commander = COMMANDER_SCENE.instantiate()
	world_root.add_child(commander)
	commander.global_position = spawn_position


func _spawn_base(spawn_position: Vector3, team: int) -> void:
	var base_instance: Node3D = BASE_SCENE.instantiate()
	base_instance.team = team
	buildings_root.add_child(base_instance)
	base_instance.global_position = spawn_position
