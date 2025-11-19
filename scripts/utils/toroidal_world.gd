class_name ToroidalWorld
## ToroidalWorld - Utility functions for wrap-around world calculations
##
## Handles:
## - Distance calculations considering world wrap-around
## - Finding nearest entities across world boundaries
## - Position wrapping

# World dimensions (will be set by GameWorld)
static var world_width: float = 1920.0
static var world_height: float = 1080.0


## Calculate shortest delta between two coordinates considering wrap-around
## @param a_coord: First coordinate (x or y)
## @param b_coord: Second coordinate (x or y)
## @param world_size: World dimension (width or height)
## @return: Shortest signed delta
static func toroidal_delta(a_coord: float, b_coord: float, world_size: float) -> float:
	var direct_delta = b_coord - a_coord

	# If direct distance is more than half the world size,
	# the wrapped distance is shorter
	if abs(direct_delta) > world_size / 2.0:
		if direct_delta > 0:
			return direct_delta - world_size
		else:
			return direct_delta + world_size

	return direct_delta


## Calculate toroidal distance squared between two positions
## @param pos_a: First position (Vector2)
## @param pos_b: Second position (Vector2)
## @return: Distance squared (avoids expensive sqrt)
static func toroidal_distance_squared(pos_a: Vector2, pos_b: Vector2) -> float:
	var dx = toroidal_delta(pos_a.x, pos_b.x, world_width)
	var dy = toroidal_delta(pos_a.y, pos_b.y, world_height)
	return dx * dx + dy * dy


## Calculate toroidal distance between two positions
## @param pos_a: First position (Vector2)
## @param pos_b: Second position (Vector2)
## @return: Actual distance
static func toroidal_distance(pos_a: Vector2, pos_b: Vector2) -> float:
	return sqrt(toroidal_distance_squared(pos_a, pos_b))


## Get direction vector from pos_a to pos_b considering wrap-around
## @param pos_a: Starting position
## @param pos_b: Target position
## @return: Normalized direction vector
static func toroidal_direction(pos_a: Vector2, pos_b: Vector2) -> Vector2:
	var dx = toroidal_delta(pos_a.x, pos_b.x, world_width)
	var dy = toroidal_delta(pos_a.y, pos_b.y, world_height)
	return Vector2(dx, dy).normalized()


## Wrap a position to stay within world bounds
## @param position: Position to wrap
## @return: Wrapped position
static func wrap_position(position: Vector2) -> Vector2:
	var wrapped = position

	# Wrap X
	if wrapped.x < 0:
		wrapped.x += world_width
	elif wrapped.x >= world_width:
		wrapped.x -= world_width

	# Wrap Y
	if wrapped.y < 0:
		wrapped.y += world_height
	elif wrapped.y >= world_height:
		wrapped.y -= world_height

	return wrapped


## Find nearest entity from a list considering toroidal distance
## @param from_pos: Position to measure from
## @param entities: Array of objects with 'position' or 'global_position' property
## @return: Nearest entity or null
static func find_nearest(from_pos: Vector2, entities: Array) -> Variant:
	if entities.is_empty():
		return null

	var nearest = null
	var nearest_dist_sq = INF

	for entity in entities:
		var entity_pos: Vector2
		if entity.has("global_position"):
			entity_pos = entity.global_position
		elif entity.has("position"):
			entity_pos = entity.position
		else:
			continue

		var dist_sq = toroidal_distance_squared(from_pos, entity_pos)
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = entity

	return nearest


## Check if a position is within range of another considering wrap-around
## @param pos_a: First position
## @param pos_b: Second position
## @param range_squared: Range squared (to avoid sqrt)
## @return: True if within range
static func is_within_range(pos_a: Vector2, pos_b: Vector2, range_squared: float) -> bool:
	return toroidal_distance_squared(pos_a, pos_b) <= range_squared


## Set world dimensions (called by GameWorld on initialization)
## @param width: World width
## @param height: World height
static func set_world_size(width: float, height: float) -> void:
	world_width = width
	world_height = height
	print("Toroidal world size set to: %dx%d" % [width, height])
