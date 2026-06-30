extends Control
## Placeholder main menu: start a match or quit the game.

const SKIRMISH_SETUP_SCENE_PATH: String = "res://scenes/ui/SkirmishSetup.tscn"
const TUTORIAL_SCENE_PATH: String = "res://scenes/main/Tutorial.tscn"
const OPTIONS_MENU_SCENE: PackedScene = preload("res://scenes/ui/OptionsMenu.tscn")

@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var tutorial_button: Button = $Panel/VBoxContainer/TutorialButton
@onready var options_button: Button = $Panel/VBoxContainer/OptionsButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton


func _ready() -> void:
	# Defensive reset -- a match left running at Fast speed must not leak its
	# time scale into the menu or the next match.
	Engine.time_scale = 1.0
	start_button.pressed.connect(_on_start_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	start_button.grab_focus()
	AudioManager.play_music(AudioManager.MusicTrack.MENU)


func _on_start_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	get_tree().change_scene_to_file(SKIRMISH_SETUP_SCENE_PATH)


func _on_tutorial_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	get_tree().change_scene_to_file(TUTORIAL_SCENE_PATH)


func _on_options_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	add_child(OPTIONS_MENU_SCENE.instantiate())


func _on_quit_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_cancel")
	get_tree().quit()
