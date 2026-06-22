extends Control
## Placeholder main menu: start a match or quit the game.

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"

@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	start_button.grab_focus()


func _on_start_pressed() -> void:
	GameState.reset_match_state()
	Economy.reset()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
