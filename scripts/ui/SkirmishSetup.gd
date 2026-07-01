extends Control
## Skirmish setup screen: choose game mode, map, difficulty, starting credits,
## match speed, outpost count, and (for local multiplayer) split direction
## before a match starts. Reached from MainMenu's Start Skirmish button.

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const LOCAL_MP_SCENE_PATH: String = "res://scenes/main/LocalMultiplayer.tscn"
const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/MainMenu.tscn"

const MODE_LABELS: Array[String] = ["Single Player vs AI", "Local Multiplayer"]
const SPLIT_LABELS: Array[String] = ["Vertical (Side by Side)", "Horizontal (Top / Bottom)"]
const MAP_LABELS: Array[String] = ["Green Divide", "Iron Basin", "Ash Line"]
const DIFFICULTY_LABELS: Array[String] = ["Easy", "Normal", "Hard"]
const STARTING_CREDITS_VALUES: Array[int] = [500, 800, 1200]
const MATCH_SPEED_LABELS: Array[String] = ["Normal", "Fast"]
const OUTPOST_COUNT_VALUES: Array[int] = [5, 7, 9]

@onready var mode_option: OptionButton = $Panel/VBoxContainer/ModeOptionButton
@onready var split_label: Label = $Panel/VBoxContainer/SplitLabel
@onready var split_option: OptionButton = $Panel/VBoxContainer/SplitOptionButton
@onready var difficulty_label: Label = $Panel/VBoxContainer/DifficultyLabel
@onready var difficulty_option: OptionButton = $Panel/VBoxContainer/DifficultyOptionButton
@onready var map_option: OptionButton = $Panel/VBoxContainer/MapOptionButton
@onready var starting_credits_option: OptionButton = $Panel/VBoxContainer/StartingCreditsOptionButton
@onready var match_speed_option: OptionButton = $Panel/VBoxContainer/MatchSpeedOptionButton
@onready var outpost_count_option: OptionButton = $Panel/VBoxContainer/OutpostCountOptionButton
@onready var start_button: Button = $Panel/VBoxContainer/StartButton
@onready var back_button: Button = $Panel/VBoxContainer/BackButton


func _ready() -> void:
	_populate_options()
	_load_defaults()
	_refresh_mode_visibility()

	mode_option.item_selected.connect(_on_mode_selected)
	start_button.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_back_pressed)
	start_button.grab_focus()


func _populate_options() -> void:
	for label in MODE_LABELS:
		mode_option.add_item(label)
	for label in SPLIT_LABELS:
		split_option.add_item(label)
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
	mode_option.select(clamp(GameState.game_mode, 0, MODE_LABELS.size() - 1))
	split_option.select(clamp(GameState.split_direction, 0, SPLIT_LABELS.size() - 1))
	map_option.select(clamp(GameState.selected_map, 0, MAP_LABELS.size() - 1))
	difficulty_option.select(clamp(SaveManager.difficulty, 0, DIFFICULTY_LABELS.size() - 1))
	starting_credits_option.select(_index_of_int(STARTING_CREDITS_VALUES, GameState.selected_starting_credits, 1))
	match_speed_option.select(clamp(GameState.selected_match_speed, 0, MATCH_SPEED_LABELS.size() - 1))
	outpost_count_option.select(_index_of_int(OUTPOST_COUNT_VALUES, GameState.selected_outpost_count, 1))


func _index_of_int(values: Array[int], value: int, fallback_index: int) -> int:
	var found_index: int = values.find(value)
	return found_index if found_index != -1 else fallback_index


func _on_mode_selected(_index: int) -> void:
	_refresh_mode_visibility()


func _refresh_mode_visibility() -> void:
	var is_local_mp: bool = mode_option.selected == Constants.GameMode.LOCAL_MULTIPLAYER
	split_label.visible = is_local_mp
	split_option.visible = is_local_mp
	difficulty_label.visible = not is_local_mp
	difficulty_option.visible = not is_local_mp


func _on_start_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	var mode: int = mode_option.selected
	var split: int = split_option.selected
	GameState.configure_skirmish(
		map_option.selected,
		difficulty_option.selected,
		STARTING_CREDITS_VALUES[starting_credits_option.selected],
		match_speed_option.selected,
		OUTPOST_COUNT_VALUES[outpost_count_option.selected],
		mode,
		split
	)
	GameState.reset_match_state()
	Economy.reset()
	if mode == Constants.GameMode.LOCAL_MULTIPLAYER:
		get_tree().change_scene_to_file(LOCAL_MP_SCENE_PATH)
	else:
		get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_back_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_cancel")
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
