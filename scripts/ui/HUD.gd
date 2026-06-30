extends CanvasLayer
## Full in-match HUD: resource readout, commander panel, HQ health bars,
## match timer, build/command menus, pause menu, and match-end overlay.

const FEEDBACK_DURATION: float = 4.0

var _units_built: int = 0
var _units_lost: int = 0
var _units_destroyed: int = 0
var _outposts_captured: int = 0

var _feedback_timer: float = 0.0
var _prev_unit_type: int = -1
var _prev_order: int = -1

@onready var _credits_label: Label = $Root/TopLeft/M/Box/CreditsLabel
@onready var _income_label: Label = $Root/TopLeft/M/Box/IncomeLabel
@onready var _outposts_label: Label = $Root/TopLeft/M/Box/OutpostsLabel
@onready var _timer_label: Label = $Root/TopCenter/M/Box/TimerLabel
@onready var _enemy_hq_label: Label = $Root/TopRight/M/Box/EnemyHQLabel
@onready var _enemy_hq_bar: ProgressBar = $Root/TopRight/M/Box/EnemyHQBar
@onready var _player_hq_label: Label = $Root/TopRight/M/Box/PlayerHQLabel
@onready var _player_hq_bar: ProgressBar = $Root/TopRight/M/Box/PlayerHQBar
@onready var _mode_label: Label = $Root/CommanderPanel/M/Box/ModeLabel
@onready var _hp_bar: ProgressBar = $Root/CommanderPanel/M/Box/HPRow/HPBar
@onready var _fuel_bar: ProgressBar = $Root/CommanderPanel/M/Box/FuelRow/FuelBar
@onready var _ammo_bar: ProgressBar = $Root/CommanderPanel/M/Box/AmmoRow/AmmoBar
@onready var _carrying_label: Label = $Root/CommanderPanel/M/Box/CarryingLabel
@onready var _selected_unit_label: Label = $Root/BottomCenter/M/Box/SelectedUnitLabel
@onready var _selected_order_label: Label = $Root/BottomCenter/M/Box/SelectedOrderLabel
@onready var _feedback_label: Label = $Root/BottomCenter/M/Box/FeedbackLabel
@onready var _match_end: Control = $MatchEnd
@onready var _result_label: Label = $MatchEnd/Panel/M/Box/ResultLabel
@onready var _time_label: Label = $MatchEnd/Panel/M/Box/Stats/TimeLabel
@onready var _built_label: Label = $MatchEnd/Panel/M/Box/Stats/BuiltLabel
@onready var _lost_label: Label = $MatchEnd/Panel/M/Box/Stats/LostLabel
@onready var _destroyed_label: Label = $MatchEnd/Panel/M/Box/Stats/DestroyedLabel
@onready var _captured_label: Label = $MatchEnd/Panel/M/Box/Stats/CapturedLabel
@onready var _rematch_button: Button = $MatchEnd/Panel/M/Box/Buttons/RematchButton
@onready var _main_menu_button: Button = $MatchEnd/Panel/M/Box/Buttons/MainMenuButton
@onready var _pause_menu: Control = $PauseMenu


func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.commander_mode_changed.connect(_on_commander_mode_changed)
	EventBus.commander_fuel_changed.connect(_on_commander_fuel_changed)
	EventBus.commander_ammo_changed.connect(_on_commander_ammo_changed)
	EventBus.building_captured.connect(_on_building_captured)
	EventBus.unit_created.connect(_on_unit_created)
	EventBus.unit_destroyed.connect(_on_unit_destroyed)
	EventBus.hud_message.connect(_on_hud_message)
	EventBus.match_ended.connect(_on_match_ended)

	_rematch_button.pressed.connect(_on_rematch_pressed)
	_main_menu_button.pressed.connect(_on_main_menu_pressed)

	_on_money_changed(Constants.Team.PLAYER, Economy.get_money(Constants.Team.PLAYER))
	_refresh_outpost_display()


func _process(delta: float) -> void:
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			_feedback_label.text = ""

	_update_timer()
	_update_commander_panel()
	_update_hq_bars()
	_update_selected_labels()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(Constants.ACTION_OPEN_BUILD_MENU):
		EventBus.build_menu_requested.emit()
	elif Input.is_action_just_pressed(Constants.ACTION_OPEN_COMMAND_MENU):
		EventBus.command_menu_requested.emit()


func _on_money_changed(team: int, amount: float) -> void:
	if team != Constants.Team.PLAYER:
		return
	_credits_label.text = "Credits: %d" % int(amount)


func _on_commander_mode_changed(mode: int) -> void:
	_mode_label.text = "Mode: %s" % ("AIR" if mode == Constants.CommanderMode.AIR else "GROUND")


func _on_commander_fuel_changed(value: float) -> void:
	_fuel_bar.value = value


func _on_commander_ammo_changed(value: float) -> void:
	_ammo_bar.value = value


func _on_building_captured(building: Node, new_team: int) -> void:
	if new_team == Constants.Team.PLAYER:
		_outposts_captured += 1
	_refresh_outpost_display()


func _on_unit_created(unit: Node) -> void:
	if unit.get("team") == Constants.Team.PLAYER:
		_units_built += 1


func _on_unit_destroyed(unit: Node) -> void:
	if unit.get("team") == Constants.Team.PLAYER:
		_units_lost += 1
	elif unit.get("team") == Constants.Team.ENEMY:
		_units_destroyed += 1


func _on_hud_message(text: String) -> void:
	_feedback_label.text = text
	_feedback_timer = FEEDBACK_DURATION


func _on_match_ended(winning_team: int) -> void:
	get_tree().paused = false
	_pause_menu.visible = false

	_result_label.text = "VICTORY" if winning_team == Constants.Team.PLAYER else "DEFEAT"
	_time_label.text = _format_time(GameState.elapsed_time)
	_built_label.text = str(_units_built)
	_lost_label.text = str(_units_lost)
	_destroyed_label.text = str(_units_destroyed)
	_captured_label.text = str(_outposts_captured)
	_match_end.visible = true


func _on_rematch_pressed() -> void:
	_match_end.visible = false
	GameState.reset_match_state()
	Economy.reset()
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	_match_end.visible = false
	GameState.reset_match_state()
	Economy.reset()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _update_timer() -> void:
	_timer_label.text = _format_time(GameState.elapsed_time)


func _update_commander_panel() -> void:
	var commander: Node = GameState.player_commander
	if not is_instance_valid(commander):
		_hp_bar.value = 0.0
		_carrying_label.text = "Carrying: None"
		return

	_hp_bar.value = commander.get("hp") if commander.get("hp") != null else 0.0

	var carried: Node = commander.get("carried_unit")
	if carried != null and is_instance_valid(carried):
		var unit_type: int = carried.get("unit_type") if carried.get("unit_type") != null else 0
		_carrying_label.text = "Carrying: %s" % UnitDatabase.get_unit_name(unit_type)
	else:
		_carrying_label.text = "Carrying: None"


func _update_hq_bars() -> void:
	var enemy_hq: Node = GameState.enemy_hq
	if enemy_hq != null and is_instance_valid(enemy_hq):
		var hp: float = enemy_hq.get("hp") if enemy_hq.get("hp") != null else Constants.HQ_MAX_HP
		_enemy_hq_bar.value = hp
		_enemy_hq_label.text = "Enemy HQ: %d/%d" % [int(hp), int(Constants.HQ_MAX_HP)]

	var player_hq: Node = GameState.player_hq
	if player_hq != null and is_instance_valid(player_hq):
		var hp: float = player_hq.get("hp") if player_hq.get("hp") != null else Constants.HQ_MAX_HP
		_player_hq_bar.value = hp
		_player_hq_label.text = "Your HQ: %d/%d" % [int(hp), int(Constants.HQ_MAX_HP)]


func _update_selected_labels() -> void:
	var unit_type: int = GameState.selected_unit_type
	var order: int = GameState.selected_order

	if unit_type != _prev_unit_type:
		_prev_unit_type = unit_type
		_selected_unit_label.text = "Build: %s" % UnitDatabase.get_unit_name(unit_type)

	if order != _prev_order:
		_prev_order = order
		_selected_order_label.text = "Order: %s" % Constants.UNIT_ORDER_NAMES.get(order, "")


func _refresh_outpost_display() -> void:
	var owned: int = 0
	for outpost in GameState.outposts:
		if is_instance_valid(outpost) and outpost.get("team") == Constants.Team.PLAYER:
			owned += 1
	_outposts_label.text = "Outposts: %d" % owned
	var income: int = Constants.BASE_INCOME_PER_SECOND + owned * Constants.OUTPOST_INCOME_PER_SECOND
	_income_label.text = "Income: +%d/s" % income


func _format_time(seconds: float) -> String:
	var secs: int = int(seconds)
	return "%02d:%02d" % [secs / 60, secs % 60]
