extends Node
## AudioManager - Handles all audio playback and volume control
##
## Features:
## - Master, Music, and SFX volume controls
## - Mute toggle
## - Audio bus management
## - Music playback
## - Sound effect playback

# Audio buses (defined in Audio settings)
const BUS_MASTER = "Master"
const BUS_MUSIC = "Music"
const BUS_SFX = "SFX"

# Volume settings (0.0 to 1.0)
var master_volume: float = 0.8
var music_volume: float = 0.7
var sfx_volume: float = 0.9
var is_muted: bool = false

# Current music player
var music_player: AudioStreamPlayer
var music_tracks: Dictionary = {}

# SFX player pool
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS = 16


func _ready() -> void:
	print("AudioManager initialized")
	_setup_audio_buses()
	_setup_music_player()
	_setup_sfx_pool()
	apply_volume_settings()


## Setup audio buses
func _setup_audio_buses() -> void:
	# Audio buses should be configured in Project Settings > Audio
	# This ensures the buses exist
	for bus_name in [BUS_MASTER, BUS_MUSIC, BUS_SFX]:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx == -1:
			push_warning("Audio bus '%s' not found. Please configure in project settings." % bus_name)


## Setup music player
func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = BUS_MUSIC
	add_child(music_player)


## Setup SFX player pool
func _setup_sfx_pool() -> void:
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = BUS_SFX
		add_child(player)
		sfx_players.append(player)


## Set master volume (0.0 to 1.0)
func set_master_volume(volume: float) -> void:
	master_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()


## Set music volume (0.0 to 1.0)
func set_music_volume(volume: float) -> void:
	music_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()


## Set SFX volume (0.0 to 1.0)
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clamp(volume, 0.0, 1.0)
	apply_volume_settings()


## Toggle mute
func toggle_mute() -> void:
	is_muted = not is_muted
	apply_volume_settings()


## Apply volume settings to audio buses
func apply_volume_settings() -> void:
	if is_muted:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MASTER), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index(BUS_MASTER), false)

		# Convert linear volume (0-1) to decibels
		var master_db = linear_to_db(master_volume)
		var music_db = linear_to_db(music_volume)
		var sfx_db = linear_to_db(sfx_volume)

		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MASTER), master_db)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), music_db)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), sfx_db)


## Play music track
func play_music(track_name: String, loop: bool = true) -> void:
	if music_tracks.has(track_name):
		music_player.stream = music_tracks[track_name]
		music_player.play()
		if loop:
			music_player.finished.connect(_on_music_finished)


## Stop music
func stop_music() -> void:
	music_player.stop()


## Play sound effect
func play_sfx(sound: AudioStream, volume_db: float = 0.0) -> void:
	var player = _get_available_sfx_player()
	if player:
		player.stream = sound
		player.volume_db = volume_db
		player.play()


## Get an available SFX player from the pool
func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player

	# If all players are busy, return the first one (will interrupt)
	return sfx_players[0]


## Music finished callback (for looping)
func _on_music_finished() -> void:
	music_player.play()


## Register a music track
func register_music_track(track_name: String, stream: AudioStream) -> void:
	music_tracks[track_name] = stream


## Convert linear volume to decibels
func linear_to_db(linear: float) -> float:
	if linear <= 0.0:
		return -80.0  # Effective silence
	return 20.0 * log(linear) / log(10.0)
