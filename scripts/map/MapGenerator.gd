class_name MapGenerator
extends RefCounted
## Stateless battlefield layout generator.
## Builds both HQs, the neutral outposts, and a debug grid overlay for the
## match. Called once from the gameplay scene's _ready().

const HQ_SCENE: PackedScene = preload("res://scenes/buildings/Base.tscn")
const OUTPOST_SCENE: PackedScene = preload("res://scenes/buildings/Outpost.tscn")

## One layout per Constants.MapPreset. "outposts" lists are priority-ordered
## (highest-priority first) so generate_battlefield() can slice the first N
## for whatever GameState.selected_outpost_count was chosen (5/7/9) while
## keeping each map's character -- e.g. Iron Basin's middle cluster stays
## first so its outposts read as "strong middle" even at the lowest count.
const MAP_LAYOUTS: Dictionary = {
	# Balanced, open central field: hand-placed rather than mirrored, so
	# neither side reads as a perfect reflection of the other.
	Constants.MapPreset.GREEN_DIVIDE: {
		"player_hq": Vector3(-90.0, 0.0, 0.0),
		"enemy_hq": Vector3(90.0, 0.0, 0.0),
		"outposts": [
			Vector3(6.0, 0.0, 3.0),
			Vector3(-50.0, 0.0, 4.0),
			Vector3(58.0, 0.0, 6.0),
			Vector3(-9.0, 0.0, -35.0),
			Vector3(10.0, 0.0, 32.0),
			Vector3(-55.0, 0.0, -32.0),
			Vector3(52.0, 0.0, -29.0),
			Vector3(-60.0, 0.0, 28.0),
			Vector3(48.0, 0.0, 34.0),
		],
		"obstacles": [
			Vector3(-30.0, 0.0, -18.0),
			Vector3(-20.0, 0.0, 22.0),
			Vector3(25.0, 0.0, -20.0),
			Vector3(32.0, 0.0, 18.0),
			Vector3(0.0, 0.0, -12.0),
		],
	},
	# More obstacles, strong middle outposts: HQs pulled in slightly so the
	# crowded, obstacle-heavy center is reachable early and worth fighting for.
	Constants.MapPreset.IRON_BASIN: {
		"player_hq": Vector3(-85.0, 0.0, 0.0),
		"enemy_hq": Vector3(85.0, 0.0, 0.0),
		"outposts": [
			Vector3(-12.0, 0.0, -14.0),
			Vector3(14.0, 0.0, -10.0),
			Vector3(-10.0, 0.0, 16.0),
			Vector3(16.0, 0.0, 18.0),
			Vector3(-58.0, 0.0, -22.0),
			Vector3(58.0, 0.0, -20.0),
			Vector3(-56.0, 0.0, 24.0),
			Vector3(56.0, 0.0, 26.0),
			Vector3(0.0, 0.0, -34.0),
		],
		"obstacles": [
			Vector3(-30.0, 0.0, -8.0),
			Vector3(-28.0, 0.0, 20.0),
			Vector3(30.0, 0.0, -6.0),
			Vector3(28.0, 0.0, 22.0),
			Vector3(0.0, 0.0, -26.0),
			Vector3(0.0, 0.0, 30.0),
			Vector3(-45.0, 0.0, 4.0),
			Vector3(45.0, 0.0, 2.0),
			Vector3(5.0, 0.0, -2.0),
		],
	},
	# Long, narrow battlefield: HQs pushed apart, outposts confined to a
	# tight central band so the frontline forms fast and stays aggressive.
	Constants.MapPreset.ASH_LINE: {
		"player_hq": Vector3(-100.0, 0.0, 0.0),
		"enemy_hq": Vector3(100.0, 0.0, 0.0),
		"outposts": [
			Vector3(0.0, 0.0, -8.0),
			Vector3(0.0, 0.0, 10.0),
			Vector3(-30.0, 0.0, -14.0),
			Vector3(30.0, 0.0, 12.0),
			Vector3(-30.0, 0.0, 14.0),
			Vector3(30.0, 0.0, -12.0),
			Vector3(-60.0, 0.0, -10.0),
			Vector3(60.0, 0.0, 8.0),
			Vector3(62.0, 0.0, -16.0),
		],
		"obstacles": [
			Vector3(-40.0, 0.0, -22.0),
			Vector3(-40.0, 0.0, 22.0),
			Vector3(40.0, 0.0, -22.0),
			Vector3(40.0, 0.0, 22.0),
		],
	},
}

const GRID_STEP: float = 20.0
const GRID_HEIGHT: float = 0.06
const GRID_COLOR: Color = Color(0.35, 0.45, 0.38)

## Low ridges/rocks scattered in the open lanes between buildings, positions
## taken from each map's MAP_LAYOUTS entry -- physical blockers only (not
## carved into the navmesh), so ground units/the grounded commander collide
## and slide around them via move_and_slide() while the airborne commander
## (collision_mask = 0) flies straight over. Kept well clear of HQs/outposts
## so pathfinding never has to route around a maze, just nudge around rocks.
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

	var layout: Dictionary = MAP_LAYOUTS.get(
		GameState.selected_map, MAP_LAYOUTS[Constants.MapPreset.GREEN_DIVIDE]
	)
	var player_hq_position: Vector3 = layout["player_hq"]
	var enemy_hq_position: Vector3 = layout["enemy_hq"]
	var all_outposts: Array = layout["outposts"]
	var outpost_count: int = clamp(GameState.selected_outpost_count, 1, all_outposts.size())
	var outpost_positions: Array = all_outposts.slice(0, outpost_count)
	var obstacle_positions: Array = layout["obstacles"]

	world_root.add_child(_build_terrain_zones())
	world_root.add_child(_build_roads(player_hq_position, enemy_hq_position, outpost_positions))
	world_root.add_child(_build_rocky_patches(obstacle_positions))

	buildings_root.add_child(create_hq(Constants.Team.PLAYER, player_hq_position))
	buildings_root.add_child(create_hq(Constants.Team.ENEMY, enemy_hq_position))

	for outpost_position in outpost_positions:
		buildings_root.add_child(create_outpost(outpost_position))

	for obstacle_position in obstacle_positions:
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


## Darker road strips, sitting just above the plains zones: one spine
## connecting the two HQs directly, plus one spur from each outpost to
## whichever HQ it's closer to. Agnostic to outpost count/position, so it
## works the same for every map layout and every outpost-count slice.
static func _build_roads(player_hq_position: Vector3, enemy_hq_position: Vector3, outpost_positions: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "Roads"

	root.add_child(_build_road_segment(player_hq_position, enemy_hq_position))

	for outpost_position in outpost_positions:
		var nearest_hq: Vector3 = player_hq_position
		if outpost_position.distance_to(enemy_hq_position) < outpost_position.distance_to(player_hq_position):
			nearest_hq = enemy_hq_position
		root.add_child(_build_road_segment(outpost_position, nearest_hq))

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
static func _build_rocky_patches(obstacle_positions: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "RockyPatches"

	for obstacle_position in obstacle_positions:
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
