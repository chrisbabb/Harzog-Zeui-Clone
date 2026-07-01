extends Node
## Autoload singleton providing placeholder sound effects and music.
## Every gameplay/UI audio event gets a short procedurally-generated tone so
## the game has audio feedback before real assets exist. Dropping a
## same-named .wav/.ogg file into assets/audio/placeholder/ (e.g.
## "commander_fire.wav" or "battle_music.ogg") is picked up automatically and
## takes priority over the generated tone/silence -- no script changes needed
## to swap in real assets later.

enum MusicTrack { NONE, MENU, BATTLE, VICTORY, DEFEAT }

const SFX_DIR: String = "res://assets/audio/placeholder/"
const SFX_POOL_SIZE: int = 8
const MIX_RATE: int = 44100

const LOW_FUEL_RATIO: float = 0.2
const LOW_AMMO_RATIO: float = 0.2

## Per-event placeholder tone definition: frequency (Hz), duration (seconds),
## and a simple waveform shape. Explosions use "noise" for a percussive thump
## rather than a clean pitch.
const SFX_DEFS: Dictionary = {
	"commander_fire": {"frequency": 880.0, "duration": 0.08, "wave": "square"},
	"unit_fire": {"frequency": 660.0, "duration": 0.06, "wave": "square"},
	"explosion_small": {"frequency": 140.0, "duration": 0.25, "wave": "noise"},
	"explosion_large": {"frequency": 90.0, "duration": 0.45, "wave": "noise"},
	"unit_created": {"frequency": 523.25, "duration": 0.12, "wave": "sine"},
	"unit_picked_up": {"frequency": 660.0, "duration": 0.10, "wave": "sine"},
	"unit_dropped": {"frequency": 440.0, "duration": 0.10, "wave": "sine"},
	"building_captured": {"frequency": 784.0, "duration": 0.30, "wave": "sine"},
	"low_fuel_warning": {"frequency": 330.0, "duration": 0.20, "wave": "triangle"},
	"low_ammo_warning": {"frequency": 392.0, "duration": 0.20, "wave": "triangle"},
	"victory": {"frequency": 880.0, "duration": 0.60, "wave": "sine"},
	"defeat": {"frequency": 196.0, "duration": 0.60, "wave": "triangle"},
	"ui_select": {"frequency": 988.0, "duration": 0.05, "wave": "square"},
	"ui_cancel": {"frequency": 220.0, "duration": 0.07, "wave": "square"},
}

## Base filenames looked up under SFX_DIR for each music track. No generated
## fallback for music -- a missing file just means silence (see play_music()).
const MUSIC_FILENAMES: Dictionary = {
	MusicTrack.MENU: "menu_music",
	MusicTrack.BATTLE: "battle_music",
	MusicTrack.VICTORY: "victory_music",
	MusicTrack.DEFEAT: "defeat_music",
}

var master_volume: float = 1.0
var music_volume: float = 0.6
var sfx_volume: float = 0.8

var _sfx_cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_player: int = 0
var _music_player: AudioStreamPlayer
var _current_music_track: int = MusicTrack.NONE
var _was_fuel_low: bool = false
var _was_ammo_low: bool = false


func _ready() -> void:
	# Audio feedback (menu clicks, pause-menu buttons) should keep working
	# while get_tree().paused is true.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_sfx_pool()
	_create_music_player()
	_pregenerate_sfx()
	_apply_volumes()

	EventBus.audio_event_requested.connect(play_sfx)
	EventBus.unit_created.connect(_on_unit_created)
	EventBus.unit_picked_up.connect(_on_unit_picked_up)
	EventBus.unit_dropped.connect(_on_unit_dropped)
	EventBus.building_captured.connect(_on_building_captured)
	EventBus.commander_fuel_changed.connect(_on_commander_fuel_changed)
	EventBus.commander_ammo_changed.connect(_on_commander_ammo_changed)
	EventBus.match_started.connect(_on_match_started)
	EventBus.match_ended.connect(_on_match_ended)


## Plays a one-shot sound by event name from a small round-robin player pool.
## Unknown event names (or events with neither a placeholder file nor a tone
## definition) are silently ignored rather than erroring.
func play_sfx(event_name: String) -> void:
	var stream: AudioStream = _get_or_build_sfx(event_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_players[_next_sfx_player]
	_next_sfx_player = (_next_sfx_player + 1) % _sfx_players.size()
	player.stream = stream
	player.play()


## Switches background music to the given track. Looks for a placeholder
## file under SFX_DIR; if none exists yet, music simply stays silent.
func play_music(track: int) -> void:
	if track == _current_music_track:
		return
	_current_music_track = track
	_music_player.stop()
	_music_player.stream = _load_music_stream(track)
	if _music_player.stream != null:
		_music_player.play()


func stop_music() -> void:
	_current_music_track = MusicTrack.NONE
	_music_player.stop()


func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()


func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_volumes()


## Extension points for a future SaveManager to persist/restore volume
## settings without this script needing to know anything about save files.
func get_volume_settings() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
	}


func apply_volume_settings(settings: Dictionary) -> void:
	set_master_volume(settings.get("master_volume", master_volume))
	set_music_volume(settings.get("music_volume", music_volume))
	set_sfx_volume(settings.get("sfx_volume", sfx_volume))


func _create_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)


func _create_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)


func _pregenerate_sfx() -> void:
	for event_name in SFX_DEFS.keys():
		_get_or_build_sfx(event_name)


func _apply_volumes() -> void:
	var sfx_db: float = linear_to_db(clamp(master_volume * sfx_volume, 0.0, 1.0))
	for player in _sfx_players:
		player.volume_db = sfx_db
	if _music_player != null:
		_music_player.volume_db = linear_to_db(clamp(master_volume * music_volume, 0.0, 1.0))


func _on_unit_created(_unit: Node) -> void:
	play_sfx("unit_created")


func _on_unit_picked_up(_unit: Node) -> void:
	play_sfx("unit_picked_up")


func _on_unit_dropped(_unit: Node) -> void:
	play_sfx("unit_dropped")


func _on_building_captured(_building: Node, _new_team: int) -> void:
	play_sfx("building_captured")


## commander_fuel_changed/commander_ammo_changed only ever fire for the
## player commander (see Commander.gd/EnemyCommanderBot.gd), so these warnings
## are naturally player-only. Only fires once per crossing into "low",
## not on every frame the value stays low.
func _on_commander_fuel_changed(_team: int, value: float) -> void:
	var is_low: bool = value <= Constants.MAX_PLAYER_FUEL * LOW_FUEL_RATIO
	if is_low and not _was_fuel_low:
		play_sfx("low_fuel_warning")
	_was_fuel_low = is_low


func _on_commander_ammo_changed(_team: int, value: float) -> void:
	var is_low: bool = value <= Constants.MAX_PLAYER_AMMO * LOW_AMMO_RATIO
	if is_low and not _was_ammo_low:
		play_sfx("low_ammo_warning")
	_was_ammo_low = is_low


func _on_match_started() -> void:
	_was_fuel_low = false
	_was_ammo_low = false
	play_music(MusicTrack.BATTLE)


func _on_match_ended(winning_team: int) -> void:
	var is_victory: bool = winning_team == Constants.Team.PLAYER
	play_sfx("victory" if is_victory else "defeat")
	play_music(MusicTrack.VICTORY if is_victory else MusicTrack.DEFEAT)


func _get_or_build_sfx(event_name: String) -> AudioStream:
	if _sfx_cache.has(event_name):
		return _sfx_cache[event_name]

	var stream: AudioStream = _load_placeholder_file(event_name)
	if stream == null and SFX_DEFS.has(event_name):
		var def: Dictionary = SFX_DEFS[event_name]
		stream = _generate_tone(def["frequency"], def["duration"], def["wave"])

	_sfx_cache[event_name] = stream
	return stream


func _load_music_stream(track: int) -> AudioStream:
	if not MUSIC_FILENAMES.has(track):
		return null
	return _load_placeholder_file(MUSIC_FILENAMES[track])


func _load_placeholder_file(base_name: String) -> AudioStream:
	for extension in ["wav", "ogg"]:
		var path: String = "%s%s.%s" % [SFX_DIR, base_name, extension]
		if ResourceLoader.exists(path):
			var loaded: Resource = ResourceLoader.load(path)
			if loaded is AudioStream:
				return loaded
	return null


## Synthesizes a short mono 16-bit tone in memory -- no imported audio
## assets required. A linear fade-out envelope avoids an audible click at
## the end of the clip.
func _generate_tone(frequency: float, duration: float, wave: String) -> AudioStreamWAV:
	var sample_count: int = max(1, int(MIX_RATE * duration))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t: float = float(i) / MIX_RATE
		var envelope: float = 1.0 - (float(i) / float(sample_count))
		var sample: float = clamp(_wave_sample(wave, frequency, t) * envelope, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _wave_sample(wave: String, frequency: float, t: float) -> float:
	var phase: float = fmod(frequency * t, 1.0)
	match wave:
		"square":
			return 1.0 if phase < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(phase - 0.5) - 1.0
		"noise":
			return randf_range(-1.0, 1.0)
		_:
			return sin(phase * TAU)
