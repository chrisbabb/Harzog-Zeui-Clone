extends Node
## Cinematic intro and end sequences for the single-player Game scene.
##
## Intro (~6s, skippable with any key/mouse/joypad press): fade in from
## black over the player HQ, show the objective text, pan across a neutral
## outpost and the enemy HQ, return to the commander, then hand control to
## the player by emitting intro_finished (Game.gd starts the match there).
## GameState.cinematic_active stays true for the whole sequence, which
## freezes the player commander and Game.gd's camera follow.
##
## End (not skippable, single-fire): on match_ended, re-freeze the
## commander and camera, pan to the destroyed HQ, and play a slow-motion
## explosion beat (victory) or a camera-shake barrage (defeat). The
## VICTORY/DEFEAT banner and stats panel are MatchResultPanel's job -- its
## appear delay is sized to start right after this sequence's beat.
##
## Local multiplayer intentionally has no MatchCinematics node: a shared
## camera cinematic can't serve two split-screen viewports, so that mode
## keeps its instant start (see LocalMultiplayer.gd).

signal intro_finished

const OVERLAY_LAYER: int = 0  # above the world, below the HUD CanvasLayer (layer 1)

const FADE_IN_DURATION: float = 0.9
const PAN_TO_OUTPOST_DURATION: float = 1.4
const PAN_TO_ENEMY_HQ_DURATION: float = 1.3
const ENEMY_HQ_HOLD_DURATION: float = 0.4
const PAN_TO_COMMANDER_DURATION: float = 1.2
const INTRO_SETTLE_DURATION: float = 0.3
const LINE_FADE_DURATION: float = 0.35
const LINE_1_AT: float = 0.4
const LINE_2_AT: float = 1.4

const INTRO_LINE_FONT_SIZE: int = 22
const SKIP_HINT_FONT_SIZE: int = 12
const OBJECTIVE_BOX_RAISE: float = 150.0
const SKIP_HINT_RAISE: float = 46.0

const END_PAN_DURATION: float = 0.6
const SLOWMO_SCALE: float = 0.35
# Scaled tween intervals: 0.25s at time_scale 0.35 is ~0.71s of real time,
# so the two beats below hold the slow-mo for ~1.4 real seconds.
const SLOWMO_BEAT_INTERVAL: float = 0.25
const SECONDARY_EXPLOSION_OFFSET_A: Vector3 = Vector3(2.5, 1.0, 1.5)
const SECONDARY_EXPLOSION_OFFSET_B: Vector3 = Vector3(-2.0, 2.0, -1.0)
const SHAKE_STEPS: int = 8
const SHAKE_STEP_DURATION: float = 0.055
const SHAKE_MAX_OFFSET: float = 1.6

var _camera_rig: Node3D = null
var _intro_playing: bool = false
var _end_played: bool = false
var _intro_tweens: Array[Tween] = []
var _overlay: CanvasLayer = null
var _fade_rect: ColorRect = null
var _objective_labels: Array[Label] = []
var _skip_hint: Label = null
var _player_hq_position: Vector3 = Vector3.ZERO
var _enemy_hq_position: Vector3 = Vector3.ZERO

# Text/color per objective line; index 2's danger red matches the "destroy"
# framing everywhere else in the UI.
var _intro_lines: Array[Dictionary] = [
	{"text": "COMMAND LINK ESTABLISHED", "color": UIThemeFactory.CYAN_ACCENT},
	{"text": "CAPTURE OUTPOSTS", "color": Color(0.88, 0.92, 0.98)},
	{"text": "DESTROY ENEMY HQ", "color": UIThemeFactory.DANGER_COLOR},
]


func _ready() -> void:
	_camera_rig = get_node_or_null("../CameraRig")
	EventBus.match_ended.connect(_on_match_ended)


func _unhandled_input(event: InputEvent) -> void:
	if not _intro_playing:
		return
	# "Any input" deliberately means pressed keys/buttons only -- mouse or
	# analog-stick motion would skip the intro by accident.
	var is_press: bool = (event is InputEventKey or event is InputEventMouseButton \
		or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if is_press:
		_skip_intro()


# ---------------------------------------------------------------------------
# Intro sequence
# ---------------------------------------------------------------------------

## Called by Game.gd once the battlefield/commanders exist. Runs at
## time_scale 1.0; Game.gd applies the chosen match speed when
## intro_finished fires.
func play_intro() -> void:
	Engine.time_scale = 1.0
	GameState.cinematic_active = true
	_intro_playing = true
	_cache_hq_positions()
	_set_hud_root_visible(false)
	_build_overlay()

	if _camera_rig == null:
		# No camera to choreograph -- degrade to just the fade/text overlay.
		push_warning("MatchCinematics: no ../CameraRig found; intro plays without camera pans.")

	var start_position: Vector3 = _clamp_to_arena(_player_hq_position)
	if _camera_rig != null:
		_camera_rig.global_position = start_position

	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(_fade_rect, "modulate:a", 0.0, FADE_IN_DURATION).from(1.0)
	_intro_tweens.append(fade_tween)

	var timeline: Tween = create_tween()
	timeline.tween_interval(LINE_1_AT)
	timeline.tween_callback(_fade_in_line.bind(0))
	timeline.tween_interval(LINE_2_AT - LINE_1_AT)
	timeline.tween_callback(_fade_in_line.bind(1))
	if _camera_rig != null:
		timeline.tween_property(_camera_rig, "global_position",
			_clamp_to_arena(_pick_intro_outpost_position()), PAN_TO_OUTPOST_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		timeline.tween_interval(PAN_TO_OUTPOST_DURATION)
	timeline.tween_callback(_fade_in_line.bind(2))
	if _camera_rig != null:
		timeline.tween_property(_camera_rig, "global_position",
			_clamp_to_arena(_enemy_hq_position), PAN_TO_ENEMY_HQ_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		timeline.tween_interval(PAN_TO_ENEMY_HQ_DURATION)
	timeline.tween_interval(ENEMY_HQ_HOLD_DURATION)
	timeline.tween_callback(_fade_out_lines)
	if _camera_rig != null:
		timeline.tween_property(_camera_rig, "global_position",
			_commander_camera_position(), PAN_TO_COMMANDER_DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		timeline.tween_interval(PAN_TO_COMMANDER_DURATION)
	timeline.tween_interval(INTRO_SETTLE_DURATION)
	timeline.tween_callback(_finish_intro)
	_intro_tweens.append(timeline)

	_show_skip_hint()


func _skip_intro() -> void:
	if not _intro_playing:
		return
	if _camera_rig != null:
		_camera_rig.global_position = _commander_camera_position()
	_finish_intro()


## Single exit point for both the natural end and a skip.
func _finish_intro() -> void:
	if not _intro_playing:
		return
	_intro_playing = false
	_kill_intro_tweens()
	_destroy_overlay()
	_set_hud_root_visible(true)
	GameState.cinematic_active = false
	intro_finished.emit()


func _fade_in_line(index: int) -> void:
	if index >= _objective_labels.size():
		return
	var tween: Tween = create_tween()
	tween.tween_property(_objective_labels[index], "modulate:a", 1.0, LINE_FADE_DURATION)
	_intro_tweens.append(tween)


func _fade_out_lines() -> void:
	for label in _objective_labels:
		var tween: Tween = create_tween()
		tween.tween_property(label, "modulate:a", 0.0, LINE_FADE_DURATION)
		_intro_tweens.append(tween)


func _show_skip_hint() -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(FADE_IN_DURATION)
	tween.tween_property(_skip_hint, "modulate:a", 0.7, LINE_FADE_DURATION)
	_intro_tweens.append(tween)


func _kill_intro_tweens() -> void:
	for tween in _intro_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_intro_tweens.clear()


# ---------------------------------------------------------------------------
# End sequence
# ---------------------------------------------------------------------------

func _on_match_ended(winning_team: int) -> void:
	# GameState.end_match's guard already makes a second emission
	# impossible; this latch keeps the sequence single-fire regardless.
	if _end_played:
		return
	_end_played = true

	GameState.cinematic_active = true
	Engine.time_scale = 1.0  # normalize from Fast match speed before choreographing

	var victory: bool = winning_team == Constants.Team.PLAYER
	var focus: Vector3 = _losing_hq_position(winning_team)

	if _camera_rig == null:
		return

	var tween: Tween = create_tween()
	tween.tween_property(_camera_rig, "global_position", _clamp_to_arena(focus), END_PAN_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if victory:
		# Brief slow-motion while the HQ explosion (spawned by Base.gd the
		# moment it died) is still blooming, plus two secondary blasts.
		tween.tween_callback(_set_time_scale.bind(SLOWMO_SCALE))
		tween.tween_interval(SLOWMO_BEAT_INTERVAL)
		tween.tween_callback(_spawn_secondary_explosion.bind(focus + SECONDARY_EXPLOSION_OFFSET_A))
		tween.tween_interval(SLOWMO_BEAT_INTERVAL)
		tween.tween_callback(_set_time_scale.bind(1.0))
		tween.tween_callback(_spawn_secondary_explosion.bind(focus + SECONDARY_EXPLOSION_OFFSET_B))
	else:
		# Defeat: one extra blast on the player HQ and a hard camera shake.
		tween.tween_callback(_spawn_secondary_explosion.bind(focus + SECONDARY_EXPLOSION_OFFSET_A))
		var clamped_focus: Vector3 = _clamp_to_arena(focus)
		for i in range(SHAKE_STEPS):
			var decay: float = 1.0 - float(i) / float(SHAKE_STEPS)
			var jitter := Vector3(
				randf_range(-1.0, 1.0) * SHAKE_MAX_OFFSET * decay,
				0.0,
				randf_range(-1.0, 1.0) * SHAKE_MAX_OFFSET * decay
			)
			tween.tween_property(_camera_rig, "global_position", clamped_focus + jitter, SHAKE_STEP_DURATION)
		tween.tween_property(_camera_rig, "global_position", clamped_focus, SHAKE_STEP_DURATION * 1.5)


func _set_time_scale(scale_value: float) -> void:
	Engine.time_scale = scale_value


func _spawn_secondary_explosion(explosion_position: Vector3) -> void:
	VFXManager.spawn_explosion_large(explosion_position)


## The exploding HQ is the loser's. Prefer the live node (still valid while
## match_ended handlers run -- Base.gd frees itself only afterwards) and
## fall back to the positions cached at intro time.
func _losing_hq_position(winning_team: int) -> Vector3:
	var losing_hq: Node = GameState.enemy_hq if winning_team == Constants.Team.PLAYER else GameState.player_hq
	if losing_hq != null and is_instance_valid(losing_hq):
		return losing_hq.global_position
	return _enemy_hq_position if winning_team == Constants.Team.PLAYER else _player_hq_position


# ---------------------------------------------------------------------------
# Overlay construction / helpers
# ---------------------------------------------------------------------------

func _build_overlay() -> void:
	_overlay = CanvasLayer.new()
	_overlay.layer = OVERLAY_LAYER
	add_child(_overlay)

	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_fade_rect)

	var objective_box := VBoxContainer.new()
	objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_box.add_theme_constant_override("separation", 10)
	_overlay.add_child(objective_box)
	objective_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	objective_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	objective_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	objective_box.offset_top -= OBJECTIVE_BOX_RAISE
	objective_box.offset_bottom -= OBJECTIVE_BOX_RAISE

	_objective_labels.clear()
	for line in _intro_lines:
		var label := Label.new()
		label.text = line["text"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", INTRO_LINE_FONT_SIZE)
		label.add_theme_color_override("font_color", line["color"])
		label.modulate.a = 0.0
		objective_box.add_child(label)
		_objective_labels.append(label)

	_skip_hint = Label.new()
	_skip_hint.text = "Press any key to skip"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.add_theme_font_size_override("font_size", SKIP_HINT_FONT_SIZE)
	_skip_hint.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88))
	_skip_hint.modulate.a = 0.0
	_overlay.add_child(_skip_hint)
	_skip_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_skip_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_skip_hint.offset_top -= SKIP_HINT_RAISE
	_skip_hint.offset_bottom -= SKIP_HINT_RAISE


func _destroy_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_fade_rect = null
	_skip_hint = null
	_objective_labels.clear()


func _cache_hq_positions() -> void:
	if GameState.player_hq != null and is_instance_valid(GameState.player_hq):
		_player_hq_position = GameState.player_hq.global_position
	if GameState.enemy_hq != null and is_instance_valid(GameState.enemy_hq):
		_enemy_hq_position = GameState.enemy_hq.global_position


## The neutral outpost nearest the arena center reads as "the contested
## middle" -- the most representative capture target to showcase. Falls
## back to any outpost, then to the midpoint between the HQs.
func _pick_intro_outpost_position() -> Vector3:
	var nearest_neutral: Node = null
	var nearest_distance: float = INF
	for outpost in GameState.outposts:
		if not is_instance_valid(outpost) or outpost.get("team") != Constants.Team.NEUTRAL:
			continue
		var distance: float = outpost.global_position.length()
		if distance < nearest_distance:
			nearest_neutral = outpost
			nearest_distance = distance
	if nearest_neutral != null:
		return nearest_neutral.global_position

	for outpost in GameState.outposts:
		if is_instance_valid(outpost):
			return outpost.global_position
	return (_player_hq_position + _enemy_hq_position) * 0.5


func _commander_camera_position() -> Vector3:
	var commander: Node = GameState.player_commander
	if commander != null and is_instance_valid(commander):
		return _clamp_to_arena(commander.global_position)
	return _clamp_to_arena(_player_hq_position)


## Mirrors Game.gd's camera clamp so the intro's final waypoint matches the
## follow position Game.gd resumes from -- no snap on handoff.
func _clamp_to_arena(world_position: Vector3) -> Vector3:
	var half_length: float = Constants.ARENA_LENGTH * 0.5 - Constants.CAMERA_CLAMP_MARGIN.x
	var half_width: float = Constants.ARENA_WIDTH * 0.5 - Constants.CAMERA_CLAMP_MARGIN.y
	return Vector3(
		clamp(world_position.x, -half_length, half_length),
		0.0,
		clamp(world_position.z, -half_width, half_width)
	)


## Hides the HUD's readouts and minimap during the intro so the battlefield
## reads as a cinematic frame. PauseMenu (also a HUD child) is deliberately
## left alone -- pausing mid-intro must still show a usable menu.
func _set_hud_root_visible(shown: bool) -> void:
	var hud: Node = get_node_or_null("../HUD")
	if hud == null:
		return
	for child_name in ["Root", "Minimap"]:
		var child: CanvasItem = hud.get_node_or_null(child_name) as CanvasItem
		if child != null:
			child.visible = shown
