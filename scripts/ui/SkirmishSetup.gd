extends Control
## Skirmish setup screen: choose map, difficulty, starting credits, match
## speed, and outpost count before a match starts. Reached from MainMenu's
## Start Skirmish button; Start here applies the choices to GameState and
## launches the match, mirroring the reset/launch sequence HUD.gd uses for
## rematches.

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/MainMenu.tscn"

const MAP_LABELS: Array[String] = ["Green Divide", "Iron Basin", "Ash Line"]
const DIFFICULTY_LABELS: Array[String] = ["Easy", "Normal", "Hard"]
const STARTING_CREDITS_VALUES: Array[int] = [500, 800, 1200]
const MATCH_SPEED_LABELS: Array[String] = ["Normal", "Fast"]
const OUTPOST_COUNT_VALUES: Array[int] = [5, 7, 9]

@onready var map_option: OptionButton = $Panel/VBoxContainer/MapOptionButton
@onready var difficulty_option: OptionButton = $Panel/VBoxContainer/DifficultyOptionButton
@onready var starting_credits_option: OptionButton = $Panel/VBoxContainer/StartingCreditsOptionButton
@onready var match_speed_option: OptionButton = $Panel/VBoxContainer/MatchSpeedOptionButton
@onready var outpost_count_option: OptionButton = $Panel/VBoxContainer/OutpostCountOptionButton
@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var back_button: Button = $Panel/VBoxContainer/BackButton


func _ready() -> void:
	_populate_options()
	_load_defaults()

	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	start_button.grab_focus()


func _populate_options() -> void:
	for label in MAP_LABELS:
		map_option.add_item(label)
	for label in DIFFICULTY_LABELS:
		difficulty_option.add_item(label)
	for value in STARTING_CREDITS_VALUES:
		starting_credits_option.add_item(str(value))
	for label in MATCH_SPEED_LABELS:
		match_speed_option.add_item(label)
	for value in OUTPOST_COUNT_VALUES:
		outpost_count_option.add_item(str(value))


func _load_defaults() -> void:
	map_option.select(clamp(GameState.selected_map, 0, MAP_LABELS.size() - 1))
	# Pre-fill from the persisted Options Menu preference rather than
	# GameState's own default, so a returning player sees their usual
	# difficulty without having to reselect it every skirmish.
	difficulty_option.select(clamp(SaveManager.difficulty, 0, DIFFICULTY_LABELS.size() - 1))
	starting_credits_option.select(_index_of_int(STARTING_CREDITS_VALUES, GameState.selected_starting_credits, 1))
	match_speed_option.select(clamp(GameState.selected_match_speed, 0, MATCH_SPEED_LABELS.size() - 1))
	outpost_count_option.select(_index_of_int(OUTPOST_COUNT_VALUES, GameState.selected_outpost_count, 1))


func _index_of_int(values: Array[int], value: int, fallback_index: int) -> int:
	var found_index: int = values.find(value)
	return found_index if found_index != -1 else fallback_index


func _on_start_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	GameState.configure_skirmish(
		map_option.selected,
		difficulty_option.selected,
		STARTING_CREDITS_VALUES[starting_credits_option.selected],
		match_speed_option.selected,
		OUTPOST_COUNT_VALUES[outpost_count_option.selected]
	)
	GameState.reset_match_state()
	Economy.reset()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_back_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_cancel")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
