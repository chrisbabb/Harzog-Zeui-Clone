class_name MapGenerator
extends RefCounted
## Stateless battlefield layout generator.
## Builds both HQs, the neutral outposts, and a debug grid overlay for the
## match. Called once from the gameplay scene's _ready().

const HQ_SCENE: PackedScene = preload("res://scenes/buildings/Base.tscn")
const OUTPOST_SCENE: PackedScene = preload("res://scenes/buildings/Outpost.tscn")

const PLAYER_HQ_POSITION: Vector3 = Vector3(-90.0, 0.0, 0.0)
const ENEMY_HQ_POSITION: Vector3 = Vector3(90.0, 0.0, 0.0)

## Hand-placed rather than mirrored, so neither side reads as a perfect
## reflection of the other: 3 near player, 3 middle, 3 near enemy.
const OUTPOST_POSITIONS: Array[Vector3] = [
	Vector3(-55.0, 0.0, -32.0),
	Vector3(-50.0, 0.0, 4.0),
	Vector3(-60.0, 0.0, 28.0),
	Vector3(-9.0, 0.0, -35.0),
	Vector3(6.0, 0.0, 3.0),
	Vector3(10.0, 0.0, 32.0),
	Vector3(52.0, 0.0, -29.0),
	Vector3(58.0, 0.0, 6.0),
	Vector3(48.0, 0.0, 34.0),
]

const GRID_STEP: float = 20.0
const GRID_HEIGHT: float = 0.06
const GRID_COLOR: Color = Color(0.35, 0.45, 0.38)


static func generate_battlefield(game_root: Node3D) -> void:
	var buildings_root: Node3D = game_root.get_node("WorldRoot/BuildingsRoot")
	var effects_root: Node3D = game_root.get_node("WorldRoot/EffectsRoot")

	buildings_root.add_child(create_hq(Constants.Team.PLAYER, PLAYER_HQ_POSITION))
	buildings_root.add_child(create_hq(Constants.Team.ENEMY, ENEMY_HQ_POSITION))

	for outpost_position in OUTPOST_POSITIONS:
		buildings_root.add_child(create_outpost(outpost_position))

	effects_root.add_child(_build_grid_overlay())


static func create_hq(team: int, position: Vector3) -> Node3D:
	var hq: Node3D = HQ_SCENE.instantiate()
	hq.setup(team, position)
	return hq


static func create_outpost(position: Vector3) -> Node3D:
	var outpost: Node3D = OUTPOST_SCENE.instantiate()
	outpost.position = position
	return outpost


static func _build_grid_overlay() -> MeshInstance3D:
	var half_length: float = Constants.ARENA_LENGTH * 0.5
	var half_width: float = Constants.ARENA_WIDTH * 0.5

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = GRID_COLOR

	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

	var x: float = -half_length
	while x <= half_length:
		immediate_mesh.surface_add_vertex(Vector3(x, GRID_HEIGHT, -half_width))
		immediate_mesh.surface_add_vertex(Vector3(x, GRID_HEIGHT, half_width))
		x += GRID_STEP

	var z: float = -half_width
	while z <= half_width:
		immediate_mesh.surface_add_vertex(Vector3(-half_length, GRID_HEIGHT, z))
		immediate_mesh.surface_add_vertex(Vector3(half_length, GRID_HEIGHT, z))
		z += GRID_STEP

	immediate_mesh.surface_end()

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GridOverlay"
	mesh_instance.mesh = immediate_mesh
	return mesh_instance
