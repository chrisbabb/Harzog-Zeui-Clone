class_name BuildingVisualFactory
extends RefCounted
## Builds procedural "final-style" building visuals out of Godot primitive
## MeshInstance3D nodes, tinted with MaterialLibrary materials. These are
## procedural final-style placeholder models -- meant to be replaceable by
## authored Blender assets later without touching any other system.
##
## Base.gd/Outpost.gd only depend on the returned root node and the names
## of specific children: "Hull" (the flashable/recolorable main structure,
## on both) and "CaptureRing" (the animated capture ring, outpost only).


static func create_hq_visual(team: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"

	_add_box(root, "Platform", Vector3(9.0, 0.6, 9.0), Vector3(0.0, 0.3, 0.0),
		MaterialLibrary.light_metal())

	_add_box(root, "Hull", Vector3(6.0, 4.0, 6.0), Vector3(0.0, 2.6, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	_add_cylinder(root, "Tower", 2.0, 2.5, 6.0, Vector3(0.0, 7.6, 0.0),
		MaterialLibrary.light_metal())

	_add_sphere(root, "PowerCore", 1.0, Vector3(0.0, 11.0, 0.0),
		MaterialLibrary.emissive_for_team(team))

	_add_cylinder(root, "RadarMast", 0.08, 0.08, 2.5, Vector3(1.4, 12.0, 0.0),
		MaterialLibrary.dark_metal())
	_add_dish(root, "RadarDish", 0.5, Vector3(1.4, 13.3, 0.0), MaterialLibrary.light_metal())

	_add_box(root, "ProductionBayDoor", Vector3(2.0, 2.5, 0.15), Vector3(0.0, 2.6, 3.05),
		MaterialLibrary.dark_metal())

	const WALL_BLOCK_COUNT: int = 6
	const WALL_BLOCK_RADIUS: float = 4.3
	for i in range(WALL_BLOCK_COUNT):
		var angle: float = TAU * float(i) / float(WALL_BLOCK_COUNT)
		var block_position := Vector3(cos(angle) * WALL_BLOCK_RADIUS, 0.75, sin(angle) * WALL_BLOCK_RADIUS)
		_add_box(root, "WallBlock%d" % i, Vector3(0.6, 0.5, 0.6), block_position,
			MaterialLibrary.light_metal())

	_add_box(root, "BannerLeft", Vector3(0.05, 2.0, 0.6), Vector3(3.05, 2.6, 0.0),
		MaterialLibrary.emissive_for_team(team))
	_add_box(root, "BannerRight", Vector3(0.05, 2.0, 0.6), Vector3(-3.05, 2.6, 0.0),
		MaterialLibrary.emissive_for_team(team))

	return root


static func create_outpost_visual(team: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"

	var platform := _add_cylinder(root, "Platform", 4.2, 4.4, 0.4, Vector3(0.0, 0.2, 0.0),
		MaterialLibrary.light_metal())
	(platform.mesh as CylinderMesh).radial_segments = 6

	_add_cylinder(root, "Hull", 1.0, 1.3, 4.0, Vector3(0.0, 2.4, 0.0),
		MaterialLibrary.body_for_team(team).duplicate())

	# Duplicated (not shared) since BuildingAnimator mutates this material's
	# emission_energy_multiplier every frame -- the ownership core below
	# intentionally points at the same instance so it pulses in sync with
	# the ring rather than needing its own tween.
	var ring_material: StandardMaterial3D = MaterialLibrary.emissive_for_team(team).duplicate()
	_add_torus(root, "CaptureRing", 5.5, 6.0, Vector3(0.0, 0.45, 0.0), ring_material)
	_add_sphere(root, "OwnershipCore", 0.5, Vector3(0.0, 4.9, 0.0), ring_material)

	_add_cylinder(root, "Antenna", 0.06, 0.06, 2.0, Vector3(0.0, 5.4, 0.0),
		MaterialLibrary.dark_metal())
	_add_sphere(root, "AntennaTip", 0.12, Vector3(0.0, 6.5, 0.0),
		MaterialLibrary.emissive_for_team(team))

	# Matches UnitSpawnPoint's (4, 0, 4) position in Outpost.tscn -- a
	# separate small pad rather than part of the main platform, since the
	# spawn point sits outside the platform's radius.
	_add_cylinder(root, "LandingPad", 1.2, 1.2, 0.15, Vector3(4.0, 0.075, 4.0),
		MaterialLibrary.dark_metal())

	return root


# ---------------------------------------------------------------------------
# Primitive-building helpers (mirrors UnitVisualFactory's)
# ---------------------------------------------------------------------------

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


static func _add_torus(parent: Node3D, mesh_name: String, inner_radius: float,
		outer_radius: float, mesh_position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	return _add_mesh_instance(parent, mesh_name, mesh, mesh_position, material)


## A shallow, flattened sphere used for the radar dish.
static func _add_dish(parent: Node3D, mesh_name: String, radius: float, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var dish := _add_sphere(parent, mesh_name, radius, mesh_position, material)
	dish.scale.y = 0.35
	return dish


static func _add_mesh_instance(parent: Node3D, mesh_name: String, mesh: Mesh, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	mesh_instance.position = mesh_position
	parent.add_child(mesh_instance)
	return mesh_instance
