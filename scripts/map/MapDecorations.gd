class_name MapDecorations
extends RefCounted
## Reusable, stateless factories for individual battlefield set-dressing
## props. Each function builds and returns a detached Node3D -- callers
## (TerrainVisualGenerator) are responsible for add_child()-ing it into the
## scene and, for parts named below, wiring up a Tween for animation.
##
## These are procedural final-style placeholder props -- meant to be
## replaceable by authored Blender assets later without touching the
## callers, since TerrainVisualGenerator only depends on each function's
## return value and the documented child names.
##
## Determinism: none of these take an RNG parameter (to keep the exact
## signatures below), but every function that needs internal variation
## (a rock's exact tilt, a crate's offset, ...) seeds a local
## RandomNumberGenerator from hash(position) instead of using the global
## randf()/randi(). Combined with TerrainVisualGenerator seeding its own
## placement RNG from GameState.map_seed, the same seed always produces
## the exact same battlefield dressing, down to individual prop tilts.

const _ROCK_CHUNK_COUNT: int = 4
const _ROCK_HEIGHT: float = 1.5

const _WRECK_HULL_SIZE: Vector3 = Vector3(2.2, 0.6, 1.4)
const _WRECK_PART_SIZE: Vector3 = Vector3(0.8, 0.4, 0.9)

const _POWER_NODE_BASE_HEIGHT: float = 1.0
const _POWER_NODE_CORE_RADIUS: float = 0.35

const _ANTENNA_MAST_HEIGHT: float = 4.5
const _ANTENNA_DISH_RADIUS: float = 0.5

const _CRATE_SIZE: Vector3 = Vector3(0.8, 0.7, 0.8)

const _PYLON_HEIGHT: float = 3.5
const _PYLON_RING_COUNT: int = 2

const _ROAD_HEIGHT: float = 0.04
const _ROAD_LIGHT_SPACING: float = 25.0
const _ROAD_LIGHT_RADIUS: float = 0.12

const _SCORCH_HEIGHT: float = 0.015
## Flat ground decals must start above TerrainVisualGenerator's 0.02-thick
## zone tiles (or they'd be buried invisibly inside them) while staying
## below the 0.04-tall road slabs so roads still read as paved over them.
const _DECAL_GROUND_OFFSET: float = 0.022

const _PLATE_SIZE: Vector3 = Vector3(4.6, 0.1, 3.4)
const _PLATE_RIVET_RADIUS: float = 0.07

const _PIPE_RADIUS: float = 0.2
const _PIPE_HEIGHT: float = 0.5
const _PIPE_SUPPORT_SIZE: Vector3 = Vector3(1.1, 0.5, 0.3)

const _VENT_GRATE_RADIUS: float = 1.0
const _VENT_GRATE_HEIGHT: float = 0.14
const _VENT_GLOW_COLOR: Color = Color(1.0, 0.5, 0.12)

const _MACHINE_BODY_SIZE: Vector3 = Vector3(2.6, 1.7, 1.9)

const _WARNING_POST_HEIGHT: float = 2.4
const _WARNING_LAMP_RADIUS: float = 0.18

const _RUIN_WALL_LENGTH: float = 3.4
const _RUIN_WALL_HEIGHT: float = 2.4
const _RUIN_WALL_THICKNESS: float = 0.35

const _SMOKE_COLUMN_AMOUNT: int = 7
const _SMOKE_COLUMN_LIFETIME: float = 3.2
const _SMOKE_COLUMN_PARTICLE_SIZE: float = 0.8
const _SMOKE_COLUMN_COLOR: Color = Color(0.1, 0.1, 0.11, 0.5)


## A cluster of irregular rock chunks. Purely decorative (no collision) by
## default; pass blocks_navigation = true to make it a real physical
## obstacle instead (used for MapGenerator's gameplay-relevant obstacle
## list, so the same visual language covers both decorative and
## functional rock formations).
static func create_rock_cluster(position: Vector3, radius: float, blocks_navigation: bool = false) -> Node3D:
	var rng := _rng_for(position)
	var root: Node3D
	if blocks_navigation:
		var body := StaticBody3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = _ROCK_HEIGHT * 1.6
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = Vector3(0.0, shape.height * 0.5, 0.0)
		body.add_child(collision)
		root = body
	else:
		root = Node3D.new()
	root.name = "RockCluster"
	root.position = position

	for i in range(_ROCK_CHUNK_COUNT):
		var angle: float = TAU * float(i) / float(_ROCK_CHUNK_COUNT) + rng.randf_range(-0.3, 0.3)
		var dist: float = radius * rng.randf_range(0.3, 0.65)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * dist
		var chunk_height: float = _ROCK_HEIGHT * rng.randf_range(0.5, 1.0)
		var chunk_width: float = radius * rng.randf_range(0.35, 0.6)
		var material: StandardMaterial3D = MaterialLibrary.dark_metal() if i % 2 == 0 else MaterialLibrary.terrain_dirt()
		var chunk := _add_box(root, "Chunk%d" % i, Vector3(chunk_width, chunk_height, chunk_width * 0.85),
			offset + Vector3(0.0, chunk_height * 0.5, 0.0), material)
		chunk.rotation_degrees = Vector3(rng.randf_range(-8.0, 8.0), rad_to_deg(angle), rng.randf_range(-8.0, 8.0))

	return root


## Burnt-out vehicle debris. team_hint tints a single dim accent scrap so a
## wreck still hints at whose unit it once was; pass Constants.Team.NEUTRAL
## (or any unrecognized value) for anonymous wreckage. Never blocks
## navigation -- it reads as long-past battle damage, not a live obstacle.
static func create_wreck(position: Vector3, team_hint: int) -> Node3D:
	var rng := _rng_for(position)
	var root := Node3D.new()
	root.name = "Wreck"
	root.position = position
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	var hull := _add_box(root, "Hull", _WRECK_HULL_SIZE, Vector3(0.0, _WRECK_HULL_SIZE.y * 0.5, 0.0),
		MaterialLibrary.dark_metal())
	hull.rotation_degrees = Vector3(rng.randf_range(-6.0, 6.0), 0.0, rng.randf_range(10.0, 22.0))

	var part := _add_box(root, "DetachedPart", _WRECK_PART_SIZE,
		Vector3(1.4, _WRECK_PART_SIZE.y * 0.5, 0.9), MaterialLibrary.light_metal())
	part.rotation_degrees = Vector3(0.0, rng.randf_range(20.0, 70.0), rng.randf_range(15.0, 35.0))

	if team_hint == Constants.Team.PLAYER or team_hint == Constants.Team.ENEMY:
		var scrap_material: StandardMaterial3D = MaterialLibrary.emissive_for_team(team_hint).duplicate()
		scrap_material.emission_energy_multiplier = 0.4
		_add_box(root, "TeamScrap", Vector3(0.3, 0.06, 0.3), Vector3(-0.6, 0.65, -0.3), scrap_material)

	return root


## A small glowing utility pylon -- base, pulsing core (named "PulseCore"
## for the caller's Tween), and two ground cables.
static func create_power_node(position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "PowerNode"
	root.position = position

	_add_cylinder(root, "Base", 0.4, 0.5, _POWER_NODE_BASE_HEIGHT,
		Vector3(0.0, _POWER_NODE_BASE_HEIGHT * 0.5, 0.0), MaterialLibrary.dark_metal())
	_add_sphere(root, "PulseCore", _POWER_NODE_CORE_RADIUS,
		Vector3(0.0, _POWER_NODE_BASE_HEIGHT + _POWER_NODE_CORE_RADIUS * 0.6, 0.0),
		MaterialLibrary.energy_blue())
	_add_cable(root, "CableA", Vector3(0.0, 0.15, 0.0), Vector3(0.7, 0.05, 0.3))
	_add_cable(root, "CableB", Vector3(0.0, 0.15, 0.0), Vector3(-0.6, 0.05, -0.4))

	return root


## A tall comms mast with a rotating dish (named "Dish") and a blinking
## warning light at the tip (named "Light").
static func create_antenna(position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "Antenna"
	root.position = position

	_add_cylinder(root, "Mast", 0.08, 0.12, _ANTENNA_MAST_HEIGHT,
		Vector3(0.0, _ANTENNA_MAST_HEIGHT * 0.5, 0.0), MaterialLibrary.dark_metal())

	var dish := _add_sphere(root, "Dish", _ANTENNA_DISH_RADIUS,
		Vector3(0.0, _ANTENNA_MAST_HEIGHT * 0.78, 0.0), MaterialLibrary.light_metal())
	dish.scale.y = 0.3
	dish.rotation_degrees.x = 55.0

	_add_sphere(root, "Light", 0.1, Vector3(0.0, _ANTENNA_MAST_HEIGHT + 0.1, 0.0),
		MaterialLibrary.warning_yellow())

	return root


## Three offset supply crates, stacked with a bit of position-seeded
## irregularity so a row of stacks never looks copy-pasted.
static func create_crate_stack(position: Vector3) -> Node3D:
	var rng := _rng_for(position)
	var root := Node3D.new()
	root.name = "CrateStack"
	root.position = position
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	var offsets: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(_CRATE_SIZE.x * 0.55, 0.0, _CRATE_SIZE.z * 0.2),
		Vector3(_CRATE_SIZE.x * 0.2, _CRATE_SIZE.y, -_CRATE_SIZE.z * 0.1),
	]
	for i in range(offsets.size()):
		var material: StandardMaterial3D = MaterialLibrary.light_metal() if i % 2 == 0 else MaterialLibrary.dark_metal()
		var crate := _add_box(root, "Crate%d" % i, _CRATE_SIZE,
			offsets[i] + Vector3(0.0, _CRATE_SIZE.y * 0.5, 0.0), material)
		crate.rotation_degrees.y = rng.randf_range(-12.0, 12.0)

	return root


## A tall energy spire with pulsing glow rings (named "GlowRing0",
## "GlowRing1", ...) at staggered heights.
static func create_energy_pylon(position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "EnergyPylon"
	root.position = position

	_add_cylinder(root, "Spire", 0.18, 0.3, _PYLON_HEIGHT,
		Vector3(0.0, _PYLON_HEIGHT * 0.5, 0.0), MaterialLibrary.dark_metal())

	for i in range(_PYLON_RING_COUNT):
		var ring_height: float = _PYLON_HEIGHT * (0.4 + 0.35 * float(i))
		var material: StandardMaterial3D = MaterialLibrary.energy_blue() if i % 2 == 0 else MaterialLibrary.energy_red()
		_add_torus(root, "GlowRing%d" % i, 0.35, 0.45, Vector3(0.0, ring_height, 0.0), material)

	_add_cable(root, "BaseCableA", Vector3(0.0, 0.1, 0.0), Vector3(0.9, 0.05, 0.0))
	_add_cable(root, "BaseCableB", Vector3(0.0, 0.1, 0.0), Vector3(-0.5, 0.05, 0.7))

	return root


## A flat road slab between two points with evenly spaced marker lights
## (named "Light0", "Light1", ...) along its length, for readability from
## the fixed camera angle and for the caller's blink animation.
## surface_color tints the slab per map (Iron Basin's darker metal roads,
## ...); Color can't be null, so a zero-alpha color is the "no override"
## sentinel meaning "use the shared default road material".
static func create_road_segment(start: Vector3, end: Vector3, width: float,
		surface_color: Color = Color(0.0, 0.0, 0.0, 0.0)) -> Node3D:
	var root := Node3D.new()
	root.name = "RoadSegment"

	var diff: Vector3 = end - start
	diff.y = 0.0
	var length: float = diff.length()
	if length < 0.01:
		return root

	var center: Vector3 = (start + end) * 0.5
	center.y = _ROAD_HEIGHT * 0.5
	root.position = center
	root.rotation.y = atan2(diff.x, diff.z)

	var surface_material: StandardMaterial3D = MaterialLibrary.terrain_road()
	if surface_color.a > 0.0:
		surface_material = StandardMaterial3D.new()
		surface_material.albedo_color = surface_color
	_add_box(root, "Slab", Vector3(width, _ROAD_HEIGHT, length), Vector3.ZERO, surface_material)

	var light_count: int = max(2, int(length / _ROAD_LIGHT_SPACING))
	for i in range(light_count):
		var t: float = (float(i) + 0.5) / float(light_count)
		var local_z: float = -length * 0.5 + t * length
		for side in [-1.0, 1.0]:
			var local_x: float = side * (width * 0.5 - _ROAD_LIGHT_RADIUS * 1.5)
			_add_sphere(root, "Light%d" % (i * 2 + int((side + 1.0) * 0.5)), _ROAD_LIGHT_RADIUS,
				Vector3(local_x, _ROAD_HEIGHT * 0.5 + _ROAD_LIGHT_RADIUS * 0.5, local_z),
				MaterialLibrary.warning_yellow())

	return root


## A dark, roughly-circular scorch decal flush with the ground -- purely
## visual and always thin enough that it never interferes with movement.
## Raised by _DECAL_GROUND_OFFSET so the decal sits on top of the terrain
## zone tiles instead of being buried inside them.
static func create_scorch_mark(position: Vector3, radius: float) -> Node3D:
	var rng := _rng_for(position)
	var root := Node3D.new()
	root.name = "ScorchMark"
	root.position = position + Vector3(0.0, _DECAL_GROUND_OFFSET + _SCORCH_HEIGHT * 0.5, 0.0)
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	var mesh_instance := _add_cylinder(root, "Scorch", radius, radius * rng.randf_range(0.85, 1.0),
		_SCORCH_HEIGHT, Vector3.ZERO, MaterialLibrary.smoke_dark())
	(mesh_instance.mesh as CylinderMesh).radial_segments = 10

	return root


## A flat industrial deck plate with corner rivets -- factory flooring for
## Iron Basin. Thin enough that units visually drive over it; never blocks.
static func create_metal_plate(position: Vector3) -> Node3D:
	var rng := _rng_for(position)
	var root := Node3D.new()
	root.name = "MetalPlate"
	root.position = position
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	var size: Vector3 = _PLATE_SIZE * rng.randf_range(0.8, 1.15)
	size.y = _PLATE_SIZE.y
	_add_box(root, "Plate", size, Vector3(0.0, size.y * 0.5, 0.0), MaterialLibrary.dark_metal())

	for corner in range(4):
		var sign_x: float = 1.0 if corner % 2 == 0 else -1.0
		var sign_z: float = 1.0 if corner < 2 else -1.0
		_add_sphere(root, "Rivet%d" % corner, _PLATE_RIVET_RADIUS,
			Vector3(sign_x * size.x * 0.42, size.y, sign_z * size.z * 0.42), MaterialLibrary.light_metal())

	return root


## A pair of parallel surface pipes on support blocks, running along the
## prop's local Z with a random yaw. Callers keep length small (<= ~8) so a
## run placed with standard clearance can never reach into a capture zone.
static func create_pipe_run(position: Vector3, length: float = 7.0) -> Node3D:
	var rng := _rng_for(position)
	var root := Node3D.new()
	root.name = "PipeRun"
	root.position = position
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	for pipe_index in range(2):
		var side: float = 1.0 if pipe_index == 0 else -1.0
		var radius: float = _PIPE_RADIUS if pipe_index == 0 else _PIPE_RADIUS * 0.75
		var pipe := _add_cylinder(root, "Pipe%d" % pipe_index, radius, radius, length,
			Vector3(side * 0.3, _PIPE_HEIGHT, 0.0), MaterialLibrary.light_metal())
		pipe.rotation_degrees.x = 90.0

	var support_count: int = 3
	for i in range(support_count):
		var t: float = float(i) / float(support_count - 1)
		var local_z: float = lerpf(-length * 0.5 + 0.4, length * 0.5 - 0.4, t)
		_add_box(root, "Support%d" % i, _PIPE_SUPPORT_SIZE,
			Vector3(0.0, _PIPE_SUPPORT_SIZE.y * 0.5, local_z), MaterialLibrary.dark_metal())

	_add_cylinder(root, "Valve", 0.08, 0.08, 0.4,
		Vector3(0.3, _PIPE_HEIGHT + 0.25, rng.randf_range(-length * 0.3, length * 0.3)),
		MaterialLibrary.dark_metal())

	return root


## A round industrial floor vent glowing from inside. The emissive disc is
## named "PulseCore" so TerrainVisualGenerator's animation pass gives it the
## same slow breathing pulse as power nodes for free.
static func create_glow_vent(position: Vector3) -> Node3D:
	var rng := _rng_for(position)
	var root := Node3D.new()
	root.name = "GlowVent"
	root.position = position
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	_add_cylinder(root, "Grate", _VENT_GRATE_RADIUS, _VENT_GRATE_RADIUS * 1.15, _VENT_GRATE_HEIGHT,
		Vector3(0.0, _VENT_GRATE_HEIGHT * 0.5, 0.0), MaterialLibrary.dark_metal())

	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.emission_enabled = true
	glow_material.albedo_color = _VENT_GLOW_COLOR
	glow_material.emission = _VENT_GLOW_COLOR
	glow_material.emission_energy_multiplier = 1.4
	_add_cylinder(root, "PulseCore", _VENT_GRATE_RADIUS * 0.6, _VENT_GRATE_RADIUS * 0.6, 0.05,
		Vector3(0.0, _VENT_GRATE_HEIGHT + 0.02, 0.0), glow_material)

	# Three bars across the glow so it reads as a grated vent, not a lamp.
	for i in range(3):
		_add_box(root, "Bar%d" % i, Vector3(_VENT_GRATE_RADIUS * 1.1, 0.04, 0.08),
			Vector3(0.0, _VENT_GRATE_HEIGHT + 0.05, (float(i) - 1.0) * 0.35), MaterialLibrary.dark_metal())

	return root


## A dead industrial machine: tilted housing sunk into the ground, a fallen
## drum, loose scrap, and a dying status lamp (named "Light" so the caller's
## animation pass makes it blink).
static func create_broken_machine(position: Vector3) -> Node3D:
	var rng := _rng_for(position)
	var root := Node3D.new()
	root.name = "BrokenMachine"
	root.position = position
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	var housing := _add_box(root, "Housing", _MACHINE_BODY_SIZE,
		Vector3(0.0, _MACHINE_BODY_SIZE.y * 0.38, 0.0), MaterialLibrary.dark_metal())
	housing.rotation_degrees = Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(6.0, 14.0))

	var drum := _add_cylinder(root, "FallenDrum", 0.5, 0.5, 1.6,
		Vector3(1.9, 0.5, rng.randf_range(-0.6, 0.6)), MaterialLibrary.light_metal())
	drum.rotation_degrees = Vector3(90.0, rng.randf_range(0.0, 180.0), 0.0)

	for i in range(3):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(1.4, 2.4)
		var scrap := _add_box(root, "Scrap%d" % i, Vector3(0.4, 0.12, 0.5),
			Vector3(cos(angle) * dist, 0.08, sin(angle) * dist), MaterialLibrary.dark_metal())
		scrap.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	var lamp_material: StandardMaterial3D = MaterialLibrary.energy_red().duplicate()
	lamp_material.emission_energy_multiplier = 0.9
	_add_sphere(root, "Light", 0.12,
		Vector3(-_MACHINE_BODY_SIZE.x * 0.3, _MACHINE_BODY_SIZE.y * 0.85, 0.0), lamp_material)

	return root


## A hazard post with a blinking red beacon (named "Light" for the caller's
## blink pass) -- Ash Line's frontline warning markers.
static func create_warning_light(position: Vector3) -> Node3D:
	var rng := _rng_for(position)
	var root := Node3D.new()
	root.name = "WarningLight"
	root.position = position
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	_add_cylinder(root, "Post", 0.07, 0.1, _WARNING_POST_HEIGHT,
		Vector3(0.0, _WARNING_POST_HEIGHT * 0.5, 0.0), MaterialLibrary.dark_metal())
	_add_box(root, "Stripe", Vector3(0.16, 0.3, 0.16),
		Vector3(0.0, _WARNING_POST_HEIGHT * 0.55, 0.0), MaterialLibrary.warning_yellow())
	_add_box(root, "Head", Vector3(0.3, 0.22, 0.3),
		Vector3(0.0, _WARNING_POST_HEIGHT + 0.05, 0.0), MaterialLibrary.dark_metal())
	_add_sphere(root, "Light", _WARNING_LAMP_RADIUS,
		Vector3(0.0, _WARNING_POST_HEIGHT + 0.28, 0.0), MaterialLibrary.energy_red())

	return root


## The scorched corner of a destroyed building: two charred wall slabs at a
## right angle -- one mostly standing, one collapsed to a stub -- over a
## char patch with rubble spill. Purely visual, like all wreckage.
static func create_ruined_structure(position: Vector3) -> Node3D:
	var rng := _rng_for(position)
	var root := Node3D.new()
	root.name = "RuinedStructure"
	root.position = position
	root.rotation_degrees.y = rng.randf_range(0.0, 360.0)

	var tall_height: float = _RUIN_WALL_HEIGHT * rng.randf_range(0.85, 1.0)
	var tall_wall := _add_box(root, "WallA",
		Vector3(_RUIN_WALL_LENGTH, tall_height, _RUIN_WALL_THICKNESS),
		Vector3(0.0, tall_height * 0.5, 0.0), MaterialLibrary.dark_metal())
	tall_wall.rotation_degrees.z = rng.randf_range(-3.0, 3.0)

	var stub_height: float = _RUIN_WALL_HEIGHT * rng.randf_range(0.3, 0.5)
	_add_box(root, "WallB", Vector3(_RUIN_WALL_THICKNESS, stub_height, _RUIN_WALL_LENGTH),
		Vector3(-_RUIN_WALL_LENGTH * 0.5, stub_height * 0.5, _RUIN_WALL_LENGTH * 0.5),
		MaterialLibrary.dark_metal())

	_add_cylinder(root, "CharPatch", 2.0, 2.0, 0.03,
		Vector3(-0.5, _DECAL_GROUND_OFFSET + 0.015, 0.5), MaterialLibrary.smoke_dark())

	for i in range(3):
		var angle: float = rng.randf_range(0.0, TAU)
		var dist: float = rng.randf_range(0.8, 2.0)
		var rubble := _add_box(root, "Rubble%d" % i, Vector3(0.5, 0.3, 0.45),
			Vector3(cos(angle) * dist - 0.5, 0.15, sin(angle) * dist + 0.5), MaterialLibrary.dark_metal())
		rubble.rotation_degrees = Vector3(rng.randf_range(-10.0, 10.0), rng.randf_range(0.0, 360.0), 0.0)

	return root


## A charred vent mound with a thin, persistent smoke column rising out of
## it -- ambient battlefield haze, not tied to any damage system. Unlike
## SmokePuff (one-shot, self-freeing), this emitter runs for the whole
## match; preprocess makes the column already fully formed when the match
## fades in instead of visibly starting up.
static func create_smoke_column(position: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "SmokeColumn"
	root.position = position

	_add_cylinder(root, "Mound", 0.5, 1.1, 0.5, Vector3(0.0, 0.25, 0.0), MaterialLibrary.smoke_dark())

	var particles := GPUParticles3D.new()
	particles.name = "SmokeEmitter"
	particles.amount = _SMOKE_COLUMN_AMOUNT
	particles.lifetime = _SMOKE_COLUMN_LIFETIME
	particles.preprocess = _SMOKE_COLUMN_LIFETIME
	particles.local_coords = false
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(_SMOKE_COLUMN_PARTICLE_SIZE)
	particles.process_material = _make_smoke_column_material()
	particles.position = Vector3(0.0, 0.45, 0.0)
	root.add_child(particles)

	return root


static func _make_smoke_column_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 8.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 0.9
	# Slight sideways acceleration so the column leans like wind-blown smoke.
	material.gravity = Vector3(0.12, 0.4, 0.0)
	material.scale_min = 0.7
	material.scale_max = 1.5
	material.color_ramp = VFXParticleUtil.make_fade_gradient(_SMOKE_COLUMN_COLOR)
	return material


# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

## Deterministic per-decoration RNG: same world position always yields the
## same internal variation (tilt, offsets, ...), so overall reproducibility
## only depends on TerrainVisualGenerator's placement RNG being seeded from
## GameState.map_seed.
static func _rng_for(position: Vector3) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(position)
	return rng


## Thin cylinder from `from` to `to` (both parent-local). Orients purely via
## local vector math rather than look_at()/global_transform, since these
## decoration subtrees are still detached (not yet added to the scene tree)
## while MapDecorations builds them.
static func _add_cable(parent: Node3D, mesh_name: String, from: Vector3, to: Vector3) -> MeshInstance3D:
	var diff: Vector3 = to - from
	var length: float = diff.length()
	var mesh_instance := _add_cylinder(parent, mesh_name, 0.03, 0.03, max(length, 0.01),
		(from + to) * 0.5, MaterialLibrary.dark_metal())
	if length > 0.01:
		var y_axis: Vector3 = diff.normalized()
		var reference: Vector3 = Vector3.RIGHT if absf(y_axis.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var x_axis: Vector3 = reference.cross(y_axis).normalized()
		var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
		mesh_instance.transform.basis = Basis(x_axis, y_axis, z_axis)
	return mesh_instance


static func _add_box(parent: Node3D, mesh_name: String, size: Vector3, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material)


static func _add_cylinder(parent: Node3D, mesh_name: String, top_radius: float, bottom_radius: float,
		height: float, mesh_position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material)


static func _add_sphere(parent: Node3D, mesh_name: String, radius: float, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material)


static func _add_torus(parent: Node3D, mesh_name: String, inner_radius: float, outer_radius: float,
		mesh_position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material)


static func _add_mesh_instance(parent: Node3D, mesh_name: String, mesh: Mesh, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	parent.add_child(mesh_instance)
	return mesh_instance
