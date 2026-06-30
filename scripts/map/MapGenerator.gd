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

## A handful of low ridges/rocks scattered in the open lanes between
## buildings -- physical blockers only (not carved into the navmesh), so
## ground units/the grounded commander collide and slide around them via
## move_and_slide() while the airborne commander (collision_mask = 0) flies
## straight over. Kept sparse and well clear of HQs/outposts so pathfinding
## never has to route around a maze, just nudge around a few rocks.
const OBSTACLE_POSITIONS: Array[Vector3] = [
	Vector3(-30.0, 0.0, -18.0),
	Vector3(-20.0, 0.0, 22.0),
	Vector3(25.0, 0.0, -20.0),
	Vector3(32.0, 0.0, 18.0),
	Vector3(0.0, 0.0, -12.0),
]
const OBSTACLE_RADIUS: float = 4.0
const OBSTACLE_HEIGHT: float = 2.2
const OBSTACLE_COLOR: Color = Color(0.42, 0.38, 0.34)

## Flat decorative terrain zones, drawn as thin slabs flush with the ground
## (Ground's top surface sits at world Y=0; see Game.tscn). Purely visual --
## none of this is carved into the navmesh, so it doesn't affect pathfinding.
const ZONE_COLS: int = 5
const ZONE_ROWS: int = 4
const ZONE_THICKNESS: float = 0.02
const ZONE_GRASS_COLOR: Color = Color(0.28, 0.36, 0.24)
const ZONE_METAL_COLOR: Color = Color(0.33, 0.35, 0.39)

## Lane indices into OUTPOST_POSITIONS: positions 0/3/6 share one Z band,
## 1/4/7 another, 2/5/8 a third (see the "3 near player, 3 middle, 3 near
## enemy" comment above) -- each band reads as a road from HQ to HQ.
const ROAD_LANES: Array[Array] = [
	[0, 3, 6],
	[1, 4, 7],
	[2, 5, 8],
]
const ROAD_WIDTH: float = 5.0
const ROAD_HEIGHT: float = ZONE_THICKNESS * 2.0
const ROAD_COLOR: Color = Color(0.15, 0.15, 0.17)

const ROCKY_RADIUS: float = 7.0
const ROCKY_HEIGHT: float = ZONE_THICKNESS * 1.5
const ROCKY_COLOR: Color = Color(0.30, 0.27, 0.23)


static func generate_battlefield(game_root: Node3D) -> void:
	var world_root: Node3D = game_root.get_node("WorldRoot")
	var buildings_root: Node3D = world_root.get_node("BuildingsRoot")
	var effects_root: Node3D = world_root.get_node("EffectsRoot")

	world_root.add_child(_build_terrain_zones())
	world_root.add_child(_build_roads())
	world_root.add_child(_build_rocky_patches())

	buildings_root.add_child(create_hq(Constants.Team.PLAYER, PLAYER_HQ_POSITION))
	buildings_root.add_child(create_hq(Constants.Team.ENEMY, ENEMY_HQ_POSITION))

	for outpost_position in OUTPOST_POSITIONS:
		buildings_root.add_child(create_outpost(outpost_position))

	for obstacle_position in OBSTACLE_POSITIONS:
		world_root.add_child(create_obstacle(obstacle_position))

	effects_root.add_child(_build_grid_overlay())
	NavigationManager.rebake_navigation(game_root)


static func create_hq(team: int, position: Vector3) -> Node3D:
	var hq: Node3D = HQ_SCENE.instantiate()
	hq.setup(team, position)
	return hq


static func create_outpost(position: Vector3) -> Node3D:
	var outpost: Node3D = OUTPOST_SCENE.instantiate()
	outpost.position = position
	return outpost


static func create_obstacle(position: Vector3) -> StaticBody3D:
	var obstacle := StaticBody3D.new()
	obstacle.name = "Obstacle"
	obstacle.position = position + Vector3(0.0, OBSTACLE_HEIGHT * 0.5, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = OBSTACLE_COLOR

	var mesh := BoxMesh.new()
	mesh.size = Vector3(OBSTACLE_RADIUS * 2.0, OBSTACLE_HEIGHT, OBSTACLE_RADIUS * 1.5)
	mesh.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	obstacle.add_child(mesh_instance)

	var shape := BoxShape3D.new()
	shape.size = mesh.size
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	obstacle.add_child(collision_shape)

	return obstacle


## Checkerboard of grass/metal plains slabs spanning the arena, purely for
## visual variety -- the ground itself stays a single physical collider.
static func _build_terrain_zones() -> Node3D:
	var root := Node3D.new()
	root.name = "TerrainZones"

	var half_length: float = Constants.ARENA_LENGTH * 0.5
	var half_width: float = Constants.ARENA_WIDTH * 0.5
	var cell_size_x: float = Constants.ARENA_LENGTH / ZONE_COLS
	var cell_size_z: float = Constants.ARENA_WIDTH / ZONE_ROWS

	for col in range(ZONE_COLS):
		for row in range(ZONE_ROWS):
			var center := Vector3(
				-half_length + (col + 0.5) * cell_size_x,
				ZONE_THICKNESS * 0.5,
				-half_width + (row + 0.5) * cell_size_z
			)
			var color: Color = ZONE_GRASS_COLOR if (col + row) % 2 == 0 else ZONE_METAL_COLOR
			root.add_child(_build_slab(center, Vector3(cell_size_x, ZONE_THICKNESS, cell_size_z), color))

	return root


## Darker road strips connecting each HQ to its outposts along the three
## lanes described by ROAD_LANES, sitting just above the plains zones.
static func _build_roads() -> Node3D:
	var root := Node3D.new()
	root.name = "Roads"

	for lane in ROAD_LANES:
		var points: Array[Vector3] = [PLAYER_HQ_POSITION]
		for outpost_index in lane:
			points.append(OUTPOST_POSITIONS[outpost_index])
		points.append(ENEMY_HQ_POSITION)

		for i in range(points.size() - 1):
			root.add_child(_build_road_segment(points[i], points[i + 1]))

	return root


static func _build_road_segment(start: Vector3, end: Vector3) -> MeshInstance3D:
	var diff: Vector3 = end - start
	diff.y = 0.0
	var length: float = diff.length()

	var center: Vector3 = (start + end) * 0.5
	center.y = ROAD_HEIGHT * 0.5

	var mesh_instance := _build_slab(center, Vector3(ROAD_WIDTH, ROAD_HEIGHT, length), ROAD_COLOR)
	mesh_instance.rotation.y = atan2(diff.x, diff.z)
	return mesh_instance


## Tints the ground beneath each physical obstacle so the blocked, rocky
## areas read clearly from the angled camera, without affecting collision.
static func _build_rocky_patches() -> Node3D:
	var root := Node3D.new()
	root.name = "RockyPatches"

	for obstacle_position in OBSTACLE_POSITIONS:
		var center: Vector3 = obstacle_position + Vector3(0.0, ROCKY_HEIGHT * 0.5, 0.0)

		var material := StandardMaterial3D.new()
		material.albedo_color = ROCKY_COLOR

		var mesh := CylinderMesh.new()
		mesh.top_radius = ROCKY_RADIUS
		mesh.bottom_radius = ROCKY_RADIUS
		mesh.height = ROCKY_HEIGHT
		mesh.material = material

		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = mesh
		mesh_instance.position = center
		root.add_child(mesh_instance)

	return root


static func _build_slab(center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color

	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = center
	return mesh_instance


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
