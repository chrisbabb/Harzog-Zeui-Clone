extends Control
## Title screen: the menu panel sits over a live 3D battlefield diorama
## (TitleBackground.tscn) with a faint drifting tactical grid and a vignette
## on top. Buttons share one cyan focus highlight between mouse hover and
## controller navigation (hovering grabs focus), and get a press "punch"
## animation plus hover/select sounds.

const SKIRMISH_SETUP_SCENE_PATH: String = "res://scenes/ui/SkirmishSetup.tscn"
const TUTORIAL_SCENE_PATH: String = "res://scenes/main/Tutorial.tscn"
const OPTIONS_MENU_SCENE: PackedScene = preload("res://scenes/ui/OptionsMenu.tscn")

const FOCUS_PULSE_LOW_ALPHA: float = 0.78
const FOCUS_PULSE_SPEED: float = 2.5
const PRESS_SCALE: float = 0.94
const PRESS_IN_DURATION: float = 0.05
const PRESS_OUT_DURATION: float = 0.07
const FOCUS_BG_COLOR: Color = Color(0.1, 0.16, 0.22, 0.9)
const FOCUS_BORDER_COLOR: Color = Color(0.35, 0.85, 1.0, 0.95)

@onready var start_button: Button = $MenuPanel/M/Box/StartButton
@onready var tutorial_button: Button = $MenuPanel/M/Box/TutorialButton
@onready var options_button: Button = $MenuPanel/M/Box/OptionsButton
@onready var quit_button: Button = $MenuPanel/M/Box/QuitButton

var _focus_tweens: Dictionary = {}
var _press_locked: bool = false
var _hover_sound_ready: bool = false


func _ready() -> void:
	# Defensive reset -- a match left running at Fast speed must not leak its
	# time scale into the menu or the next match.
	Engine.time_scale = 1.0

	var focus_style: StyleBoxFlat = _make_focus_style()
	_setup_button(start_button, _start_skirmish, "ui_select", focus_style)
	_setup_button(tutorial_button, _start_tutorial, "ui_select", focus_style)
	_setup_button(options_button, _open_options, "ui_select", focus_style)
	_setup_button(quit_button, _quit_game, "ui_cancel", focus_style)
	_wrap_focus_neighbors()

	start_button.grab_focus()
	# Deferred so the initial grab_focus above doesn't play a hover blip.
	call_deferred("_enable_hover_sounds")
	AudioManager.play_music(AudioManager.MusicTrack.MENU)


func _setup_button(button: Button, action: Callable, sound: String, focus_style: StyleBoxFlat) -> void:
	# Cyan "active selection" style replacing the theme's default focus ring;
	# scoped to the title screen so other menus keep the shared theme look.
	button.add_theme_stylebox_override("focus", focus_style)
	button.pressed.connect(_on_button_pressed.bind(button, action, sound))
	# Hover moves focus, so mouse and controller share one highlight instead
	# of showing two competing selections.
	button.mouse_entered.connect(button.grab_focus)
	button.focus_entered.connect(_on_button_focus_entered.bind(button))
	button.focus_exited.connect(_on_button_focus_exited.bind(button))


func _make_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = FOCUS_BG_COLOR
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = FOCUS_BORDER_COLOR
	style.content_margin_left = 12.0
	style.content_margin_top = 6.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0
	return style


## Controller/keyboard navigation wraps: up from the top button lands on
## Quit, down from Quit lands back on Start. The in-between neighbors are
## Godot's automatic VBox ordering.
func _wrap_focus_neighbors() -> void:
	start_button.focus_neighbor_top = start_button.get_path_to(quit_button)
	quit_button.focus_neighbor_bottom = quit_button.get_path_to(start_button)


func _enable_hover_sounds() -> void:
	_hover_sound_ready = true


# ---------------------------------------------------------------------------
# Button feedback (focus pulse, hover sound, press punch)
# ---------------------------------------------------------------------------

func _on_button_focus_entered(button: Button) -> void:
	if _hover_sound_ready:
		EventBus.audio_event_requested.emit("ui_hover")
	_stop_focus_pulse(button)
	_focus_tweens[button] = UIThemeFactory.continuous_pulse(button, FOCUS_PULSE_LOW_ALPHA, 1.0, FOCUS_PULSE_SPEED)


func _on_button_focus_exited(button: Button) -> void:
	_stop_focus_pulse(button)


func _stop_focus_pulse(button: Button) -> void:
	if _focus_tweens.has(button):
		var tween: Tween = _focus_tweens[button]
		if tween != null and tween.is_valid():
			tween.kill()
		_focus_tweens.erase(button)
	button.modulate = Color.WHITE


## Quick scale punch on press, then run the button's action. The lock stops
## a second activation (e.g. mashing ui_accept) from firing two scene
## changes while the first punch is still playing.
func _on_button_pressed(button: Button, action: Callable, sound: String) -> void:
	if _press_locked:
		return
	_press_locked = true
	EventBus.audio_event_requested.emit(sound)

	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * PRESS_SCALE, PRESS_IN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, PRESS_OUT_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_run_action.bind(action))


func _run_action(action: Callable) -> void:
	_press_locked = false
	action.call()


# ---------------------------------------------------------------------------
# Button actions
# ---------------------------------------------------------------------------

func _start_skirmish() -> void:
	get_tree().change_scene_to_file(SKIRMISH_SETUP_SCENE_PATH)


func _start_tutorial() -> void:
	# Set before the scene change (not left to Tutorial.gd's own _ready()) --
	# Godot fires a child's _ready() before its parent's, so HUD._ready()
	# would otherwise read a stale LOCAL_MULTIPLAYER left over from a
	# previous match before Tutorial.gd got a chance to reset it.
	GameState.game_mode = Constants.GameMode.SINGLE_PLAYER
	get_tree().change_scene_to_file(TUTORIAL_SCENE_PATH)


func _open_options() -> void:
	add_child(OPTIONS_MENU_SCENE.instantiate())


func _quit_game() -> void:
	get_tree().quit()
