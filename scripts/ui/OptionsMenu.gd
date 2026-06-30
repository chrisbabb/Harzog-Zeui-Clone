extends Control
## Options menu: audio sliders, fullscreen, difficulty, and camera shake.
## Self-contained -- instantiated on demand by MainMenu/PauseMenu and frees
## itself when Back is pressed. Every control applies its setting immediately
## through SaveManager, which persists to disk and pushes the value out to
## whichever system actually uses it (AudioManager, DisplayServer, etc.).

const DIFFICULTY_LABELS: Array[String] = ["Easy", "Normal", "Hard"]

@onready var master_slider: HSlider = $Panel/VBoxContainer/MasterVolumeSlider
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicVolumeSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SfxVolumeSlider
@onready var fullscreen_check: CheckButton = $Panel/VBoxContainer/FullscreenCheckButton
@onready var difficulty_option: OptionButton = $Panel/VBoxContainer/DifficultyOptionButton
@onready var camera_shake_check: CheckButton = $Panel/VBoxContainer/CameraShakeCheckButton
@onready var back_button: Button = $Panel/VBoxContainer/BackButton


func _ready() -> void:
	# Stays interactive if opened from the (paused) PauseMenu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_populate_difficulty_options()
	_load_current_values()

	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	difficulty_option.item_selected.connect(_on_difficulty_selected)
	camera_shake_check.toggled.connect(_on_camera_shake_toggled)
	back_button.pressed.connect(_on_back_pressed)


func _populate_difficulty_options() -> void:
	for label in DIFFICULTY_LABELS:
		difficulty_option.add_item(label)


func _load_current_values() -> void:
	master_slider.value = SaveManager.master_volume
	music_slider.value = SaveManager.music_volume
	sfx_slider.value = SaveManager.sfx_volume
	fullscreen_check.button_pressed = SaveManager.fullscreen
	difficulty_option.select(clamp(SaveManager.difficulty, 0, DIFFICULTY_LABELS.size() - 1))
	camera_shake_check.button_pressed = SaveManager.camera_shake


func _on_master_volume_changed(value: float) -> void:
	SaveManager.set_master_volume(value)


func _on_music_volume_changed(value: float) -> void:
	SaveManager.set_music_volume(value)


func _on_sfx_volume_changed(value: float) -> void:
	SaveManager.set_sfx_volume(value)


func _on_fullscreen_toggled(pressed: bool) -> void:
	SaveManager.set_fullscreen(pressed)


func _on_difficulty_selected(index: int) -> void:
	SaveManager.set_difficulty(index)


func _on_camera_shake_toggled(pressed: bool) -> void:
	SaveManager.set_camera_shake(pressed)


func _on_back_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_cancel")
	queue_free()
