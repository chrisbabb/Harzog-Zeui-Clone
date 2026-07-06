extends CanvasLayer
## Full in-match HUD: resource readout, commander panel, HQ health bars,
## match timer, build/command menus, pause menu, notification toasts, and
## match-end overlay. In local multiplayer each player has their own HUD
## instance with a different team value so signals and polling are filtered
## per-player.

const HUD_POLL_INTERVAL: float = 0.1
const CREDITS_LERP_SPEED: float = 5.0
const BAR_LERP_SPEED: float = 9.0
const LOW_FUEL_RATIO: float = 0.2 ## Mirrors AudioManager.LOW_FUEL_RATIO.
const LOW_AMMO_RATIO: float = 0.2 ## Mirrors AudioManager.LOW_AMMO_RATIO.
const HQ_ATTACK_NOTIFICATION_COOLDOWN: float = 6.0
const NOTIFICATION_DURATION: float = 3.5
const NOTIFICATION_FADE_DURATION: float = 0.35
const MAX_NOTIFICATIONS: int = 4
const NOTIFICATION_FONT_SIZE: int = 14

# Which team this HUD belongs to. Set before adding to the tree in local
# multiplayer; leave at PLAYER for single-player and tutorial scenes.
@export var team: int = Constants.Team.PLAYER

var _units_built: int = 0
var _units_lost: int = 0
var _units_destroyed: int = 0
var _outposts_captured: int = 0
var _commander_deaths: int = 0

var _hud_poll_timer: float = 0.0
var _prev_unit_type: int = -1
var _prev_order: int = -1

var _displayed_credits: float = 0.0
var _target_credits: float = 0.0

# Bars ease toward these targets in _process instead of snapping (see
# _approach_bar); the targets are what the signal handlers/pollers write.
var _hp_bar_target: float = 0.0
var _fuel_bar_target: float = 0.0
var _ammo_bar_target: float = 0.0
var _enemy_hq_bar_target: float = 0.0
var _player_hq_bar_target: float = 0.0
var _was_fuel_low: bool = false
var _was_ammo_low: bool = false
var _fuel_warning_tween: Tween = null
var _ammo_warning_tween: Tween = null
var _hq_attack_notification_timer: float = 0.0

@onready var _credits_label: Label = $Root/TopLeft/M/Box/CreditsLabel
@onready var _income_label: Label = $Root/TopLeft/M/Box/IncomeLabel
@onready var _outposts_label: Label = $Root/TopLeft/M/Box/OutpostsLabel
@onready var _timer_label: Label = $Root/TopCenter/M/Box/TimerLabel
@onready var _enemy_hq_label: Label = $Root/TopRight/M/Box/EnemyHQLabel
@onready var _enemy_hq_bar: ProgressBar = $Root/TopRight/M/Box/EnemyHQBar
@onready var _player_hq_label: Label = $Root/TopRight/M/Box/PlayerHQLabel
@onready var _player_hq_bar: ProgressBar = $Root/TopRight/M/Box/PlayerHQBar
@onready var _mode_label: Label = $Root/CommanderPanel/M/Box/HeaderRow/HeaderCol/ModeRow/ModeLabel
@onready var _mode_icon: ColorRect = $Root/CommanderPanel/M/Box/HeaderRow/HeaderCol/ModeRow/ModeIcon
@onready var _hp_bar: ProgressBar = $Root/CommanderPanel/M/Box/HPRow/HPBar
@onready var _fuel_bar: ProgressBar = $Root/CommanderPanel/M/Box/FuelRow/FuelBar
@onready var _ammo_bar: ProgressBar = $Root/CommanderPanel/M/Box/AmmoRow/AmmoBar
@onready var _carrying_icon: TacticalIcon = $Root/CommanderPanel/M/Box/CarryingRow/CarryingIcon
@onready var _carrying_label: Label = $Root/CommanderPanel/M/Box/CarryingRow/CarryingLabel
@onready var _selected_unit_label: Label = $Root/BottomCenter/M/Box/SelectedUnitLabel
@onready var _selected_order_label: Label = $Root/BottomCenter/M/Box/SelectedOrderLabel
@onready var _notification_list: VBoxContainer = $Root/BottomCenter/M/Box/NotificationList
@onready var _result_panel: Control = $MatchResultPanel
@onready var _pause_menu: Control = $PauseMenu
@onready var _commander_panel: Panel = $Root/CommanderPanel
@onready var _top_left: Panel = $Root/TopLeft
@onready var _top_right: Panel = $Root/TopRight
@onready var _bottom_center: Panel = $Root/BottomCenter


func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.commander_mode_changed.connect(_on_commander_mode_changed)
	EventBus.commander_fuel_changed.connect(_on_commander_fuel_changed)
	EventBus.commander_ammo_changed.connect(_on_commander_ammo_changed)
	EventBus.building_captured.connect(_on_building_captured)
	EventBus.building_damaged.connect(_on_building_damaged)
	EventBus.unit_created.connect(_on_unit_created)
	EventBus.unit_destroyed.connect(_on_unit_destroyed)
	EventBus.hud_message.connect(_on_hud_message)
	EventBus.enemy_wave_launched.connect(_on_enemy_wave_launched)
	EventBus.commander_died.connect(_on_commander_died)
	EventBus.match_ended.connect(_on_match_ended)

	UIThemeFactory.apply_team_accent(_commander_panel, team)
	UIThemeFactory.apply_team_accent(_top_left, team)
	UIThemeFactory.apply_team_accent(_top_right, team)
	UIThemeFactory.apply_team_accent(_bottom_center, team)

	_displayed_credits = Economy.get_money(team)
	_target_credits = _displayed_credits
	_credits_label.text = "Credits: %d" % int(_displayed_credits)
	_hp_bar_target = _hp_bar.value
	_fuel_bar_target = _fuel_bar.value
	_ammo_bar_target = _ammo_bar.value
	_enemy_hq_bar_target = _enemy_hq_bar.value
	_player_hq_bar_target = _player_hq_bar.value
	_refresh_outpost_display()

	# In local multiplayer label the commander panel with the player number
	if GameState.game_mode == Constants.GameMode.LOCAL_MULTIPLAYER:
		var panel_title: Label = $Root/CommanderPanel/M/Box/HeaderRow/HeaderCol/PanelTitle
		panel_title.text = "P1 COMMANDER" if team == Constants.Team.PLAYER else "P2 COMMANDER"
		# HQ labels from each player's perspective
		_player_hq_label.text = "Your HQ: 3000/3000"
		_enemy_hq_label.text = "Opponent HQ: 3000/3000"


func _process(delta: float) -> void:
	if _hq_attack_notification_timer > 0.0:
		_hq_attack_notification_timer -= delta

	if not is_equal_approx(_displayed_credits, _target_credits):
		_displayed_credits = lerp(_displayed_credits, _target_credits, clamp(delta * CREDITS_LERP_SPEED, 0.0, 1.0))
		if absf(_displayed_credits - _target_credits) < 0.5:
			_displayed_credits = _target_credits
		_credits_label.text = "Credits: %d" % int(round(_displayed_credits))

	_approach_bar(_hp_bar, _hp_bar_target, delta)
	_approach_bar(_fuel_bar, _fuel_bar_target, delta)
	_approach_bar(_ammo_bar, _ammo_bar_target, delta)
	_approach_bar(_enemy_hq_bar, _enemy_hq_bar_target, delta)
	_approach_bar(_player_hq_bar, _player_hq_bar_target, delta)

	_hud_poll_timer -= delta
	if _hud_poll_timer <= 0.0:
		_hud_poll_timer = HUD_POLL_INTERVAL
		_update_timer()
		_update_commander_panel()
		_update_hq_bars()
		_update_selected_labels()
		_refresh_outpost_display()


## Exponential ease toward the target so bars visibly drain/refill instead
## of snapping; snaps the last sliver to avoid an endless asymptote.
func _approach_bar(bar: ProgressBar, target: float, delta: float) -> void:
	if is_equal_approx(bar.value, target):
		return
	bar.value = lerp(bar.value, target, clamp(delta * BAR_LERP_SPEED, 0.0, 1.0))
	if absf(bar.value - target) < 0.5:
		bar.value = target


func _unhandled_input(event: InputEvent) -> void:
	# No build/command/order-cycle hotkeys while the intro or end cinematic
	# has control of the battlefield.
	if GameState.cinematic_active:
		return

	var is_local_mp: bool = GameState.game_mode == Constants.GameMode.LOCAL_MULTIPLAYER

	# In local multiplayer P1's HUD ignores joypad events; P2's HUD ignores keyboard/mouse.
	if is_local_mp:
		var is_joy_event: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if team == Constants.Team.PLAYER and is_joy_event:
			return
		if team == Constants.Team.ENEMY and not is_joy_event:
			return

	if Input.is_action_just_pressed(Constants.ACTION_OPEN_BUILD_MENU):
		EventBus.build_menu_requested.emit(team)
	elif Input.is_action_just_pressed(Constants.ACTION_OPEN_COMMAND_MENU):
		EventBus.command_menu_requested.emit(team)
	elif Input.is_action_just_pressed(Constants.ACTION_CYCLE_ORDER):
		_cycle_selected_order()


func _cycle_selected_order() -> void:
	var order_count: int = Constants.UnitOrder.size()
	var new_order: int = (GameState.get_selected_order(team) + 1) % order_count
	GameState.set_selected_order(team, new_order)
	EventBus.hud_message.emit("Order: %s" % Constants.UNIT_ORDER_NAMES.get(new_order, ""), team)


func _on_money_changed(changed_team: int, amount: float) -> void:
	if changed_team != team:
		return
	_target_credits = amount


func _on_commander_mode_changed(changed_team: int, mode: int) -> void:
	if changed_team != team:
		return
	var is_air: bool = mode == Constants.CommanderMode.AIR
	_mode_label.text = "Mode: %s" % ("AIR" if is_air else "GROUND")
	_mode_icon.color = Color(0.55, 0.85, 1.0) if is_air else Color(0.75, 0.6, 0.35)


func _on_commander_fuel_changed(changed_team: int, value: float) -> void:
	if changed_team != team:
		return
	_fuel_bar_target = value
	var is_low: bool = value <= Constants.MAX_PLAYER_FUEL * LOW_FUEL_RATIO
	if is_low and not _was_fuel_low:
		_fuel_warning_tween = UIThemeFactory.continuous_pulse(_fuel_bar, 0.45, 1.0, 2.5)
		_push_notification("Low fuel!", UIThemeFactory.WARNING_COLOR)
	elif not is_low and _was_fuel_low:
		_stop_warning_tween(_fuel_warning_tween, _fuel_bar)
	_was_fuel_low = is_low


func _on_commander_ammo_changed(changed_team: int, value: float) -> void:
	if changed_team != team:
		return
	_ammo_bar_target = value
	var is_low: bool = value <= Constants.MAX_PLAYER_AMMO * LOW_AMMO_RATIO
	if is_low and not _was_ammo_low:
		_ammo_warning_tween = UIThemeFactory.continuous_pulse(_ammo_bar, 0.45, 1.0, 2.5)
		_push_notification("Low ammo!", UIThemeFactory.WARNING_COLOR)
	elif not is_low and _was_ammo_low:
		_stop_warning_tween(_ammo_warning_tween, _ammo_bar)
	_was_ammo_low = is_low


func _stop_warning_tween(tween: Tween, control: CanvasItem) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	control.modulate = Color.WHITE


func _on_building_captured(building: Node, new_team: int) -> void:
	if new_team == team:
		_outposts_captured += 1
		_push_notification("Outpost captured!", UIThemeFactory.SUCCESS_COLOR)
	elif new_team == GameState.get_enemy_team(team):
		_push_notification("Outpost lost!", UIThemeFactory.DANGER_COLOR)
	_refresh_outpost_display()


func _on_building_damaged(building: Node, _amount: float, _attacker: Node) -> void:
	var my_hq: Node = GameState.player_hq if team == Constants.Team.PLAYER else GameState.enemy_hq
	if building != my_hq or _hq_attack_notification_timer > 0.0:
		return
	_hq_attack_notification_timer = HQ_ATTACK_NOTIFICATION_COOLDOWN
	_push_notification("WARNING: HQ under attack!", UIThemeFactory.DANGER_COLOR)


func _on_enemy_wave_launched(attacking_team: int, unit_count: int) -> void:
	if attacking_team != GameState.get_enemy_team(team):
		return
	_push_notification("Enemy wave detected (%d units)" % unit_count, UIThemeFactory.WARNING_COLOR)


func _on_unit_created(unit: Node) -> void:
	if unit.get("team") == team:
		_units_built += 1
		_push_notification("%s ready" % UnitDatabase.get_unit_name(unit.get("unit_type")), UIThemeFactory.CYAN_ACCENT)


func _on_unit_destroyed(unit: Node) -> void:
	var enemy_team: int = GameState.get_enemy_team(team)
	if unit.get("team") == team:
		_units_lost += 1
	elif unit.get("team") == enemy_team:
		_units_destroyed += 1


func _on_commander_died(commander: Node) -> void:
	if commander.get("team") == team:
		_commander_deaths += 1


func _on_hud_message(text: String, msg_team: int) -> void:
	if msg_team != -1 and msg_team != team:
		return
	_push_notification(text, UIThemeFactory.CYAN_ACCENT)


## Adds a fading toast to the notification stack, capped at
## MAX_NOTIFICATIONS (oldest is dropped first). Used for every HUD
## notification -- hud_message relays (build/command menu feedback), plus
## the events this HUD detects directly (captures, fuel/ammo, HQ attacks,
## enemy waves, unit-ready).
func _push_notification(text: String, color: Color) -> void:
	if _notification_list.get_child_count() >= MAX_NOTIFICATIONS:
		_notification_list.get_child(0).queue_free()

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", NOTIFICATION_FONT_SIZE)
	label.modulate.a = 0.0
	_notification_list.add_child(label)

	var tween: Tween = label.create_tween()
	tween.tween_property(label, "modulate:a", 1.0, NOTIFICATION_FADE_DURATION)
	tween.tween_interval(NOTIFICATION_DURATION)
	tween.tween_property(label, "modulate:a", 0.0, NOTIFICATION_FADE_DURATION)
	tween.tween_callback(label.queue_free)


## Hands the result off to MatchResultPanel, which waits out the end
## cinematic's explosion beat before animating its banner/stats in.
func _on_match_ended(winning_team: int) -> void:
	get_tree().paused = false
	_pause_menu.visible = false

	_result_panel.show_result(winning_team == team, {
		"duration": GameState.elapsed_time,
		"built": _units_built,
		"destroyed": _units_destroyed,
		"lost": _units_lost,
		"captured": _outposts_captured,
		"earned": Economy.get_total_earned(team),
		"commander_deaths": _commander_deaths,
	})


func _update_timer() -> void:
	_timer_label.text = _format_time(GameState.elapsed_time)


func _update_commander_panel() -> void:
	var commander: Node = GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander
	if not is_instance_valid(commander):
		_hp_bar_target = 0.0
		_carrying_label.text = "Carrying: None"
		_carrying_icon.visible = false
		return

	_hp_bar_target = commander.get("hp") if commander.get("hp") != null else 0.0

	var carried: Node = commander.get("carried_unit")
	if carried != null and is_instance_valid(carried):
		var unit_type: int = carried.get("unit_type") if carried.get("unit_type") != null else 0
		_carrying_label.text = "Carrying: %s" % UnitDatabase.get_unit_name(unit_type)
		_carrying_icon.icon_type = IconFactory.icon_for_unit_type(unit_type)
		_carrying_icon.team = team
		_carrying_icon.visible = true
	else:
		_carrying_label.text = "Carrying: None"
		_carrying_icon.visible = false


func _update_hq_bars() -> void:
	# "Player HQ" from this HUD's perspective = the HQ belonging to this HUD's team
	var my_hq: Node = GameState.player_hq if team == Constants.Team.PLAYER else GameState.enemy_hq
	var opp_hq: Node = GameState.enemy_hq if team == Constants.Team.PLAYER else GameState.player_hq

	if opp_hq != null and is_instance_valid(opp_hq):
		var hp: float = opp_hq.get("hp") if opp_hq.get("hp") != null else Constants.HQ_MAX_HP
		_enemy_hq_bar_target = hp
		_enemy_hq_label.text = "Opponent HQ: %d/%d" % [int(hp), int(Constants.HQ_MAX_HP)]

	if my_hq != null and is_instance_valid(my_hq):
		var hp: float = my_hq.get("hp") if my_hq.get("hp") != null else Constants.HQ_MAX_HP
		_player_hq_bar_target = hp
		_player_hq_label.text = "Your HQ: %d/%d" % [int(hp), int(Constants.HQ_MAX_HP)]


func _update_selected_labels() -> void:
	var unit_type: int = GameState.get_selected_unit_type(team)
	var order: int = GameState.get_selected_order(team)

	if unit_type != _prev_unit_type:
		_prev_unit_type = unit_type
		_selected_unit_label.text = "Build: %s" % UnitDatabase.get_unit_name(unit_type)

	if order != _prev_order:
		_prev_order = order
		_selected_order_label.text = "Order: %s" % Constants.UNIT_ORDER_NAMES.get(order, "")


func _refresh_outpost_display() -> void:
	var owned: int = 0
	for outpost in GameState.outposts:
		if is_instance_valid(outpost) and outpost.get("team") == team:
			owned += 1
	_outposts_label.text = "Outposts: %d" % owned
	var income: int = Constants.BASE_INCOME_PER_SECOND + owned * Constants.OUTPOST_INCOME_PER_SECOND
	_income_label.text = "Income: +%d/s" % income


func _format_time(seconds: float) -> String:
	var secs: int = int(seconds)
	return "%02d:%02d" % [secs / 60, secs % 60]
