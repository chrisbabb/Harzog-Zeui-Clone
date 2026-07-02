extends Control
## Match-end result screen: a large VICTORY/DEFEAT banner that drops in
## after the end cinematic's explosion beat, followed by the full stats
## panel (duration, units, outposts, credits, commander deaths) and
## rematch/main-menu buttons. Purely presentational -- HUD.gd gathers the
## stats and calls show_result() once; the single-fire latch here is the
## last line of defense against a double match_ended ever reaching the
## screen.

## Real-time delay before the banner appears, sized so MatchCinematics'
## end sequence (camera pan + slow-mo explosion or shake, ~2s real time)
## finishes first. Uses an ignore-time-scale timer since the end sequence
## manipulates Engine.time_scale.
const APPEAR_DELAY: float = 2.4
const BANNER_START_SCALE: float = 1.5
const BANNER_IN_DURATION: float = 0.45
const DIM_IN_DURATION: float = 0.35
const PANEL_IN_DURATION: float = 0.35

const MAIN_MENU_SCENE_PATH: String = "res://scenes/ui/MainMenu.tscn"

@onready var _dim: ColorRect = $Dim
@onready var _banner: Label = $Banner
@onready var _center_panel: Panel = $CenterPanel
@onready var _duration_value: Label = $CenterPanel/M/Box/Stats/DurationValue
@onready var _built_value: Label = $CenterPanel/M/Box/Stats/BuiltValue
@onready var _destroyed_value: Label = $CenterPanel/M/Box/Stats/DestroyedValue
@onready var _lost_value: Label = $CenterPanel/M/Box/Stats/LostValue
@onready var _captured_value: Label = $CenterPanel/M/Box/Stats/CapturedValue
@onready var _earned_value: Label = $CenterPanel/M/Box/Stats/EarnedValue
@onready var _deaths_value: Label = $CenterPanel/M/Box/Stats/DeathsValue
@onready var _rematch_button: Button = $CenterPanel/M/Box/Buttons/RematchButton
@onready var _main_menu_button: Button = $CenterPanel/M/Box/Buttons/MainMenuButton

var _shown: bool = false


func _ready() -> void:
	_rematch_button.pressed.connect(_on_rematch_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)


## Latched: only the first call ever shows anything.
func show_result(victory: bool, stats: Dictionary) -> void:
	if _shown:
		return
	_shown = true

	_banner.text = "VICTORY" if victory else "DEFEAT"
	_banner.add_theme_color_override("font_color",
		UIThemeFactory.SUCCESS_COLOR if victory else UIThemeFactory.DANGER_COLOR)
	_populate_stats(stats)

	# process_always=false so the delay waits out a paused tree instead of
	# popping the panel over the pause menu.
	get_tree().create_timer(APPEAR_DELAY, false, false, true).timeout.connect(_animate_in)


func _populate_stats(stats: Dictionary) -> void:
	_duration_value.text = _format_time(stats.get("duration", 0.0))
	_built_value.text = str(int(stats.get("built", 0)))
	_destroyed_value.text = str(int(stats.get("destroyed", 0)))
	_lost_value.text = str(int(stats.get("lost", 0)))
	_captured_value.text = str(int(stats.get("captured", 0)))
	_earned_value.text = "%d cr" % int(stats.get("earned", 0.0))
	_deaths_value.text = str(int(stats.get("commander_deaths", 0)))


func _animate_in() -> void:
	# Visible first (alphas are all zeroed below, so nothing flashes) so the
	# banner has a laid-out size before it's used as the scale pivot.
	visible = true
	_dim.modulate.a = 0.0
	_banner.modulate.a = 0.0
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2.ONE * BANNER_START_SCALE
	_center_panel.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_dim, "modulate:a", 1.0, DIM_IN_DURATION)
	tween.tween_property(_banner, "modulate:a", 1.0, BANNER_IN_DURATION)
	tween.tween_property(_banner, "scale", Vector2.ONE, BANNER_IN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(_center_panel, "modulate:a", 1.0, PANEL_IN_DURATION)
	tween.chain().tween_callback(_rematch_button.grab_focus)


func _on_rematch_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_select")
	GameState.reset_match_state()
	Economy.reset()
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	EventBus.audio_event_requested.emit("ui_cancel")
	GameState.reset_match_state()
	Economy.reset()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _format_time(seconds: float) -> String:
	var secs: int = int(seconds)
	return "%02d:%02d" % [secs / 60, secs % 60]
