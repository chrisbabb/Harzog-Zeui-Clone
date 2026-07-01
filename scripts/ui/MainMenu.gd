extends Control
## Main menu: start a match or quit the game, over an animated parallax
## "abstract map" backdrop (see ParallaxGridLayer.gd).

const SKIRMISH_SETUP_SCENE_PATH: String = "res://scenes/ui/SkirmishSetup.tscn"
const TUTORIAL_SCENE_PATH: String = "res://scenes/main/Tutorial.tscn"
const OPTIONS_MENU_SCENE: PackedScene = preload("res://scenes/ui/OptionsMenu.tscn")
const FOCUS_PULSE_LOW_ALPHA: float = 0.75
const FOCUS_PULSE_SPEED: float = 2.5

@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var tutorial_button: Button = $Panel/VBoxContainer/TutorialButton
@onready var options_button: Button = $Panel/VBoxContainer/OptionsButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

var _focus_tweens: Dictionary = {}


func _ready() -> void:
	# Defensive reset -- a match left running at Fast speed must not leak its
	# time scale into the menu or the next match.
	Engine.time_scale = 1.0
	start_button.pressed.connect(_on_start_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	_connect_focus_pulse(start_button)
	_connect_focus_pulse(tutorial_button)
	_connect_focus_pulse(options_button)
	_connect_focus_pulse(quit_button)
	start_button.grab_focus()
	AudioManager.play_music(AudioManager.MusicTrack.MENU)


## Gives whichever button currently holds keyboard/gamepad focus a gentle
## breathing glow -- the "animated selection highlight" style used across
## the rest of the UI (BuildMenu/CommandMenu card pulses), scaled down to a
## simple modulate pulse since a plain vertical button list doesn't need a
## dedicated StyleBoxFlat per entry.
func _connect_focus_pulse(button: Button) -> void:
	button.focus_entered.connect(_on_button_focus_entered.bind(button))
	button.focus_exited.connect(_on_button_focus_exited.bind(button))


func _on_button_focus_entered(button: Button) -> void:
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


func _on_start_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	get_tree().change_scene_to_file(SKIRMISH_SETUP_SCENE_PATH)


func _on_tutorial_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	# Set before the scene change (not left to Tutorial.gd's own _ready()) --
	# Godot fires a child's _ready() before its parent's, so HUD._ready()
	# would otherwise read a stale LOCAL_MULTIPLAYER left over from a
	# previous match before Tutorial.gd got a chance to reset it.
	GameState.game_mode = Constants.GameMode.SINGLE_PLAYER
	get_tree().change_scene_to_file(TUTORIAL_SCENE_PATH)


func _on_options_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	add_child(OPTIONS_MENU_SCENE.instantiate())


func _on_quit_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_cancel")
	get_tree().quit()
