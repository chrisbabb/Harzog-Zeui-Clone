class_name DamageStateController
extends RefCounted
## Health-driven damage visuals for units and buildings, layered on top of
## UnitAnimator/BuildingAnimator (which keep owning idle/combat animation and
## the on-hit flash). One instance per unit/HQ/outpost, created next to the
## animator and driven from the host's existing _physics_process via
## update(delta, hp_ratio).
##
## States by hp ratio: NORMAL (> 0.7), DAMAGED (0.3..0.7, occasional sparks +
## light smoke + flickering lights), CRITICAL (< 0.3, heavier smoke, alarm
## lights, blinking emissives, and -- for units -- a mild speed penalty via
## movement_multiplier()). Because the state is re-derived from the live hp
## ratio every frame, it integrates with every damage AND repair path
## automatically: take_damage, supply-truck heals, HQ/outpost repair auras.
##
## Also owns the two staged one-off sequences: the HQ's destruction
## (internal flashes -> main explosion -> tower collapse -> smoke plume;
## GameState.end_match fires at the main explosion so the match-end
## cinematics/banner follow the blast) and the outpost capture transition
## (old team lights shut off -> neutral pulse -> new team lights power on).

enum Kind { UNIT, HQ, OUTPOST }
enum State { NORMAL, DAMAGED, CRITICAL }

const DAMAGED_HP_RATIO: float = 0.7
const CRITICAL_HP_RATIO: float = 0.3

# Periodic damage sparks (VFXManager.spawn_damage_sparks reuse).
const SPARK_INTERVAL_DAMAGED_MIN: float = 1.6
const SPARK_INTERVAL_DAMAGED_MAX: float = 3.2
const SPARK_INTERVAL_CRITICAL_MIN: float = 0.9
const SPARK_INTERVAL_CRITICAL_MAX: float = 1.8
const SPARK_OFFSET_RANGE: float = 0.9

# Random light flicker (brief offs, mostly on).
const FLICKER_ON_DAMAGED_MIN: float = 0.7
const FLICKER_ON_DAMAGED_MAX: float = 1.8
const FLICKER_ON_CRITICAL_MIN: float = 0.25
const FLICKER_ON_CRITICAL_MAX: float = 0.8
const FLICKER_OFF_MIN: float = 0.05
const FLICKER_OFF_MAX: float = 0.14

# HQ alarm banners (regular strobe, danger red) while CRITICAL.
const ALARM_STROBE_INTERVAL: float = 0.3
const ALARM_COLOR: Color = Color(1.0, 0.25, 0.2)

# Smoke emitters (lazily created; toggled per state).
const UNIT_SMOKE_LIGHT_AMOUNT: int = 5
const UNIT_SMOKE_HEAVY_AMOUNT: int = 9
const UNIT_SMOKE_SIZE: float = 0.3
const UNIT_SMOKE_HEAVY_SIZE: float = 0.42
const BUILDING_SMOKE_AMOUNT: int = 8
const BUILDING_SMOKE_SIZE: float = 0.5
const OUTPOST_SMOKE_AMOUNT: int = 6
const OUTPOST_SMOKE_SIZE: float = 0.4
const SMOKE_LIFETIME: float = 1.4

# HQ staged destruction.
const DESTRUCTION_FLASH_INTERVAL: float = 0.16
const DESTRUCTION_FLASH_OFFSETS: Array[Vector3] = [
	Vector3(1.5, 2.5, 1.0), Vector3(-1.8, 4.0, -0.8), Vector3(0.4, 6.5, 0.6),
]
const COLLAPSE_SINK_DISTANCE: float = 4.5
const COLLAPSE_DURATION: float = 1.2
const COLLAPSE_TILT: float = 0.12
const PLUME_AMOUNT: int = 18
const PLUME_SIZE: float = 0.85
const PLUME_LIFETIME: float = 2.4

# Outpost capture transition.
const CAPTURE_NEUTRAL_HOLD: float = 0.45
const CAPTURE_PULSE_DURATION: float = 0.55
const CAPTURE_PULSE_SCALE: float = 1.5

var _kind: int = Kind.UNIT
var _state: int = State.NORMAL
var _team: int = Constants.Team.PLAYER
var _host: Node3D = null
var _visual_root: Node3D = null
var _animator: BuildingAnimator = null  # buildings only (capture staging)

# Flicker/alarm channels.
var _flicker_targets: Array[Node3D] = []
var _flicker_timer: float = 0.0
var _flicker_lights_on: bool = true
var _alarm_targets: Array[MeshInstance3D] = []
var _alarm_timer: float = 0.0
var _alarm_lights_on: bool = true
var _alarm_active: bool = false

var _spark_timer: float = 0.0

# Smoke emitters: [0] = primary (DAMAGED+), rest = extras (CRITICAL only).
var _smoke_emitters: Array[GPUParticles3D] = []
var _smoke_offsets: Array[Vector3] = []
var _smoke_amounts: Array[int] = []
var _smoke_sizes: Array[float] = []

# Named parts (buildings).
var _power_core: Node3D = null
var _banners: Array[MeshInstance3D] = []
var _antenna_tip: Node3D = null
var _team_strip: Node3D = null  # units

var _destruction_played: bool = false
var _capture_tween: Tween = null


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup_unit(host: Node3D, visual_root: Node3D, team: int, team_strip: Node3D) -> void:
	_kind = Kind.UNIT
	_host = host
	_visual_root = visual_root
	_team = team
	_team_strip = team_strip
	_smoke_offsets = [Vector3(0.0, 0.9, 0.0), Vector3(0.3, 0.7, -0.25)]
	_smoke_amounts = [UNIT_SMOKE_LIGHT_AMOUNT, UNIT_SMOKE_HEAVY_AMOUNT]
	_smoke_sizes = [UNIT_SMOKE_SIZE, UNIT_SMOKE_HEAVY_SIZE]


func setup_building(host: Node3D, visual_root: Node3D, building_kind: int, team: int, animator: BuildingAnimator) -> void:
	_kind = Kind.HQ if building_kind == Constants.BuildingType.HQ else Kind.OUTPOST
	_host = host
	_visual_root = visual_root
	_team = team
	_animator = animator

	if _kind == Kind.HQ:
		_power_core = _visual_root.get_node_or_null("PowerCore")
		for banner_name in ["BannerLeft", "BannerRight"]:
			var banner := _visual_root.get_node_or_null(banner_name) as MeshInstance3D
			if banner != null:
				_banners.append(banner)
		# Smoke from one side while DAMAGED; two extra columns while CRITICAL.
		_smoke_offsets = [Vector3(3.2, 3.5, 1.2), Vector3(-2.8, 3.0, -1.5), Vector3(0.5, 8.0, 0.4)]
		_smoke_amounts = [BUILDING_SMOKE_AMOUNT, BUILDING_SMOKE_AMOUNT, BUILDING_SMOKE_AMOUNT]
		_smoke_sizes = [BUILDING_SMOKE_SIZE, BUILDING_SMOKE_SIZE, BUILDING_SMOKE_SIZE]
	else:
		_antenna_tip = _visual_root.get_node_or_null("AntennaTip")
		_smoke_offsets = [Vector3(0.9, 3.8, 0.4), Vector3(-0.8, 2.2, -0.6)]
		_smoke_amounts = [OUTPOST_SMOKE_AMOUNT, OUTPOST_SMOKE_AMOUNT]
		_smoke_sizes = [OUTPOST_SMOKE_SIZE, OUTPOST_SMOKE_SIZE]


# ---------------------------------------------------------------------------
# Per-frame update (state machine driven by the live hp ratio)
# ---------------------------------------------------------------------------

func update(delta: float, hp_ratio: float) -> void:
	if _destruction_played:
		return

	var new_state: int = _state_for_ratio(hp_ratio)
	if new_state != _state:
		_enter_state(new_state)

	if _state == State.NORMAL:
		return

	_update_sparks(delta)
	_update_flicker(delta)
	_update_alarm(delta)


## Mild, symmetric speed penalty for critically damaged units -- both teams
## are affected identically (see Constants.CRITICAL_DAMAGE_SPEED_MULTIPLIER).
func movement_multiplier() -> float:
	if _kind == Kind.UNIT and _state == State.CRITICAL:
		return Constants.CRITICAL_DAMAGE_SPEED_MULTIPLIER
	return 1.0


## Units: stop the damage-state emitters when the unit dies so they don't
## keep puffing over UnitAnimator's own wreck smoke/fade.
func on_death() -> void:
	for emitter in _smoke_emitters:
		if emitter != null:
			emitter.emitting = false
	_restore_lights()


func _state_for_ratio(hp_ratio: float) -> int:
	if hp_ratio < CRITICAL_HP_RATIO:
		return State.CRITICAL
	elif hp_ratio < DAMAGED_HP_RATIO:
		return State.DAMAGED
	return State.NORMAL


func _enter_state(new_state: int) -> void:
	_state = new_state
	match _state:
		State.NORMAL:
			_set_smoke_level(0)
			_restore_lights()
		State.DAMAGED:
			_set_smoke_level(1)
			_stop_alarm()
			_flicker_timer = 0.0
			_spark_timer = randf_range(SPARK_INTERVAL_DAMAGED_MIN, SPARK_INTERVAL_DAMAGED_MAX)
		State.CRITICAL:
			_set_smoke_level(_smoke_offsets.size())
			_flicker_timer = 0.0
			_spark_timer = randf_range(SPARK_INTERVAL_CRITICAL_MIN, SPARK_INTERVAL_CRITICAL_MAX)
			if _kind == Kind.HQ:
				_start_alarm()


# ---------------------------------------------------------------------------
# Periodic sparks
# ---------------------------------------------------------------------------

func _update_sparks(delta: float) -> void:
	_spark_timer -= delta
	if _spark_timer > 0.0:
		return
	if _state == State.CRITICAL:
		_spark_timer = randf_range(SPARK_INTERVAL_CRITICAL_MIN, SPARK_INTERVAL_CRITICAL_MAX)
	else:
		_spark_timer = randf_range(SPARK_INTERVAL_DAMAGED_MIN, SPARK_INTERVAL_DAMAGED_MAX)

	var jitter := Vector3(
		randf_range(-SPARK_OFFSET_RANGE, SPARK_OFFSET_RANGE),
		randf_range(0.5, 1.5),
		randf_range(-SPARK_OFFSET_RANGE, SPARK_OFFSET_RANGE)
	)
	VFXManager.spawn_damage_sparks(_visual_root.global_position + jitter, _team)


# ---------------------------------------------------------------------------
# Light flicker / alarm strobing
# ---------------------------------------------------------------------------

## Which lights blink randomly in the current state. Units: the team strip
## only when CRITICAL. HQ: banners while DAMAGED; the power core while
## CRITICAL (banners switch to the alarm strobe channel). Outpost: the
## antenna tip only when CRITICAL ("similar but smaller").
func _current_flicker_targets() -> Array[Node3D]:
	var targets: Array[Node3D] = []
	match _kind:
		Kind.UNIT:
			if _state == State.CRITICAL and _team_strip != null:
				targets.append(_team_strip)
		Kind.HQ:
			if _state == State.DAMAGED:
				for banner in _banners:
					targets.append(banner)
			elif _state == State.CRITICAL and _power_core != null:
				targets.append(_power_core)
		Kind.OUTPOST:
			if _state == State.CRITICAL and _antenna_tip != null:
				targets.append(_antenna_tip)
	return targets


func _update_flicker(delta: float) -> void:
	_flicker_targets = _current_flicker_targets()
	if _flicker_targets.is_empty():
		return

	_flicker_timer -= delta
	if _flicker_timer > 0.0:
		return

	_flicker_lights_on = not _flicker_lights_on
	if _flicker_lights_on:
		if _state == State.CRITICAL:
			_flicker_timer = randf_range(FLICKER_ON_CRITICAL_MIN, FLICKER_ON_CRITICAL_MAX)
		else:
			_flicker_timer = randf_range(FLICKER_ON_DAMAGED_MIN, FLICKER_ON_DAMAGED_MAX)
	else:
		_flicker_timer = randf_range(FLICKER_OFF_MIN, FLICKER_OFF_MAX)

	for target in _flicker_targets:
		target.visible = _flicker_lights_on


## HQ CRITICAL only: banners re-tint to danger red and strobe on a steady
## rhythm -- a deliberate alarm cadence, distinct from the random flicker.
## Banner materials are per-HQ duplicates (see BuildingVisualFactory), so
## re-tinting them never touches the shared team emissives.
func _start_alarm() -> void:
	_alarm_active = true
	_alarm_timer = 0.0
	_alarm_lights_on = true
	for banner in _banners:
		var material := banner.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = ALARM_COLOR
			material.emission = ALARM_COLOR


func _stop_alarm() -> void:
	if not _alarm_active:
		return
	_alarm_active = false
	for banner in _banners:
		banner.visible = true
		var material := banner.material_override as StandardMaterial3D
		if material != null:
			var team_emissive: StandardMaterial3D = MaterialLibrary.emissive_for_team(_team)
			material.albedo_color = team_emissive.albedo_color
			material.emission = team_emissive.emission


func _update_alarm(delta: float) -> void:
	if not _alarm_active:
		return
	_alarm_timer -= delta
	if _alarm_timer > 0.0:
		return
	_alarm_timer = ALARM_STROBE_INTERVAL
	_alarm_lights_on = not _alarm_lights_on
	for banner in _banners:
		banner.visible = _alarm_lights_on


## Everything visible again, alarm off -- entering NORMAL (repaired) or death.
func _restore_lights() -> void:
	_stop_alarm()
	_flicker_lights_on = true
	if _team_strip != null:
		_team_strip.visible = true
	if _power_core != null:
		_power_core.visible = true
	if _antenna_tip != null:
		_antenna_tip.visible = true
	for banner in _banners:
		banner.visible = true


# ---------------------------------------------------------------------------
# Smoke emitters
# ---------------------------------------------------------------------------

## Enables the first `active_count` emitters (creating them lazily) and
## silences the rest. 0 = repaired/clean, 1 = light/one-sided smoke,
## all = the CRITICAL multi-column state.
func _set_smoke_level(active_count: int) -> void:
	for i in range(_smoke_offsets.size()):
		var should_emit: bool = i < active_count
		if should_emit and i >= _smoke_emitters.size():
			_smoke_emitters.append(_make_smoke_emitter(_smoke_offsets[i], _smoke_amounts[i], _smoke_sizes[i]))
		if i < _smoke_emitters.size() and _smoke_emitters[i] != null:
			_smoke_emitters[i].emitting = should_emit


func _make_smoke_emitter(offset: Vector3, amount: int, size: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = SMOKE_LIFETIME
	particles.local_coords = false
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(size)
	particles.process_material = _make_smoke_material(0.4, 1.0)
	particles.position = offset
	particles.emitting = false
	_visual_root.add_child(particles)
	return particles


func _make_smoke_material(velocity_min: float, velocity_max: float) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 18.0
	material.initial_velocity_min = velocity_min
	material.initial_velocity_max = velocity_max
	material.gravity = Vector3(0.0, 0.35, 0.0)
	material.scale_min = 0.9
	material.scale_max = 1.7
	material.color_ramp = VFXParticleUtil.make_fade_gradient(MaterialLibrary.smoke_dark().albedo_color)
	return material


# ---------------------------------------------------------------------------
# HQ staged destruction
# ---------------------------------------------------------------------------

## Internal flashes -> main explosion (where the match actually ends, so the
## end cinematics and result banner chain off the big blast) -> tower
## collapse/sink -> lingering smoke plume. The host node stays in the tree
## as a wreck behind the result screen; the scene change cleans it up.
func play_hq_destruction(winning_team: int) -> void:
	if _destruction_played:
		return
	_destruction_played = true
	_restore_lights()

	var tween: Tween = _host.create_tween()
	for i in range(DESTRUCTION_FLASH_OFFSETS.size()):
		tween.tween_callback(_destruction_flash.bind(i))
		tween.tween_interval(DESTRUCTION_FLASH_INTERVAL)
	tween.tween_callback(_destruction_main_blast.bind(winning_team))
	tween.tween_callback(_spawn_destruction_plume)
	tween.tween_property(_visual_root, "position:y",
		_visual_root.position.y - COLLAPSE_SINK_DISTANCE, COLLAPSE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_visual_root, "rotation:x", COLLAPSE_TILT, COLLAPSE_DURATION)
	tween.parallel().tween_property(_visual_root, "rotation:z", -COLLAPSE_TILT * 0.7, COLLAPSE_DURATION)


func _destruction_flash(index: int) -> void:
	VFXManager.spawn_explosion_small(_visual_root.global_position + DESTRUCTION_FLASH_OFFSETS[index])
	# Power dying: the core strobes with each internal flash and ends dark.
	if _power_core != null:
		_power_core.visible = index % 2 == 1


func _destruction_main_blast(winning_team: int) -> void:
	VFXManager.spawn_explosion_large(_visual_root.global_position + Vector3(0.0, 2.0, 0.0))
	GameState.end_match(winning_team)


func _spawn_destruction_plume() -> void:
	var plume := GPUParticles3D.new()
	plume.amount = PLUME_AMOUNT
	plume.lifetime = PLUME_LIFETIME
	plume.local_coords = false
	plume.draw_pass_1 = VFXParticleUtil.make_quad_mesh(PLUME_SIZE)
	plume.process_material = _make_smoke_material(1.2, 2.2)
	plume.position = Vector3(0.0, 3.0, 0.0)
	_visual_root.add_child(plume)
	plume.emitting = true


# ---------------------------------------------------------------------------
# Outpost capture transition
# ---------------------------------------------------------------------------

## Old team lights shut off (everything drops to the neutral palette), a
## white ring pulse expands, then the new team's lights power on -- the
## capture ring color change rides on BuildingAnimator.set_team, which
## re-asserts the ring palette every frame, so the staging composes with the
## animator instead of fighting its per-frame writes.
func play_capture_transition(new_team: int) -> void:
	_team = new_team
	if _animator == null:
		return

	if _capture_tween != null and _capture_tween.is_valid():
		_capture_tween.kill()

	_animator.set_team(Constants.Team.NEUTRAL)
	_spawn_capture_pulse()

	_capture_tween = _host.create_tween()
	_capture_tween.tween_interval(CAPTURE_NEUTRAL_HOLD)
	_capture_tween.tween_callback(_animator.set_team.bind(new_team))


## One-shot expanding white ring at capture-ring height, independent of the
## real ring's material so it can't disturb the animator's pulsing.
func _spawn_capture_pulse() -> void:
	var pulse := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 5.2
	mesh.outer_radius = 5.8
	pulse.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	material.emission = Color(1.0, 1.0, 1.0)
	pulse.material_override = material
	pulse.position = Vector3(0.0, 0.5, 0.0)
	_visual_root.add_child(pulse)

	var tween: Tween = _host.create_tween()
	tween.tween_property(pulse, "scale", Vector3.ONE * CAPTURE_PULSE_SCALE, CAPTURE_PULSE_DURATION)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, CAPTURE_PULSE_DURATION)
	tween.tween_callback(pulse.queue_free)
