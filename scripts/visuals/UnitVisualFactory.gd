class_name UnitVisualFactory
extends RefCounted
## Builds procedural "final-style" unit visuals out of Godot primitive
## MeshInstance3D nodes (Box/Cylinder/Sphere/Prism/Torus), tinted with
## MaterialLibrary materials. These are procedural final-style placeholder
## models -- meant to be replaceable by authored Blender assets later
## without touching any other system, since Unit.gd only depends on the
## returned root node and the name of its "Hull" child (see Unit.gd's
## _build_visual()).
##
## Dimensions/positions for weapon barrels and missile tubes intentionally
## match each unit .tscn's existing (untouched) Muzzle Marker3D placement,
## so projectiles still originate from roughly the right spot on the new
## geometry.

const _BARREL_ROTATION: Vector3 = Vector3(-90.0, 0.0, 0.0)

const FINAL_ART_ROOT: String = "res://assets/art/final"


## Tries the hand-authored final asset for `file_base` under
## assets/art/final/<subdir>/ -- a .tscn wrapper first (lets artists tune
## materials/offsets in-editor), then a raw .glb -- and returns its
## instantiated root, or null when no final asset exists so callers fall
## back to their procedural build. Shared by BuildingVisualFactory. The
## node-name contract final assets must follow is in ASSET_PIPELINE.md.
static func load_final_visual(file_base: String, subdir: String) -> Node3D:
	for extension in ["tscn", "glb"]:
		var path: String = "%s/%s/%s.%s" % [FINAL_ART_ROOT, subdir, file_base, extension]
		if not ResourceLoader.exists(path):
			continue
		var scene: PackedScene = ResourceLoader.load(path) as PackedScene
		if scene == null:
			continue
		var instance: Node = scene.instantiate()
		if instance is Node3D:
			instance.name = "Visual"
			return instance
		if instance != null:
			instance.free()
	return null


static func create_visual(unit_type: int, team: int) -> Node3D:
	var final_visual: Node3D = load_final_visual(
		Constants.UnitType.keys()[unit_type].to_lower(), "units")
	if final_visual != null:
		return final_visual

	var root := Node3D.new()
	root.name = "Visual"
	match unit_type:
		Constants.UnitType.SCOUT_BUGGY:
			_build_scout_buggy(root, team)
		Constants.UnitType.TANK:
			_build_tank(root, team)
		Constants.UnitType.MISSILE_CRAWLER:
			_build_missile_crawler(root, team)
		Constants.UnitType.ARTILLERY:
			_build_artillery(root, team)
		Constants.UnitType.ANTI_AIR:
			_build_anti_air(root, team)
		Constants.UnitType.SUPPLY_TRUCK:
			_build_supply_truck(root, team)
		Constants.UnitType.CAPTURE_DRONE:
			_build_capture_drone(root, team)
		Constants.UnitType.HEAVY_WALKER:
			_build_heavy_walker(root, team)
		_:
			_build_tank(root, team)
	return root


# ---------------------------------------------------------------------------
# SCOUT_BUGGY -- low fast wedge on four wheels
# ---------------------------------------------------------------------------

static func _build_scout_buggy(root: Node3D, team: int) -> void:
	_add_prism(root, "Hull", Vector3(1.4, 0.5, 2.2), Vector3(0.0, 0.8, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	var wheel_positions: Array[Vector3] = [
		Vector3(0.75, 0.3, 0.8), Vector3(-0.75, 0.3, 0.8),
		Vector3(0.75, 0.3, -0.8), Vector3(-0.75, 0.3, -0.8),
	]
	for i in range(wheel_positions.size()):
		_add_cylinder(root, "Wheel%d" % i, 0.3, 0.3, 0.25, wheel_positions[i],
			MaterialLibrary.dark_metal(), Vector3(0.0, 0.0, 90.0))

	_add_cylinder(root, "Antenna", 0.03, 0.03, 0.5, Vector3(0.0, 1.15, -0.9),
		MaterialLibrary.light_metal())

	_add_box(root, "TeamStripTop", Vector3(0.15, 0.06, 1.8), Vector3(0.0, 1.06, 0.0),
		MaterialLibrary.emissive_for_team(team))

	_add_sphere(root, "EngineGlow", 0.16, Vector3(0.0, 0.7, -1.12),
		MaterialLibrary.emissive_for_team(team))


# ---------------------------------------------------------------------------
# TANK -- wide armored body, turret, short cannon, side plates
# ---------------------------------------------------------------------------

static func _build_tank(root: Node3D, team: int) -> void:
	_add_box(root, "Hull", Vector3(2.0, 0.7, 3.2), Vector3(0.0, 0.75, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	_add_cylinder(root, "TurretBase", 0.6, 0.6, 0.5, Vector3(0.0, 1.35, 0.0),
		MaterialLibrary.light_metal())

	_add_cylinder(root, "Cannon", 0.12, 0.12, 1.6, Vector3(0.0, 1.35, 1.4),
		MaterialLibrary.dark_metal(), _BARREL_ROTATION)

	_add_box(root, "ArmorPlateLeft", Vector3(0.15, 0.5, 2.4), Vector3(1.05, 0.75, 0.0),
		MaterialLibrary.light_metal())
	_add_box(root, "ArmorPlateRight", Vector3(0.15, 0.5, 2.4), Vector3(-1.05, 0.75, 0.0),
		MaterialLibrary.light_metal())

	_add_torus(root, "TurretGlow", 0.56, 0.66, Vector3(0.0, 1.15, 0.0),
		MaterialLibrary.emissive_for_team(team))


# ---------------------------------------------------------------------------
# MISSILE_CRAWLER -- low tracked body, raised rack, 4 missile tubes
# ---------------------------------------------------------------------------

static func _build_missile_crawler(root: Node3D, team: int) -> void:
	_add_box(root, "Hull", Vector3(1.8, 0.5, 2.8), Vector3(0.0, 0.65, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	_add_box(root, "TrackGuardLeft", Vector3(0.2, 0.35, 2.6), Vector3(0.9, 0.4, 0.0),
		MaterialLibrary.dark_metal())
	_add_box(root, "TrackGuardRight", Vector3(0.2, 0.35, 2.6), Vector3(-0.9, 0.4, 0.0),
		MaterialLibrary.dark_metal())

	_add_box(root, "Rack", Vector3(1.4, 0.3, 1.2), Vector3(0.0, 1.05, 0.0),
		MaterialLibrary.light_metal())

	var tube_x_positions: Array[float] = [-0.45, -0.15, 0.15, 0.45]
	for i in range(tube_x_positions.size()):
		var x: float = tube_x_positions[i]
		_add_cylinder(root, "MissileTube%d" % i, 0.1, 0.1, 0.6, Vector3(x, 1.5, 0.0),
			MaterialLibrary.dark_metal())
		_add_sphere(root, "MissileTip%d" % i, 0.11, Vector3(x, 1.85, 0.0),
			MaterialLibrary.warning_yellow())

	_add_box(root, "FinLeft", Vector3(0.06, 0.3, 0.4), Vector3(0.5, 0.75, -1.3),
		MaterialLibrary.light_metal())
	_add_box(root, "FinRight", Vector3(0.06, 0.3, 0.4), Vector3(-0.5, 0.75, -1.3),
		MaterialLibrary.light_metal())

	_add_box(root, "RackGlow", Vector3(1.2, 0.06, 0.15), Vector3(0.0, 0.91, 0.65),
		MaterialLibrary.emissive_for_team(team))


# ---------------------------------------------------------------------------
# ARTILLERY -- long chassis, oversized barrel, rear braces, command cabin
# ---------------------------------------------------------------------------

static func _build_artillery(root: Node3D, team: int) -> void:
	_add_box(root, "Hull", Vector3(1.8, 0.6, 2.4), Vector3(0.0, 0.6, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	_add_cylinder(root, "Barrel", 0.18, 0.18, 3.0, Vector3(0.0, 0.9, 1.5),
		MaterialLibrary.dark_metal(), _BARREL_ROTATION)

	_add_box(root, "BraceLeft", Vector3(0.12, 0.5, 0.12), Vector3(0.7, 0.5, -1.0),
		MaterialLibrary.light_metal())
	_add_box(root, "BraceRight", Vector3(0.12, 0.5, 0.12), Vector3(-0.7, 0.5, -1.0),
		MaterialLibrary.light_metal())

	_add_box(root, "Cabin", Vector3(0.8, 0.5, 0.7), Vector3(0.0, 0.95, -0.7),
		MaterialLibrary.light_metal())
	_add_box(root, "CabinWindow", Vector3(0.6, 0.3, 0.05), Vector3(0.0, 1.0, -1.06),
		MaterialLibrary.glass_dark())


# ---------------------------------------------------------------------------
# ANTI_AIR -- square chassis, turret, twin upward-angled barrels, radar dish
# ---------------------------------------------------------------------------

static func _build_anti_air(root: Node3D, team: int) -> void:
	_add_box(root, "Hull", Vector3(1.8, 0.6, 2.6), Vector3(0.0, 0.6, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	_add_cylinder(root, "TurretBase", 0.5, 0.5, 0.4, Vector3(0.0, 1.1, 0.0),
		MaterialLibrary.light_metal())

	# Angled up from the flat-forward barrel orientation used elsewhere
	# (-90 deg around X) by tilting an extra 20 deg past vertical.
	var angled_rotation := Vector3(-110.0, 0.0, 0.0)
	_add_cylinder(root, "BarrelLeft", 0.1, 0.1, 1.4, Vector3(-0.25, 1.1, 0.9),
		MaterialLibrary.dark_metal(), angled_rotation)
	_add_cylinder(root, "BarrelRight", 0.1, 0.1, 1.4, Vector3(0.25, 1.1, 0.9),
		MaterialLibrary.dark_metal(), angled_rotation)

	_add_cylinder(root, "RadarMast", 0.05, 0.05, 0.6, Vector3(0.0, 1.5, -0.7),
		MaterialLibrary.dark_metal())
	_add_dish(root, "RadarDish", 0.35, Vector3(0.0, 1.85, -0.7), MaterialLibrary.light_metal())

	_add_torus(root, "TurretRingGlow", 0.52, 0.6, Vector3(0.0, 0.88, 0.0),
		MaterialLibrary.emissive_for_team(team))


# ---------------------------------------------------------------------------
# SUPPLY_TRUCK -- boxy support vehicle, cargo canisters, repair dish, glow
# ---------------------------------------------------------------------------

static func _build_supply_truck(root: Node3D, team: int) -> void:
	_add_box(root, "Hull", Vector3(2.0, 1.3, 3.0), Vector3(0.0, 0.95, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	_add_cylinder(root, "CanisterLeft", 0.3, 0.3, 0.8, Vector3(0.5, 1.95, -0.8),
		MaterialLibrary.light_metal())
	_add_cylinder(root, "CanisterRight", 0.3, 0.3, 0.8, Vector3(-0.5, 1.95, -0.8),
		MaterialLibrary.light_metal())

	_add_cylinder(root, "DishMast", 0.05, 0.05, 0.5, Vector3(0.0, 1.85, 1.2),
		MaterialLibrary.dark_metal())
	_add_dish(root, "RepairDish", 0.3, Vector3(0.0, 2.15, 1.2), MaterialLibrary.light_metal())

	# Glowing plus/cross icon: two thin rectangular meshes, matching the
	# game's medic-cross convention -- uses the shared energy_blue accent
	# rather than the team body color, so it reads as "support" regardless
	# of which side owns the truck.
	_add_box(root, "CrossHorizontal", Vector3(1.0, 0.08, 0.3), Vector3(0.0, 1.65, 0.0),
		MaterialLibrary.energy_blue())
	_add_box(root, "CrossVertical", Vector3(0.3, 0.08, 1.0), Vector3(0.0, 1.65, 0.0),
		MaterialLibrary.energy_blue())

	# Soft support-glow strip along the lower hull, distinct from combat
	# units' team-emissive strips.
	_add_box(root, "SupportGlowStrip", Vector3(2.02, 0.05, 0.15), Vector3(0.0, 0.35, 1.45),
		MaterialLibrary.energy_blue())


# ---------------------------------------------------------------------------
# CAPTURE_DRONE -- small fragile utility craft, antenna, capture emitter
# ---------------------------------------------------------------------------

static func _build_capture_drone(root: Node3D, team: int) -> void:
	_add_sphere(root, "Hull", 0.45, Vector3(0.0, 0.5, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	_add_cylinder(root, "Antenna", 0.04, 0.04, 0.5, Vector3(0.0, 1.2, 0.0),
		MaterialLibrary.light_metal())
	_add_sphere(root, "AntennaTip", 0.08, Vector3(0.0, 1.53, 0.0),
		MaterialLibrary.emissive_for_team(team))

	# Capture emitter ring wraps the equator of the hull, distinct in size
	# and height from Unit.gd's generic ground-level team strip so the two
	# don't visually overlap.
	_add_torus(root, "CaptureEmitter", 0.5, 0.58, Vector3(0.0, 0.5, 0.0),
		MaterialLibrary.emissive_for_team(team))

	_add_sphere(root, "TeamCore", 0.12, Vector3(0.0, 0.5, 0.35),
		MaterialLibrary.emissive_for_team(team))


# ---------------------------------------------------------------------------
# HEAVY_WALKER -- large body, chunky legs, shoulder armor, arm cannon
# ---------------------------------------------------------------------------

static func _build_heavy_walker(root: Node3D, team: int) -> void:
	_add_box(root, "Hull", Vector3(2.6, 1.2, 3.0), Vector3(0.0, 2.0, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	_add_box(root, "LegLeft", Vector3(0.6, 1.4, 0.6), Vector3(0.8, 0.7, 0.0),
		MaterialLibrary.dark_metal())
	_add_box(root, "LegRight", Vector3(0.6, 1.4, 0.6), Vector3(-0.8, 0.7, 0.0),
		MaterialLibrary.dark_metal())

	_add_box(root, "ShoulderLeft", Vector3(0.7, 0.5, 1.2), Vector3(1.5, 2.5, 0.0),
		MaterialLibrary.light_metal())
	_add_box(root, "ShoulderRight", Vector3(0.7, 0.5, 1.2), Vector3(-1.5, 2.5, 0.0),
		MaterialLibrary.light_metal())

	_add_cylinder(root, "ArmCannon", 0.22, 0.22, 1.6, Vector3(0.0, 2.0, 0.6),
		MaterialLibrary.dark_metal(), _BARREL_ROTATION)

	_add_box(root, "TeamPanelLeft", Vector3(0.5, 0.7, 0.05), Vector3(0.9, 2.0, 1.52),
		MaterialLibrary.emissive_for_team(team))
	_add_box(root, "TeamPanelRight", Vector3(0.5, 0.7, 0.05), Vector3(-0.9, 2.0, 1.52),
		MaterialLibrary.emissive_for_team(team))


# ---------------------------------------------------------------------------
# Primitive-building helpers
# ---------------------------------------------------------------------------

static func _add_box(parent: Node3D, mesh_name: String, size: Vector3, mesh_position: Vector3,
		material: StandardMaterial3D, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material, rotation_deg)


static func _add_cylinder(parent: Node3D, mesh_name: String, top_radius: float, bottom_radius: float,
		height: float, mesh_position: Vector3, material: StandardMaterial3D,
		rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material, rotation_deg)


static func _add_sphere(parent: Node3D, mesh_name: String, radius: float, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material)


static func _add_prism(parent: Node3D, mesh_name: String, size: Vector3, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material)


static func _add_torus(parent: Node3D, mesh_name: String, inner_radius: float, outer_radius: float,
		mesh_position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material)


## A shallow, flattened sphere used for radar/repair dishes.
static func _add_dish(parent: Node3D, mesh_name: String, radius: float, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var dish := _add_sphere(parent, mesh_name, radius, mesh_position, material)
	dish.scale.y = 0.35
	return dish


static func _add_mesh_instance(parent: Node3D, mesh_name: String, mesh: Mesh, mesh_position: Vector3,
		material: StandardMaterial3D, rotation_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	if rotation_deg != Vector3.ZERO:
		mesh_instance.rotation_degrees = rotation_deg
	parent.add_child(mesh_instance)
	return mesh_instance
