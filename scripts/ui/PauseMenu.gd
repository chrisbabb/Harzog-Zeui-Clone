extends Control
## Pause menu: resume, restart the current match, return to main menu, or quit.
## In local multiplayer each player's HUD embeds its own PauseMenu instance.
## Pausing is inherently shared (get_tree().paused is tree-wide), so
## visibility here just mirrors that shared state -- whichever player
## toggles it, both instances show/hide together instead of one getting
## stuck open after the other resumes.

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/MainMenu.tscn"
const OPTIONS_MENU_SCENE: PackedScene = preload("res://scenes/ui/OptionsMenu.tscn")

@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var options_button: Button = $Panel/VBoxContainer/OptionsButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

# Which player this PauseMenu belongs to; set to ENEMY for P2 in local
# multiplayer so its input filtering matches its sibling HUD's.
@export var team: int = Constants.Team.PLAYER


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	options_button.pressed.connect(_on_options_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _process(_delta: float) -> void:
	var should_show: bool = get_tree().paused
	if should_show and not visible:
		visible = true
		resume_button.grab_focus()
	elif not should_show and visible:
		visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Two PauseMenu instances exist in local multiplayer (one per player);
	# without this filter either player's Pause button would toggle both.
	# Mirrors the same filter in HUD.gd/BuildMenu.gd/CommandMenu.gd.
	if GameState.game_mode == Constants.GameMode.LOCAL_MULTIPLAYER:
		var is_joy_event: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if team == Constants.Team.PLAYER and is_joy_event:
			return
		if team == Constants.Team.ENEMY and not is_joy_event:
			return

	if Input.is_action_just_pressed(Constants.ACTION_PAUSE):
		get_tree().paused = not get_tree().paused


func _on_resume_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_cancel")
	get_tree().paused = false


func _on_restart_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	get_tree().paused = false
	GameState.reset_match_state()
	Economy.reset()
	get_tree().reload_current_scene()


func _on_options_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	add_child(OPTIONS_MENU_SCENE.instantiate())


func _on_main_menu_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_cancel")
	get_tree().paused = false
	GameState.reset_match_state()
	Economy.reset()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _on_quit_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_cancel")
	get_tree().quit()
