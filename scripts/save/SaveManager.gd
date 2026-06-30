extends Node
## Autoload singleton persisting player settings (audio, display, gameplay
## preferences) to user://settings.json. Owns persistence and current values;
## pushes loaded/changed values out to whichever system actually uses them
## (AudioManager for volume, DisplayServer for fullscreen/resolution, etc.)
## so every setting takes effect immediately, not just on next launch.

const SAVE_PATH: String = "user://settings.json"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

const DEFAULT_SETTINGS: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.6,
	"sfx_volume": 0.8,
	"fullscreen": false,
	"resolution_index": 2,
	"camera_shake": true,
	"minimap_size": 0,
	"difficulty": 1,
}

var master_volume: float = DEFAULT_SETTINGS["master_volume"]
var music_volume: float = DEFAULT_SETTINGS["music_volume"]
var sfx_volume: float = DEFAULT_SETTINGS["sfx_volume"]
var fullscreen: bool = DEFAULT_SETTINGS["fullscreen"]
var resolution_index: int = DEFAULT_SETTINGS["resolution_index"]
var camera_shake: bool = DEFAULT_SETTINGS["camera_shake"]
var minimap_size: int = DEFAULT_SETTINGS["minimap_size"]
var difficulty: int = DEFAULT_SETTINGS["difficulty"]


func _ready() -> void:
	load_settings()


## Writes the current settings to disk as JSON. A failure to open the file
## (e.g. read-only filesystem) is silently ignored -- losing persistence
## shouldn't crash or interrupt play.
func save_settings() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(_to_dict()))


## Reads settings from disk if present, falling back to defaults for any
## missing/invalid fields, then applies them. Safe to call even if the save
## file doesn't exist yet (first launch).
func load_settings() -> void:
	var loaded: Dictionary = DEFAULT_SETTINGS.duplicate()
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				for key in loaded.keys():
					if parsed.has(key):
						loaded[key] = parsed[key]

	_apply_dict(loaded)
	_apply_all()


## Restores every setting to its default, applies it, and persists the reset.
func reset_settings() -> void:
	_apply_dict(DEFAULT_SETTINGS.duplicate())
	_apply_all()
	save_settings()


func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	AudioManager.set_master_volume(master_volume)
	save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	AudioManager.set_music_volume(music_volume)
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	AudioManager.set_sfx_volume(sfx_volume)
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_display_settings()
	save_settings()


func set_difficulty(value: int) -> void:
	difficulty = clamp(value, 0, 2)
	save_settings()


func set_camera_shake(value: bool) -> void:
	camera_shake = value
	save_settings()


func _to_dict() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"fullscreen": fullscreen,
		"resolution_index": resolution_index,
		"camera_shake": camera_shake,
		"minimap_size": minimap_size,
		"difficulty": difficulty,
	}


func _apply_dict(values: Dictionary) -> void:
	master_volume = values.get("master_volume", master_volume)
	music_volume = values.get("music_volume", music_volume)
	sfx_volume = values.get("sfx_volume", sfx_volume)
	fullscreen = values.get("fullscreen", fullscreen)
	resolution_index = values.get("resolution_index", resolution_index)
	camera_shake = values.get("camera_shake", camera_shake)
	minimap_size = values.get("minimap_size", minimap_size)
	difficulty = values.get("difficulty", difficulty)


func _apply_all() -> void:
	AudioManager.apply_volume_settings({
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	})
	_apply_display_settings()


func _apply_display_settings() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if not fullscreen:
		var index: int = clamp(resolution_index, 0, RESOLUTIONS.size() - 1)
		DisplayServer.window_set_size(RESOLUTIONS[index])
