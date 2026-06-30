class_name NavigationManager
extends RefCounted
## Stateless movement/navigation helpers shared by units, the commander, and
## the battlefield generator: keeping everyone on the flat arena, picking
## destination points that don't overlap, and spacing out attack-wave
## formations. Mirrors MapGenerator.gd/TacticalDirector.gd's static-utility
## pattern rather than being an autoload, since none of this needs state.

## Margin kept inside the arena edges so capsule/box collision shapes never
## clip through the boundary.
const BOUNDARY_MARGIN: float = 2.0

const FORMATION_RANK_COUNT: int = 3
const FORMATION_RANK_SPACING: float = 6.0
const FORMATION_LANE_SPACING: float = 4.0


## Picks a uniformly random point within `radius` of `position` (flat on the
## XZ plane), clamped to the battlefield. Used to keep units from sharing a
## single exact destination.
static func get_random_point_near(position: Vector3, radius: float) -> Vector3:
	if radius <= 0.0:
		return clamp_to_battlefield(position)

	var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if offset == Vector3.ZERO:
		return clamp_to_battlefield(position)
	offset = offset.normalized() * randf_range(0.0, radius)
	return clamp_to_battlefield(position + offset)


## Clamps a world position to stay within the arena bounds (XZ only -- Y is
## left untouched so callers keep their own altitude/height logic).
static func clamp_to_battlefield(world_position: Vector3) -> Vector3:
	var half_length: float = Constants.ARENA_LENGTH * 0.5 - BOUNDARY_MARGIN
	var half_width: float = Constants.ARENA_WIDTH * 0.5 - BOUNDARY_MARGIN
	return Vector3(
		clamp(world_position.x, -half_length, half_length),
		world_position.y,
		clamp(world_position.z, -half_width, half_width)
	)


## Picks a point pushed out from `position`'s immediate center (between 35%
## and 100% of `radius` away), clamped to the battlefield. Used so units
## capturing/defending a building spread around its capture zone instead of
## stacking directly on the center point.
static func get_valid_ground_position_near(position: Vector3, radius: float) -> Vector3:
	var min_radius: float = radius * 0.35
	var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	if offset == Vector3.ZERO:
		offset = Vector3.RIGHT
	offset = offset.normalized() * randf_range(min_radius, max(min_radius, radius))
	return clamp_to_battlefield(position + offset)


## Returns `count` positions arranged in three depth ranks around `center`,
## spread laterally within each rank and stepped back along
## `-facing_direction` per rank. Rank 0 (the first third of the returned
## array) sits closest to `center`; rank 2 (the last third) sits furthest
## behind. Callers sort their own units front-to-back (e.g. tanks first,
## artillery last) before indexing into the result so heavier units lead an
## attack wave and support units trail it.
static func get_formation_positions(center: Vector3, count: int, facing_direction: Vector3) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	if count <= 0:
		return positions

	var forward: Vector3 = facing_direction
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else Vector3.FORWARD
	var right: Vector3 = forward.cross(Vector3.UP).normalized()

	var per_rank: int = ceili(float(count) / FORMATION_RANK_COUNT)

	for i in range(count):
		var rank: int = i / per_rank
		var slot_in_rank: int = i % per_rank
		var lane_count: int = min(per_rank, count - rank * per_rank)
		var lane_offset: float = (slot_in_rank - (lane_count - 1) * 0.5) * FORMATION_LANE_SPACING
		var depth_offset: float = -float(rank) * FORMATION_RANK_SPACING
		positions.append(clamp_to_battlefield(center + forward * depth_offset + right * lane_offset))

	return positions


## TerrainRoot bakes the battlefield's navmesh once on its own _ready(), but
## MapGenerator spawns obstacles afterward -- this gives it an explicit hook
## to refresh the mesh once the full layout exists.
static func rebake_navigation(game_root: Node3D) -> void:
	var region: NavigationRegion3D = game_root.get_node_or_null("WorldRoot/TerrainRoot/NavigationRegion3D")
	if region != null:
		region.bake_navigation_mesh()
