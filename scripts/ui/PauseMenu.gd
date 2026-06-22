extends Control
## Placeholder pause menu: resume, return to main menu, or quit.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/MainMenu.tscn"

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(Constants.ACTION_PAUSE):
		_toggle_pause()


func _toggle_pause() -> void:
	if visible:
		_on_resume_pressed()
	else:
		visible = true
		get_tree().paused = true
		resume_button.grab_focus()


func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	GameState.reset_match_state()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
