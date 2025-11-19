extends Control
## SettingsMenu - Configure video, audio, and input settings


func _ready() -> void:
	GameManager.current_state = GameManager.GameState.SETTINGS
	_load_current_settings()


## Load current settings from SettingsManager
func _load_current_settings() -> void:
	# Video settings
	var fullscreen_toggle = $MarginContainer/VBoxContainer/VideoSettings/FullscreenToggle
	fullscreen_toggle.button_pressed = SettingsManager.settings.video.fullscreen

	# Setup resolution dropdown
	var resolution_option = $MarginContainer/VBoxContainer/VideoSettings/ResolutionContainer/ResolutionOption
	resolution_option.clear()
	var current_res = SettingsManager.settings.video.resolution
	var current_index = 0
	for i in range(SettingsManager.AVAILABLE_RESOLUTIONS.size()):
		var res = SettingsManager.AVAILABLE_RESOLUTIONS[i]
		resolution_option.add_item(res)
		if res == current_res:
			current_index = i
	resolution_option.selected = current_index

	# Audio settings
	var master_slider = $MarginContainer/VBoxContainer/AudioSettings/MasterVolumeContainer/MasterSlider
	var music_slider = $MarginContainer/VBoxContainer/AudioSettings/MusicVolumeContainer/MusicSlider
	var sfx_slider = $MarginContainer/VBoxContainer/AudioSettings/SFXVolumeContainer/SFXSlider
	var mute_toggle = $MarginContainer/VBoxContainer/AudioSettings/MuteToggle

	master_slider.value = SettingsManager.settings.audio.master_volume * 100.0
	music_slider.value = SettingsManager.settings.audio.music_volume * 100.0
	sfx_slider.value = SettingsManager.settings.audio.sfx_volume * 100.0
	mute_toggle.button_pressed = SettingsManager.settings.audio.muted

	_update_volume_labels()


## Update volume value labels
func _update_volume_labels() -> void:
	var master_label = $MarginContainer/VBoxContainer/AudioSettings/MasterVolumeContainer/ValueLabel
	var music_label = $MarginContainer/VBoxContainer/AudioSettings/MusicVolumeContainer/ValueLabel
	var sfx_label = $MarginContainer/VBoxContainer/AudioSettings/SFXVolumeContainer/ValueLabel

	var master_slider = $MarginContainer/VBoxContainer/AudioSettings/MasterVolumeContainer/MasterSlider
	var music_slider = $MarginContainer/VBoxContainer/AudioSettings/MusicVolumeContainer/MusicSlider
	var sfx_slider = $MarginContainer/VBoxContainer/AudioSettings/SFXVolumeContainer/SFXSlider

	master_label.text = str(int(master_slider.value))
	music_label.text = str(int(music_slider.value))
	sfx_label.text = str(int(sfx_slider.value))


## Fullscreen toggled
func _on_fullscreen_toggled(toggled_on: bool) -> void:
	SettingsManager.set_video_setting("fullscreen", toggled_on)


## Resolution selected
func _on_resolution_selected(index: int) -> void:
	var resolution_option = $MarginContainer/VBoxContainer/VideoSettings/ResolutionContainer/ResolutionOption
	var resolution = resolution_option.get_item_text(index)
	SettingsManager.set_video_setting("resolution", resolution)


## Master volume changed
func _on_master_volume_changed(value: float) -> void:
	SettingsManager.set_audio_setting("master_volume", value / 100.0)
	_update_volume_labels()


## Music volume changed
func _on_music_volume_changed(value: float) -> void:
	SettingsManager.set_audio_setting("music_volume", value / 100.0)
	_update_volume_labels()


## SFX volume changed
func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.set_audio_setting("sfx_volume", value / 100.0)
	_update_volume_labels()


## Mute toggled
func _on_mute_toggled(toggled_on: bool) -> void:
	SettingsManager.set_audio_setting("muted", toggled_on)


## Back to main menu
func _on_back_pressed() -> void:
	GameManager.return_to_main_menu()


## Apply settings (already applied in real-time, but this confirms)
func _on_apply_pressed() -> void:
	SettingsManager.save_settings()
	# Show confirmation message (TODO: Add proper dialog)
	print("Settings applied and saved!")
