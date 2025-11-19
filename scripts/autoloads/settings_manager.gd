extends Node
## SettingsManager - Persistent settings storage and management
##
## Handles:
## - Saving/loading settings to disk
## - Video settings (resolution, fullscreen)
## - Audio settings (volumes)
## - Input settings (key bindings)

const SETTINGS_FILE_PATH = "user://settings.json"

# Settings data structure
var settings: Dictionary = {
	"video": {
		"fullscreen": true,
		"resolution": "1920x1080",
		"vsync": true
	},
	"audio": {
		"master_volume": 0.8,
		"music_volume": 0.7,
		"sfx_volume": 0.9,
		"muted": false
	},
	"input": {
		# Will be populated by InputManager
		"player_bindings": {}
	}
}

# Available resolutions
const AVAILABLE_RESOLUTIONS = [
	"1280x720",
	"1920x1080",
	"2560x1440",
	"3840x2160"
]


func _ready() -> void:
	print("SettingsManager initialized")
	load_settings()
	apply_all_settings()


## Load settings from disk
func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		print("No settings file found, using defaults")
		save_settings()
		return

	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK:
			var loaded_data = json.data
			if typeof(loaded_data) == TYPE_DICTIONARY:
				# Merge loaded data with defaults
				_deep_merge(settings, loaded_data)
				print("Settings loaded successfully")
		else:
			push_error("Failed to parse settings JSON: %s" % json.get_error_message())


## Save settings to disk
func save_settings() -> void:
	var file = FileAccess.open(SETTINGS_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(settings, "\t")
		file.store_string(json_string)
		file.close()
		print("Settings saved successfully")
	else:
		push_error("Failed to save settings file")


## Apply all settings
func apply_all_settings() -> void:
	apply_video_settings()
	apply_audio_settings()


## Apply video settings
func apply_video_settings() -> void:
	var video = settings.video

	# Fullscreen
	if video.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# Resolution
	var res_parts = video.resolution.split("x")
	if res_parts.size() == 2:
		var width = int(res_parts[0])
		var height = int(res_parts[1])
		DisplayServer.window_set_size(Vector2i(width, height))

	# VSync
	if video.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


## Apply audio settings
func apply_audio_settings() -> void:
	var audio = settings.audio

	AudioManager.master_volume = audio.master_volume
	AudioManager.music_volume = audio.music_volume
	AudioManager.sfx_volume = audio.sfx_volume
	AudioManager.is_muted = audio.muted
	AudioManager.apply_volume_settings()


## Set video setting
func set_video_setting(key: String, value) -> void:
	settings.video[key] = value
	apply_video_settings()
	save_settings()


## Set audio setting
func set_audio_setting(key: String, value) -> void:
	settings.audio[key] = value
	apply_audio_settings()
	save_settings()


## Get current resolution as Vector2i
func get_current_resolution() -> Vector2i:
	var res_parts = settings.video.resolution.split("x")
	if res_parts.size() == 2:
		return Vector2i(int(res_parts[0]), int(res_parts[1]))
	return Vector2i(1920, 1080)


## Deep merge two dictionaries
func _deep_merge(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if target.has(key) and typeof(target[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			_deep_merge(target[key], source[key])
		else:
			target[key] = source[key]
