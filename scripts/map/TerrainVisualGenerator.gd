class_name TerrainVisualGenerator
extends RefCounted
## Builds the full visual battlefield dressing: terrain zone tiling, a
## per-map center feature (causeway/crater/frontline scar), roads connecting
## HQs/outposts, boundary cliffs/ridges, gameplay obstacles (visually
## upgraded rock clusters), landing pads, team markers, hand-placed set
## pieces, and scattered environmental decorations -- then wires up ambient
## animation (pulse/rotate/blink) for the parts that need it. Called once
## from MapGenerator.generate_battlefield().
##
## Everything map-specific (palette, zone weighting, road color, cliff
## density, decoration recipe, set pieces, center feature) comes from the
## MapPresets entry passed in, so the three maps read visually distinct
## without this file knowing which map is which.
##
## All placement randomness is seeded from GameState.map_seed, so a given
## match's battlefield dressing (down to individual prop positions) is
## reproducible; see MapDecorations' own docstring for how per-prop visual
## variation (tilts, offsets) stays deterministic too.
##
## These are procedural final-style placeholder visuals -- meant to be
## replaceable by authored Blender/terrain assets later without touching
## MapGenerator.gd, since it only depends on generate()'s signature.

const _ZONE_COLS: int = 6
const _ZONE_ROWS: int = 5
const _ZONE_THICKNESS: float = 0.02

enum _ZoneKind { GRASS, DIRT, METAL, SCORCHED }

const _ROAD_WIDTH: float = 5.0
const _ROAD_SPUR_WIDTH: float = 3.5

const _CLIFF_LENGTH_RANGE: Vector2 = Vector2(14.0, 26.0)
const _CLIFF_HEIGHT: float = 3.0
const _CLIFF_EDGE_MARGIN: float = 6.0

const _OBSTACLE_RADIUS: float = 4.0

const _LANDING_PAD_HQ_RADIUS: float = 8.0
const _LANDING_PAD_OUTPOST_RADIUS: float = 5.0
const _LANDING_PAD_OFFSET: float = 10.0
const _LANDING_PAD_HEIGHT: float = 0.06

const _TEAM_MARKER_HEIGHT: float = 5.0
const _TEAM_MARKER_OFFSET: float = 6.0

const _SCATTER_ATTEMPTS_PER_DECORATION: int = 6
const _DECORATION_MIN_CLEARANCE: float = 9.0
## Hand-placed set pieces are deliberately closer to the action than
## scattered props, but still comfortably outside the 6.0 capture radius.
const _FIXED_DECORATION_MIN_CLEARANCE: float = 8.0

# Center features are all flat, collisionless ground reads (tallest is the
# causeway's 0.08 edge strip): stacked heights interleave with the 0.02
# zone tiles, 0.04 roads, and 0.06 landing pads so nothing z-fights.
const _BRIDGE_BAND_SIZE: Vector3 = Vector3(24.0, 0.055, 9.0)
const _BRIDGE_EDGE_SIZE: Vector3 = Vector3(24.0, 0.08, 0.3)
const _BRIDGE_DECK_COLOR: Color = Color(0.23, 0.24, 0.26)
const _CRATER_CENTER: Vector3 = Vector3(2.0, 0.0, 2.0)
const _CRATER_OUTER_RADIUS: float = 26.0
const _CRATER_INNER_RADIUS: float = 15.0
const _CRATER_OUTER_COLOR: Color = Color(0.16, 0.15, 0.14)
const _CRATER_INNER_COLOR: Color = Color(0.11, 0.1, 0.1)
const _FRONT_SCAR_SIZE: Vector3 = Vector3(6.0, 0.028, 92.0)
const _FRONT_SCAR_COLOR: Color = Color(0.09, 0.08, 0.08)
const _FRONT_SCAR_FLANK_SIZE: Vector3 = Vector3(2.5, 0.024, 60.0)
const _FRONT_SCAR_FLANK_COLOR: Color = Color(0.13, 0.12, 0.11)

const _PULSE_ENERGY_LOW: float = 0.8
const _PULSE_ENERGY_HIGH: float = 2.2
const _PULSE_DURATION_RANGE: Vector2 = Vector2(1.2, 2.2)
const _ROTATION_DURATION_RANGE: Vector2 = Vector2(6.0, 12.0)
const _BLINK_INTERVAL_RANGE: Vector2 = Vector2(0.6, 1.4)


static func generate(world_root: Node3D, player_hq_position: Vector3, enemy_hq_position: Vector3,
		outpost_positions: Array, obstacle_positions: Array, preset: Dictionary = {}) -> void:
	if preset.is_empty():
		preset = MapPresets.get_preset(GameState.selected_map)

	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.map_seed

	var exclusion_points: Array[Vector3] = [player_hq_position, enemy_hq_position]
	exclusion_points.append_array(outpost_positions)
	exclusion_points.append_array(obstacle_positions)

	var dressing_root := Node3D.new()
	dressing_root.name = "BattlefieldDressing"
	world_root.add_child(dressing_root)

	dressing_root.add_child(_build_zones(rng, preset))
	dressing_root.add_child(_build_center_feature(preset))
	dressing_root.add_child(_build_roads(player_hq_position, enemy_hq_position, outpost_positions, preset))
	dressing_root.add_child(_build_cliffs(rng, exclusion_points, preset))
	_build_obstacles(dressing_root, obstacle_positions)
	_build_landing_pads(dressing_root, player_hq_position, enemy_hq_position, outpost_positions)
	_build_team_markers(dressing_root, player_hq_position, enemy_hq_position)
	_build_fixed_decorations(dressing_root, rng, preset, exclusion_points)
	_scatter_decorations(dressing_root, rng, exclusion_points, preset)

	_wire_animations(dressing_root, rng)


# ---------------------------------------------------------------------------
# Terrain zone tiling -- grass/dirt/metal/scorched patchwork
# ---------------------------------------------------------------------------

## Weighted-random (not checkerboard) zone tiling so the ground reads as
## hand-painted rather than mechanically patterned. Scorched/dirt zones lean
## toward the map's center column, where outposts cluster and fighting is
## heaviest; the rear areas near each HQ stay mostly base-tone. Colors and
## weights come from the preset, so each map's ground reads distinct (Green
## Divide's grass fields, Iron Basin's plate floor, Ash Line's ash).
static func _build_zones(rng: RandomNumberGenerator, preset: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "TerrainZones"

	var zone_materials: Dictionary = _make_zone_materials(preset)
	var zone_weights: Dictionary = preset["zone_weights"]

	var half_length: float = Constants.ARENA_LENGTH * 0.5
	var half_width: float = Constants.ARENA_WIDTH * 0.5
	var cell_size_x: float = Constants.ARENA_LENGTH / _ZONE_COLS
	var cell_size_z: float = Constants.ARENA_WIDTH / _ZONE_ROWS

	for col in range(_ZONE_COLS):
		var center_bias: float = 1.0 - clampf(absf(float(col) - (_ZONE_COLS - 1) * 0.5) / (_ZONE_COLS * 0.5), 0.0, 1.0)
		for row in range(_ZONE_ROWS):
			var center := Vector3(
				-half_length + (col + 0.5) * cell_size_x,
				_ZONE_THICKNESS * 0.5,
				-half_width + (row + 0.5) * cell_size_z
			)
			var kind: int = _pick_zone_kind(rng, center_bias, zone_weights)
			root.add_child(_build_material_slab(center, Vector3(cell_size_x, _ZONE_THICKNESS, cell_size_z),
				zone_materials[kind]))

	return root


static func _pick_zone_kind(rng: RandomNumberGenerator, center_bias: float, weights: Dictionary) -> int:
	var scorched_chance: float = weights["scorched_base"] + center_bias * weights["scorched_center_bonus"]
	var dirt_chance: float = weights["dirt"]
	var metal_chance: float = weights["metal"]

	var roll: float = rng.randf()
	if roll < scorched_chance:
		return _ZoneKind.SCORCHED
	roll -= scorched_chance
	if roll < dirt_chance:
		return _ZoneKind.DIRT
	roll -= dirt_chance
	if roll < metal_chance:
		return _ZoneKind.METAL
	return _ZoneKind.GRASS


## Fresh materials per generate() call rather than MaterialLibrary's shared
## cached instances: every map recolors the whole ground plane, and sharing
## would leak one map's palette into everything else using those materials.
## The 30 zone tiles all reference these same four instances, so the cost
## stays four materials per match.
static func _make_zone_materials(preset: Dictionary) -> Dictionary:
	var colors: Dictionary = preset["zone_colors"]
	return {
		_ZoneKind.GRASS: _matte_material(colors["grass"]),
		_ZoneKind.DIRT: _matte_material(colors["dirt"]),
		_ZoneKind.METAL: _matte_material(colors["metal"]),
		_ZoneKind.SCORCHED: _matte_material(colors["scorched"]),
	}


static func _matte_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


# ---------------------------------------------------------------------------
# Center feature -- each map's single hand-authored landmark
# ---------------------------------------------------------------------------

## All three variants are flat, collisionless ground reads, so they can sit
## in the middle of the play space -- even underneath outposts, roads, and
## landing pads -- without touching navigation, spawns, or capture zones.
static func _build_center_feature(preset: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "CenterFeature"
	match preset.get("center_feature", ""):
		"bridge_band":
			_build_bridge_band(root)
		"crater":
			_build_crater(root)
		"front_scar":
			_build_front_scar(root)
	return root


## Green Divide: a widened causeway plaza where the HQ-to-HQ spine road
## crosses the center line, edged with neutral glow strips -- the "central
## bridge" the map is named for. The deck sits just above the 0.04-tall
## road slab so it reads as deliberately paved, and the central outpost's
## landing pad (top 0.06) still renders above it.
static func _build_bridge_band(root: Node3D) -> void:
	root.add_child(_build_material_slab(Vector3(0.0, _BRIDGE_BAND_SIZE.y * 0.5, 0.0),
		_BRIDGE_BAND_SIZE, _matte_material(_BRIDGE_DECK_COLOR)))

	for side in [-1.0, 1.0]:
		var edge_z: float = side * (_BRIDGE_BAND_SIZE.z * 0.5 - _BRIDGE_EDGE_SIZE.z * 0.5)
		root.add_child(_build_material_slab(Vector3(0.0, _BRIDGE_EDGE_SIZE.y * 0.5, edge_z),
			_BRIDGE_EDGE_SIZE, MaterialLibrary.neutral_emissive()))


## Iron Basin: the basin itself -- a huge scorched double-ring depression
## dominating mid-field, slightly off-center so it doesn't read as a
## compass rose. Flat discs rather than real geometry, so the "crater" is
## purely a ground read that units drive straight across.
static func _build_crater(root: Node3D) -> void:
	root.add_child(_flat_disc(_CRATER_CENTER, _CRATER_OUTER_RADIUS, 0.024, _CRATER_OUTER_COLOR))
	root.add_child(_flat_disc(_CRATER_CENTER, _CRATER_INNER_RADIUS, 0.03, _CRATER_INNER_COLOR))


## Ash Line: the no-man's-land scar -- a long charred strip running the
## width of the arena at x = 0 where the two sides grind against each
## other, flanked by two shorter, fainter burn lines.
static func _build_front_scar(root: Node3D) -> void:
	root.add_child(_build_material_slab(Vector3(0.0, _FRONT_SCAR_SIZE.y * 0.5, 0.0),
		_FRONT_SCAR_SIZE, _matte_material(_FRONT_SCAR_COLOR)))

	for side in [-1.0, 1.0]:
		root.add_child(_build_material_slab(
			Vector3(side * 6.0, _FRONT_SCAR_FLANK_SIZE.y * 0.5, 0.0),
			_FRONT_SCAR_FLANK_SIZE, _matte_material(_FRONT_SCAR_FLANK_COLOR)))


## A flat ground disc whose base sits on the ground plane and whose top
## lands at top_height -- the disc equivalent of _build_material_slab.
static func _flat_disc(center: Vector3, radius: float, top_height: float, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = top_height
	mesh.radial_segments = 40
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _matte_material(color)
	mesh_instance.position = center + Vector3(0.0, top_height * 0.5, 0.0)
	return mesh_instance


# ---------------------------------------------------------------------------
# Roads -- player HQ <-> nearby/middle/enemy outposts <-> enemy HQ
# ---------------------------------------------------------------------------

## One direct spine road between the HQs (always connects player HQ to
## enemy HQ), plus one spur per outpost to whichever landmark -- either HQ,
## or another outpost -- is nearest. Outposts close to a flank naturally
## spur straight to that HQ; outposts in the middle naturally bridge to
## their nearest neighboring outpost instead, so the network reads as
## "nearby outposts to their HQ, middle outposts bridging the two sides"
## without hand-authoring per-map road topology. Surface color comes from
## the preset (Iron Basin's darker metal roads, Green Divide's pale ones).
static func _build_roads(player_hq_position: Vector3, enemy_hq_position: Vector3,
		outpost_positions: Array, preset: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Roads"

	var road_color: Color = preset["road_color"]
	root.add_child(MapDecorations.create_road_segment(player_hq_position, enemy_hq_position,
		_ROAD_WIDTH, road_color))

	for outpost_position in outpost_positions:
		var nearest: Vector3 = _nearest_landmark(outpost_position, player_hq_position, enemy_hq_position, outpost_positions)
		root.add_child(MapDecorations.create_road_segment(outpost_position, nearest,
			_ROAD_SPUR_WIDTH, road_color))

	return root


static func _nearest_landmark(from: Vector3, player_hq: Vector3, enemy_hq: Vector3, outposts: Array) -> Vector3:
	var nearest: Vector3 = player_hq
	var nearest_distance: float = from.distance_to(player_hq)

	var enemy_distance: float = from.distance_to(enemy_hq)
	if enemy_distance < nearest_distance:
		nearest = enemy_hq
		nearest_distance = enemy_distance

	for other in outposts:
		if other == from:
			continue
		var distance: float = from.distance_to(other)
		if distance < nearest_distance:
			nearest = other
			nearest_distance = distance

	return nearest


# ---------------------------------------------------------------------------
# Cliffs/ridges -- purely visual boundary framing, never collidable
# ---------------------------------------------------------------------------

## Low ridge formations scattered along the long (Z) edges of the arena,
## away from the central HQ-to-HQ lane where the match is actually played.
## Intentionally has no collision at all (unlike MAP_LAYOUTS' obstacles,
## which are explicitly gameplay-relevant) -- these exist purely to frame
## the battlefield's boundary for screenshots, never to block movement.
## Count comes from the preset: Iron Basin rings its crater with more,
## Ash Line's open wasteland gets fewer.
static func _build_cliffs(rng: RandomNumberGenerator, exclusion_points: Array[Vector3],
		preset: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Cliffs"

	var half_length: float = Constants.ARENA_LENGTH * 0.5
	var half_width: float = Constants.ARENA_WIDTH * 0.5

	var cliff_count: int = preset["cliff_count"]
	for i in range(cliff_count):
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var x: float = rng.randf_range(-half_length * 0.7, half_length * 0.7)
		var z: float = side * (half_width - _CLIFF_EDGE_MARGIN)
		var position := Vector3(x, 0.0, z)
		if not _is_clear(position, exclusion_points, Constants.CAPTURE_RADIUS * 3.0):
			continue
		var length: float = rng.randf_range(_CLIFF_LENGTH_RANGE.x, _CLIFF_LENGTH_RANGE.y)
		root.add_child(_build_ridge(position, length, rng.randf_range(-15.0, 15.0)))

	return root


static func _build_ridge(position: Vector3, length: float, yaw_degrees: float) -> Node3D:
	var ridge := Node3D.new()
	ridge.name = "Ridge"
	ridge.position = position
	ridge.rotation_degrees.y = yaw_degrees

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "RidgeBody"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(length, _CLIFF_HEIGHT, 5.0)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = MaterialLibrary.dark_metal()
	mesh_instance.position = Vector3(0.0, _CLIFF_HEIGHT * 0.5, 0.0)
	ridge.add_child(mesh_instance)

	return ridge


# ---------------------------------------------------------------------------
# Obstacles -- MAP_LAYOUTS' gameplay-relevant blockers, now rock clusters
# ---------------------------------------------------------------------------

static func _build_obstacles(dressing_root: Node3D, obstacle_positions: Array) -> void:
	for obstacle_position in obstacle_positions:
		dressing_root.add_child(MapDecorations.create_rock_cluster(obstacle_position, _OBSTACLE_RADIUS, true))


# ---------------------------------------------------------------------------
# Landing pads and team markers
# ---------------------------------------------------------------------------

static func _build_landing_pads(dressing_root: Node3D, player_hq: Vector3, enemy_hq: Vector3, outposts: Array) -> void:
	var player_forward: Vector3 = (enemy_hq - player_hq).normalized()

	dressing_root.add_child(_landing_pad(player_hq + player_forward * _LANDING_PAD_OFFSET,
		_LANDING_PAD_HQ_RADIUS, Constants.Team.PLAYER))
	dressing_root.add_child(_landing_pad(enemy_hq - player_forward * _LANDING_PAD_OFFSET,
		_LANDING_PAD_HQ_RADIUS, Constants.Team.ENEMY))
	for outpost_position in outposts:
		dressing_root.add_child(_landing_pad(outpost_position, _LANDING_PAD_OUTPOST_RADIUS, Constants.Team.NEUTRAL))


static func _landing_pad(position: Vector3, radius: float, team: int) -> Node3D:
	var root := Node3D.new()
	root.name = "LandingPad"
	root.position = position

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = _LANDING_PAD_HEIGHT
	mesh.radial_segments = 28

	var mesh_instance := MeshInstance3D.new()
	# Named "PulseCore" (not the more literal "PadGlow") so it picks up the
	# same gentle pulse animation as power nodes/pylons for free.
	mesh_instance.name = "PulseCore"
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, _LANDING_PAD_HEIGHT * 0.5, 0.0)
	mesh_instance.material_override = MaterialLibrary.emissive_for_team(team).duplicate()
	root.add_child(mesh_instance)

	return root


static func _build_team_markers(dressing_root: Node3D, player_hq: Vector3, enemy_hq: Vector3) -> void:
	dressing_root.add_child(_team_marker(
		player_hq + Vector3(_TEAM_MARKER_OFFSET, 0.0, _TEAM_MARKER_OFFSET), Constants.Team.PLAYER))
	dressing_root.add_child(_team_marker(
		enemy_hq - Vector3(_TEAM_MARKER_OFFSET, 0.0, _TEAM_MARKER_OFFSET), Constants.Team.ENEMY))


## A thin holographic-looking beam with a small banner near the top --
## purely a team-ownership landmark, not a gameplay object.
static func _team_marker(position: Vector3, team: int) -> Node3D:
	var root := Node3D.new()
	root.name = "TeamMarker"
	root.position = position

	var material: StandardMaterial3D = MaterialLibrary.emissive_for_team(team).duplicate()
	material.emission_energy_multiplier = 1.2

	var beam_mesh := CylinderMesh.new()
	beam_mesh.top_radius = 0.05
	beam_mesh.bottom_radius = 0.12
	beam_mesh.height = _TEAM_MARKER_HEIGHT
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = beam_mesh
	beam.position = Vector3(0.0, _TEAM_MARKER_HEIGHT * 0.5, 0.0)
	beam.material_override = material
	root.add_child(beam)

	var banner_mesh := BoxMesh.new()
	banner_mesh.size = Vector3(1.4, 0.9, 0.05)
	var banner := MeshInstance3D.new()
	banner.name = "Banner"
	banner.mesh = banner_mesh
	banner.position = Vector3(0.6, _TEAM_MARKER_HEIGHT - 1.0, 0.0)
	banner.material_override = material
	root.add_child(banner)

	return root


# ---------------------------------------------------------------------------
# Hand-placed set pieces + scattered ambient decorations
# ---------------------------------------------------------------------------

## The preset's hand-placed set pieces (Iron Basin's vents and pipes, Ash
## Line's warning lights along the scar, ...) -- the props that carry each
## map's identity, guaranteed present regardless of scatter luck. Their
## positions are hand-verified against MAP_LAYOUTS, but each one is still
## defensively re-checked against the live exclusion list so a future
## layout tweak can only ever drop a set piece, never bury a capture zone
## under one. Placed positions join exclusion_points so the scatter pass
## then avoids them like any other landmark.
static func _build_fixed_decorations(dressing_root: Node3D, rng: RandomNumberGenerator,
		preset: Dictionary, exclusion_points: Array[Vector3]) -> void:
	for entry in preset["fixed_decorations"]:
		var position: Vector3 = entry["position"]
		if not _is_clear(position, exclusion_points, _FIXED_DECORATION_MIN_CLEARANCE):
			continue
		var decoration: Node3D = _build_decoration(entry["kind"], position, rng, Constants.Team.NEUTRAL)
		if decoration == null:
			continue
		dressing_root.add_child(decoration)
		exclusion_points.append(position)


## Places every prop kind in the preset's decoration recipe at random
## (seeded) spots, rejecting any candidate too close to an HQ, outpost,
## obstacle, set piece, or an already-placed decoration -- keeping capture
## zones, spawn zones, and the general play area clear per the "no blocking
## navigation" rule. Since placement is a single unmirrored random walk
## across the whole arena (never reflected across the center line), the
## result reads asymmetric and hand-placed rather than procedurally uniform.
static func _scatter_decorations(dressing_root: Node3D, rng: RandomNumberGenerator,
		exclusion_points: Array[Vector3], preset: Dictionary) -> void:
	var placed_points: Array[Vector3] = []
	placed_points.append_array(exclusion_points)

	var decoration_counts: Dictionary = preset["decoration_counts"]
	for kind in decoration_counts.keys():
		var count: int = decoration_counts[kind]
		for i in range(count):
			var candidate: Variant = _find_scatter_position(rng, placed_points)
			if candidate == null:
				continue
			var position: Vector3 = candidate
			placed_points.append(position)

			var team_hint: int = [Constants.Team.PLAYER, Constants.Team.ENEMY, Constants.Team.NEUTRAL][rng.randi_range(0, 2)]
			var decoration: Node3D = _build_decoration(kind, position, rng, team_hint)
			if decoration != null:
				dressing_root.add_child(decoration)


static func _find_scatter_position(rng: RandomNumberGenerator, placed_points: Array[Vector3]) -> Variant:
	var half_length: float = Constants.ARENA_LENGTH * 0.5 - _DECORATION_MIN_CLEARANCE
	var half_width: float = Constants.ARENA_WIDTH * 0.5 - _DECORATION_MIN_CLEARANCE

	for attempt in range(_SCATTER_ATTEMPTS_PER_DECORATION):
		var candidate := Vector3(
			rng.randf_range(-half_length, half_length),
			0.0,
			rng.randf_range(-half_width, half_width)
		)
		if _is_clear(candidate, placed_points, _DECORATION_MIN_CLEARANCE):
			return candidate

	return null


static func _build_decoration(kind: String, position: Vector3, rng: RandomNumberGenerator, team_hint: int) -> Node3D:
	match kind:
		"rock_cluster":
			return MapDecorations.create_rock_cluster(position, rng.randf_range(2.0, 3.5))
		"wreck":
			return MapDecorations.create_wreck(position, team_hint)
		"antenna":
			return MapDecorations.create_antenna(position)
		"power_node":
			return MapDecorations.create_power_node(position)
		"crate_stack":
			return MapDecorations.create_crate_stack(position)
		"energy_pylon":
			return MapDecorations.create_energy_pylon(position)
		"scorch_mark":
			return MapDecorations.create_scorch_mark(position, rng.randf_range(2.5, 4.5))
		"metal_plate":
			return MapDecorations.create_metal_plate(position)
		"pipe_run":
			return MapDecorations.create_pipe_run(position, rng.randf_range(5.0, 8.0))
		"glow_vent":
			return MapDecorations.create_glow_vent(position)
		"broken_machine":
			return MapDecorations.create_broken_machine(position)
		"warning_light":
			return MapDecorations.create_warning_light(position)
		"ruined_structure":
			return MapDecorations.create_ruined_structure(position)
		"smoke_column":
			return MapDecorations.create_smoke_column(position)
		_:
			return null


static func _is_clear(position: Vector3, points: Array[Vector3], min_distance: float) -> bool:
	for point in points:
		if position.distance_to(point) < min_distance:
			return false
	return true


# ---------------------------------------------------------------------------
# Ambient animation -- pulse / rotate / blink, wired up by child node name
# ---------------------------------------------------------------------------

## Scans the whole dressing subtree once, after everything has been added
## to the scene tree (Tween.create_tween() requires that), and hooks up a
## looping Tween for every recognized child name: "PulseCore"/"GlowRing*"
## pulse, "Dish" rotates, "Light"/"Light*" blinks.
static func _wire_animations(dressing_root: Node3D, rng: RandomNumberGenerator) -> void:
	for child in dressing_root.find_children("*", "", true, false):
		var child_name: String = child.name
		if child_name == "PulseCore" or child_name.begins_with("GlowRing"):
			_animate_pulse(child, rng)
		elif child_name == "Dish":
			_animate_rotation(child, rng)
		elif child_name == "Light" or child_name.begins_with("Light"):
			_animate_blink(child, rng)


static func _animate_pulse(node: Node, rng: RandomNumberGenerator) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null:
		return
	var material := mesh_instance.material_override as StandardMaterial3D
	if material == null:
		return

	var duration: float = rng.randf_range(_PULSE_DURATION_RANGE.x, _PULSE_DURATION_RANGE.y)
	var tween: Tween = mesh_instance.create_tween()
	tween.set_loops()
	tween.tween_property(material, "emission_energy_multiplier", _PULSE_ENERGY_HIGH, duration).set_trans(Tween.TRANS_SINE)
	tween.tween_property(material, "emission_energy_multiplier", _PULSE_ENERGY_LOW, duration).set_trans(Tween.TRANS_SINE)


static func _animate_rotation(node: Node, rng: RandomNumberGenerator) -> void:
	var node_3d := node as Node3D
	if node_3d == null:
		return

	var duration: float = rng.randf_range(_ROTATION_DURATION_RANGE.x, _ROTATION_DURATION_RANGE.y)
	var tween: Tween = node_3d.create_tween()
	tween.set_loops()
	tween.tween_property(node_3d, "rotation:y", TAU, duration).as_relative().set_trans(Tween.TRANS_LINEAR)


static func _animate_blink(node: Node, rng: RandomNumberGenerator) -> void:
	var node_3d := node as Node3D
	if node_3d == null:
		return

	var interval: float = rng.randf_range(_BLINK_INTERVAL_RANGE.x, _BLINK_INTERVAL_RANGE.y)
	var tween: Tween = node_3d.create_tween()
	tween.set_loops()
	tween.tween_callback(func() -> void: node_3d.visible = false).set_delay(interval)
	tween.tween_callback(func() -> void: node_3d.visible = true).set_delay(interval)


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

static func _build_material_slab(center: Vector3, size: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = center
	return mesh_instance
