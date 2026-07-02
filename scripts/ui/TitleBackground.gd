extends Node3D
## Decorative animated battlefield diorama rendered behind the title menu
## (instanced by MainMenu.tscn). Built entirely from the same
## UnitVisualFactory/BuildingVisualFactory/MaterialLibrary visuals the game
## uses -- but as bare mesh trees with no gameplay scripts, physics bodies,
## groups, signals, or GameState/EventBus access, so the title screen can
## never start (or disturb) an actual match. All motion here is scripted
## lerps and sine drifts in _process: a slow camera pan, an enemy convoy
## crossing the far road, pulsing outpost capture rings, drifting
## dust/smoke, and an occasional commander flyby.

# Camera drift: two different sine periods on x/z so the pan never visibly
# reverses on the spot or repeats too obviously.
const CAMERA_PAN_AMPLITUDE_X: float = 9.0
const CAMERA_PAN_AMPLITUDE_Z: float = 4.5
const CAMERA_PAN_SPEED: float = 0.03  # cycles/sec -> one full drift ~33s

# Outpost capture-ring pulse.
const RING_PULSE_SPEED: float = 0.4
const RING_SCALE_AMPLITUDE: float = 0.06
const RING_EMISSION_AMPLITUDE: float = 0.35
const RING_BASE_EMISSION: float = 1.6  # mirrors MaterialLibrary's emissive energy

# Distant enemy convoy, driving along the far supply road.
const CONVOY_Z: float = -30.0
const CONVOY_SPAN: float = 55.0  # wrap point, well outside the camera frame
const CONVOY_SPACING: float = 8.0
const CONVOY_SPEED: float = 1.6

# Occasional commander flyby.
const FLYBY_HEIGHT: float = 7.5
const FLYBY_DURATION: float = 8.0
const FLYBY_INTERVAL_MIN: float = 7.0
const FLYBY_INTERVAL_MAX: float = 14.0
const FLYBY_FIRST_DELAY_MIN: float = 2.0
const FLYBY_FIRST_DELAY_MAX: float = 5.0
const FLYBY_BANK_ANGLE: float = 0.16
const FLYBY_BOB_AMPLITUDE: float = 0.35
const FLYBY_BOB_SPEED: float = 2.2

@onready var _camera_rig: Node3D = $CameraRig

var _time: float = 0.0
# Each entry: {"mesh": MeshInstance3D, "material": StandardMaterial3D, "phase": float}.
# The material is the per-outpost duplicate BuildingVisualFactory already
# makes for its CaptureRing/OwnershipCore pair, so mutating it here never
# touches MaterialLibrary's shared cached instances.
var _rings: Array[Dictionary] = []
var _convoy: Array[Node3D] = []
var _flyby: Node3D = null
var _flyby_timer: float = 0.0
var _flyby_progress: float = -1.0  # < 0 while idle/hidden
var _flyby_from: Vector3 = Vector3.ZERO
var _flyby_to: Vector3 = Vector3.ZERO


func _ready() -> void:
	_build_terrain()
	_build_buildings()
	_build_parked_defenders()
	_build_convoy()
	_build_flyby_aircraft()
	_build_ruins_and_smoke()
	_build_dust_motes()
	_flyby_timer = randf_range(FLYBY_FIRST_DELAY_MIN, FLYBY_FIRST_DELAY_MAX)


func _process(delta: float) -> void:
	_time += delta
	_update_camera()
	_update_rings()
	_update_convoy(delta)
	_update_flyby(delta)


# ---------------------------------------------------------------------------
# Diorama construction
# ---------------------------------------------------------------------------

func _build_terrain() -> void:
	_add_box(self, Vector3(150.0, 1.0, 110.0), Vector3(0.0, -0.5, 0.0),
		MaterialLibrary.terrain_grass())

	# Dirt clearings under each HQ.
	_add_cylinder(self, 11.0, 0.1, Vector3(-14.0, 0.03, 6.0), MaterialLibrary.terrain_dirt())
	_add_cylinder(self, 11.0, 0.1, Vector3(34.0, 0.03, -26.0), MaterialLibrary.terrain_dirt())

	# Far supply road the enemy convoy drives along, plus a spur toward the
	# middle of the diorama.
	_add_box(self, Vector3(140.0, 0.06, 3.2), Vector3(0.0, 0.03, CONVOY_Z),
		MaterialLibrary.terrain_road())
	var spur: MeshInstance3D = _add_box(self, Vector3(3.0, 0.06, 34.0),
		Vector3(-6.0, 0.02, -12.0), MaterialLibrary.terrain_road())
	spur.rotation.y = 0.35


func _build_buildings() -> void:
	var player_hq: Node3D = BuildingVisualFactory.create_hq_visual(Constants.Team.PLAYER)
	player_hq.position = Vector3(-14.0, 0.0, 6.0)
	player_hq.rotation.y = 0.6
	add_child(player_hq)

	# Far corner, mostly swallowed by fog -- reads as "enemy territory over
	# the horizon" rather than a symmetric mirror base.
	var enemy_hq: Node3D = BuildingVisualFactory.create_hq_visual(Constants.Team.ENEMY)
	enemy_hq.position = Vector3(34.0, 0.0, -26.0)
	enemy_hq.rotation.y = -2.2
	add_child(enemy_hq)

	_add_outpost(Vector3(4.0, 0.0, -6.0), Constants.Team.PLAYER, 0.0)
	_add_outpost(Vector3(-4.0, 0.0, -22.0), Constants.Team.NEUTRAL, 2.1)
	_add_outpost(Vector3(20.0, 0.0, -14.0), Constants.Team.ENEMY, 4.2)


func _add_outpost(outpost_position: Vector3, team: int, ring_phase: float) -> void:
	var visual: Node3D = BuildingVisualFactory.create_outpost_visual(team)
	visual.position = outpost_position
	add_child(visual)

	var ring := visual.find_child("CaptureRing", true, false) as MeshInstance3D
	if ring == null:
		return
	var material := ring.material_override as StandardMaterial3D
	if material == null:
		return
	_rings.append({"mesh": ring, "material": material, "phase": ring_phase})


func _build_parked_defenders() -> void:
	_add_unit_visual(Constants.UnitType.TANK, Constants.Team.PLAYER, Vector3(-8.0, 0.0, 11.0), 1.9)
	_add_unit_visual(Constants.UnitType.ANTI_AIR, Constants.Team.PLAYER, Vector3(-12.0, 0.0, 0.0), 0.4)
	_add_unit_visual(Constants.UnitType.SUPPLY_TRUCK, Constants.Team.PLAYER, Vector3(-6.5, 0.0, 3.5), -1.2)


func _build_convoy() -> void:
	var types: Array[int] = [
		Constants.UnitType.TANK,
		Constants.UnitType.HEAVY_WALKER,
		Constants.UnitType.MISSILE_CRAWLER,
		Constants.UnitType.TANK,
	]
	var lane_offsets: Array[float] = [0.0, 1.1, -0.9, 0.4]
	for i in range(types.size()):
		var visual: Node3D = _add_unit_visual(types[i], Constants.Team.ENEMY,
			Vector3(-CONVOY_SPAN + float(i) * CONVOY_SPACING, 0.0, CONVOY_Z + lane_offsets[i]), 0.0)
		_face_direction(visual, Vector3.RIGHT)
		_convoy.append(visual)


func _add_unit_visual(unit_type: int, team: int, unit_position: Vector3, yaw: float) -> Node3D:
	var visual: Node3D = UnitVisualFactory.create_visual(unit_type, team)
	visual.position = unit_position
	visual.rotation.y = yaw
	add_child(visual)
	return visual


## A simple stylized aircraft echoing Commander.tscn's AirMesh silhouette
## (same PrismMesh proportions) with wings and cyan emissive strips, kept
## hidden between flybys.
func _build_flyby_aircraft() -> void:
	_flyby = Node3D.new()
	_flyby.name = "FlybyCommander"

	var fuselage := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.6, 0.6, 2.6)
	fuselage.mesh = prism
	fuselage.material_override = MaterialLibrary.body_for_team(Constants.Team.PLAYER)
	_flyby.add_child(fuselage)

	_add_box(_flyby, Vector3(3.6, 0.1, 1.0), Vector3(0.0, 0.0, 0.4), MaterialLibrary.light_metal())
	_add_box(_flyby, Vector3(0.18, 0.12, 1.3), Vector3(1.7, 0.0, 0.45),
		MaterialLibrary.emissive_for_team(Constants.Team.PLAYER))
	_add_box(_flyby, Vector3(0.18, 0.12, 1.3), Vector3(-1.7, 0.0, 0.45),
		MaterialLibrary.emissive_for_team(Constants.Team.PLAYER))
	_add_sphere(_flyby, 0.2, Vector3(0.0, 0.05, 1.5), MaterialLibrary.energy_blue())

	_flyby.scale = Vector3.ONE * 1.3
	_flyby.visible = false
	add_child(_flyby)


func _build_ruins_and_smoke() -> void:
	_build_ruin(Vector3(10.0, 0.0, 14.0), 0.5)
	_build_ruin(Vector3(24.0, 0.0, -4.0), 2.4)


func _build_ruin(ruin_position: Vector3, yaw: float) -> void:
	var ruin := Node3D.new()
	ruin.position = ruin_position
	ruin.rotation.y = yaw
	add_child(ruin)

	var slab: MeshInstance3D = _add_box(ruin, Vector3(2.6, 1.8, 2.2), Vector3(0.0, 0.5, 0.0),
		MaterialLibrary.dark_metal())
	slab.rotation = Vector3(0.14, 0.3, -0.18)
	_add_box(ruin, Vector3(1.0, 0.5, 0.8), Vector3(1.7, 0.25, 0.6), MaterialLibrary.dark_metal())
	_add_box(ruin, Vector3(0.6, 0.35, 0.7), Vector3(-1.4, 0.18, -0.9), MaterialLibrary.light_metal())

	ruin.add_child(_make_smoke_column())


func _make_smoke_column() -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 12
	particles.lifetime = 4.5
	# Pre-simulated so the column is already formed on the first visible
	# frame instead of "switching on" as the menu appears.
	particles.preprocess = 4.5
	particles.position = Vector3(0.0, 1.2, 0.0)
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(0.9)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 7.0
	material.initial_velocity_min = 0.6
	material.initial_velocity_max = 1.0
	material.gravity = Vector3(0.25, 0.35, 0.1)  # buoyant rise with light wind shear
	material.scale_min = 0.8
	material.scale_max = 1.7
	material.color_ramp = VFXParticleUtil.make_fade_gradient(Color(0.16, 0.16, 0.18, 0.5))
	particles.process_material = material
	return particles


## A large, sparse box of slow cyan-tinted motes drifting across the whole
## diorama -- reads as atmosphere/ash without implying any gameplay event.
func _build_dust_motes() -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 28
	particles.lifetime = 9.0
	particles.preprocess = 9.0
	particles.position = Vector3(0.0, 4.0, -4.0)
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(0.14)

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(36.0, 5.0, 26.0)
	material.direction = Vector3(1.0, 0.06, 0.3)
	material.spread = 12.0
	material.initial_velocity_min = 0.2
	material.initial_velocity_max = 0.45
	material.gravity = Vector3.ZERO
	material.color_ramp = VFXParticleUtil.make_fade_gradient(Color(0.6, 0.85, 1.0, 0.22))
	particles.process_material = material
	add_child(particles)


# ---------------------------------------------------------------------------
# Per-frame animation
# ---------------------------------------------------------------------------

func _update_camera() -> void:
	_camera_rig.position = Vector3(
		sin(_time * CAMERA_PAN_SPEED * TAU) * CAMERA_PAN_AMPLITUDE_X,
		0.0,
		cos(_time * CAMERA_PAN_SPEED * 0.7 * TAU) * CAMERA_PAN_AMPLITUDE_Z
	)


func _update_rings() -> void:
	for entry in _rings:
		var wave: float = sin(_time * RING_PULSE_SPEED * TAU + entry["phase"])
		var ring_scale: float = 1.0 + RING_SCALE_AMPLITUDE * wave
		(entry["mesh"] as MeshInstance3D).scale = Vector3(ring_scale, 1.0, ring_scale)
		(entry["material"] as StandardMaterial3D).emission_energy_multiplier = \
			RING_BASE_EMISSION * (1.0 + RING_EMISSION_AMPLITUDE * wave)


func _update_convoy(delta: float) -> void:
	for visual in _convoy:
		visual.position.x += CONVOY_SPEED * delta
		if visual.position.x > CONVOY_SPAN:
			visual.position.x -= CONVOY_SPAN * 2.0


func _update_flyby(delta: float) -> void:
	if _flyby_progress < 0.0:
		_flyby_timer -= delta
		if _flyby_timer <= 0.0:
			_start_flyby()
		return

	_flyby_progress += delta / FLYBY_DURATION
	if _flyby_progress >= 1.0:
		_flyby_progress = -1.0
		_flyby.visible = false
		_flyby_timer = randf_range(FLYBY_INTERVAL_MIN, FLYBY_INTERVAL_MAX)
		return

	var flyby_position: Vector3 = _flyby_from.lerp(_flyby_to, _flyby_progress)
	flyby_position.y += sin(_time * FLYBY_BOB_SPEED) * FLYBY_BOB_AMPLITUDE
	_flyby.position = flyby_position


func _start_flyby() -> void:
	var z_offset: float = randf_range(-6.0, 6.0)
	_flyby_from = Vector3(-44.0, FLYBY_HEIGHT, 16.0 + z_offset)
	_flyby_to = Vector3(44.0, FLYBY_HEIGHT, -20.0 + z_offset)
	if randf() < 0.5:
		var swap: Vector3 = _flyby_from
		_flyby_from = _flyby_to
		_flyby_to = swap

	_flyby_progress = 0.0
	_flyby.position = _flyby_from
	_face_direction(_flyby, _flyby_to - _flyby_from)
	_flyby.rotation.z = FLYBY_BANK_ANGLE if _flyby_to.x > _flyby_from.x else -FLYBY_BANK_ANGLE
	_flyby.visible = true


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Yaws `node` so its -Z forward axis points along `direction` (the same
## forward convention the commander/unit visuals use).
static func _face_direction(node: Node3D, direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	node.rotation.y = atan2(-direction.x, -direction.z)


static func _add_box(parent: Node3D, size: Vector3, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, mesh, mesh_position, material)


static func _add_cylinder(parent: Node3D, radius: float, height: float, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _add_mesh(parent, mesh, mesh_position, material)


static func _add_sphere(parent: Node3D, radius: float, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _add_mesh(parent, mesh, mesh_position, material)


static func _add_mesh(parent: Node3D, mesh: Mesh, mesh_position: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = mesh_position
	parent.add_child(instance)
	return instance
