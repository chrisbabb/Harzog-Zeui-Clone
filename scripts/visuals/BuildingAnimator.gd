class_name BuildingAnimator
extends RefCounted
## Per-building procedural animation controller, mirroring UnitAnimator's
## pattern: one instance per HQ/Outpost, created in _build_visual() and
## driven every physics frame via update() from the owning script's existing
## _physics_process(). Reads named parts on the Visual root that
## BuildingVisualFactory built ("Hull", "PowerCore", "RadarDish",
## "ProductionBayDoor" on the HQ; "Hull", "CaptureRing" on the Outpost).
##
## This is procedural final-style placeholder animation -- meant to be
## replaceable by authored assets later without touching Base.gd/Outpost.gd
## beyond the handful of call sites documented there.

const CORE_PULSE_SPEED: float = 1.8
const CORE_PULSE_SCALE: float = 0.06
const CORE_PULSE_EMISSION_BASE: float = 1.6
const CORE_PULSE_EMISSION_AMPLITUDE: float = 0.6

const RADAR_SPIN_SPEED: float = 1.6

const BAY_DOOR_GLOW_SPEED: float = 4.0
const BAY_DOOR_IDLE_ENERGY: float = 0.0
const BAY_DOOR_ACTIVE_ENERGY: float = 2.2

const RING_ROTATION_SPEED: float = 0.4
const RING_PULSE_SPEED: float = 6.0
const RING_PULSE_SCALE: float = 0.08
const RING_PULSE_EMISSION_BASE: float = 1.5
const RING_PULSE_EMISSION_AMPLITUDE: float = 0.5
const RING_IDLE_PULSE_SPEED: float = 1.2
const RING_IDLE_PULSE_AMPLITUDE: float = 0.15
const RING_IDLE_SCALE_AMPLITUDE: float = 0.02
const PROGRESS_EMISSION_BONUS: float = 1.5
const CONTESTED_FLASH_SPEED: float = 10.0

var _visual_root: Node3D
var _building_kind: int = Constants.BuildingType.HQ
var _team: int = Constants.Team.NEUTRAL
var _time: float = 0.0

var _hull_material: StandardMaterial3D
var _flash_remaining: float = 0.0

# HQ
var _power_core: Node3D = null
var _power_core_material: StandardMaterial3D
var _radar_dish: Node3D = null
var _bay_door_material: StandardMaterial3D
var _bay_door_glow: float = 0.0

# Outpost
var _ring_mesh: MeshInstance3D = null
var _ring_material: StandardMaterial3D


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(visual_root: Node3D, building_kind: int, team: int) -> void:
	_visual_root = visual_root
	_building_kind = building_kind
	_team = team

	var hull: MeshInstance3D = _visual_root.get_node_or_null("Hull")
	if hull != null:
		_hull_material = hull.material_override as StandardMaterial3D

	if building_kind == Constants.BuildingType.HQ:
		_setup_hq()
	else:
		_setup_outpost()


func _setup_hq() -> void:
	_power_core = _visual_root.get_node_or_null("PowerCore")
	if _power_core != null:
		_power_core_material = (_power_core as MeshInstance3D).material_override as StandardMaterial3D

	_radar_dish = _visual_root.get_node_or_null("RadarDish")

	var bay_door: MeshInstance3D = _visual_root.get_node_or_null("ProductionBayDoor")
	if bay_door != null:
		# ProductionBayDoor shares MaterialLibrary.dark_metal() by default --
		# duplicate before enabling emission so glowing one HQ's bay door
		# doesn't light up every dark-metal part in the game.
		var mat: StandardMaterial3D = (bay_door.material_override as StandardMaterial3D).duplicate()
		mat.emission_enabled = true
		mat.emission = MaterialLibrary.emissive_for_team(_team).albedo_color
		mat.emission_energy_multiplier = BAY_DOOR_IDLE_ENERGY
		bay_door.material_override = mat
		_bay_door_material = mat


func _setup_outpost() -> void:
	_ring_mesh = _visual_root.get_node_or_null("CaptureRing")
	if _ring_mesh != null:
		_ring_material = _ring_mesh.material_override as StandardMaterial3D


# ---------------------------------------------------------------------------
# Per-frame update
# ---------------------------------------------------------------------------

## is_producing/is_contested/capture_progress are only meaningful for their
## respective building kind and are cheap to pass unconditionally. hp_ratio
## is kept in the signature for call-site stability but damage visuals now
## live in DamageStateController, which polls the same ratio itself.
func update(delta: float, _hp_ratio: float, is_producing: bool = false, is_contested: bool = false, is_being_captured: bool = false, capture_progress: float = 0.0) -> void:
	_time += delta
	_update_flash(delta)
	if _building_kind == Constants.BuildingType.HQ:
		_update_hq(delta, is_producing)
	else:
		_update_outpost(delta, is_contested, is_being_captured, capture_progress)


func _update_flash(delta: float) -> void:
	if _hull_material == null or _flash_remaining <= 0.0:
		return
	_flash_remaining -= delta
	_hull_material.albedo_color = Constants.DAMAGE_FLASH_COLOR if _flash_remaining > 0.0 else Constants.team_color(_team)


# ---------------------------------------------------------------------------
# HQ: core pulse, radar spin, bay door glow
# ---------------------------------------------------------------------------

func _update_hq(delta: float, is_producing: bool) -> void:
	if _power_core != null:
		var pulse: float = sin(_time * CORE_PULSE_SPEED)
		_power_core.scale = Vector3.ONE * (1.0 + pulse * CORE_PULSE_SCALE)
		if _power_core_material != null:
			_power_core_material.emission_energy_multiplier = CORE_PULSE_EMISSION_BASE + pulse * CORE_PULSE_EMISSION_AMPLITUDE

	if _radar_dish != null:
		_radar_dish.rotate_y(RADAR_SPIN_SPEED * delta)

	if _bay_door_material != null:
		var target_energy: float = BAY_DOOR_ACTIVE_ENERGY if is_producing else BAY_DOOR_IDLE_ENERGY
		_bay_door_glow = move_toward(_bay_door_glow, target_energy, BAY_DOOR_GLOW_SPEED * delta)
		_bay_door_material.emission_energy_multiplier = _bay_door_glow


# ---------------------------------------------------------------------------
# Outpost: ring rotation/pulse, contested flash, capture-progress brightness
# ---------------------------------------------------------------------------

func _update_outpost(delta: float, is_contested: bool, is_being_captured: bool, capture_progress: float) -> void:
	if _ring_mesh == null or _ring_material == null:
		return

	_ring_mesh.rotate_y(RING_ROTATION_SPEED * delta)

	if is_contested:
		var flash: float = (sin(_time * CONTESTED_FLASH_SPEED) + 1.0) * 0.5
		var warning_color: Color = MaterialLibrary.warning_yellow().albedo_color
		_ring_material.albedo_color = warning_color
		_ring_material.emission = warning_color
		_ring_material.emission_energy_multiplier = RING_PULSE_EMISSION_BASE + flash * RING_PULSE_EMISSION_AMPLITUDE
		_ring_mesh.scale = Vector3.ONE * (1.0 + flash * RING_PULSE_SCALE)
		return

	# Not contested this frame: re-assert the team-accurate color in case a
	# prior contested flash left albedo/emission on warning_yellow.
	var emissive_source: StandardMaterial3D = MaterialLibrary.emissive_for_team(_team)
	_ring_material.albedo_color = emissive_source.albedo_color
	_ring_material.emission = emissive_source.emission

	# Trigger is live occupancy (is_being_captured), not capture_progress --
	# progress is a one-way accumulator that only resets on a completed
	# capture, so using it as the pulse trigger would leave the ring pulsing
	# "under attack" forever after a capturer merely leaves without finishing.
	# Progress still modulates brightness while a capture is actually live.
	if is_being_captured:
		var pulse: float = sin(_time * RING_PULSE_SPEED)
		_ring_mesh.scale = Vector3.ONE * (1.0 + pulse * RING_PULSE_SCALE)
		_ring_material.emission_energy_multiplier = RING_PULSE_EMISSION_BASE + pulse * RING_PULSE_EMISSION_AMPLITUDE + capture_progress * PROGRESS_EMISSION_BONUS
		return

	# Idle heartbeat so a settled, uncontested outpost still reads as "alive"
	# (ring + OwnershipCore, which shares this same material -- see
	# BuildingVisualFactory) instead of going fully static.
	var idle_pulse: float = sin(_time * RING_IDLE_PULSE_SPEED)
	_ring_mesh.scale = Vector3.ONE * (1.0 + idle_pulse * RING_IDLE_SCALE_AMPLITUDE)
	_ring_material.emission_energy_multiplier = 1.0 + idle_pulse * RING_IDLE_PULSE_AMPLITUDE


# ---------------------------------------------------------------------------
# Public event hooks (called from Base.gd / Outpost.gd)
# ---------------------------------------------------------------------------

func on_damaged() -> void:
	_flash_remaining = Constants.DAMAGE_FLASH_DURATION
	VFXManager.spawn_damage_sparks(_visual_root.global_position, _team)


## Re-tints the hull (and, for an Outpost, the capture ring/ownership core)
## for a new owning team -- called on spawn and whenever an Outpost is
## recaptured. Replaces the material-mutation body Base.gd/Outpost.gd used
## to carry directly in their own update_team_material().
func set_team(team: int) -> void:
	_team = team
	if _hull_material != null:
		_hull_material.albedo_color = Constants.team_color(_team)
	if _ring_material != null:
		var emissive_source: StandardMaterial3D = MaterialLibrary.emissive_for_team(_team)
		_ring_material.albedo_color = emissive_source.albedo_color
		_ring_material.emission = emissive_source.emission
	if _bay_door_material != null:
		_bay_door_material.emission = MaterialLibrary.emissive_for_team(_team).albedo_color
