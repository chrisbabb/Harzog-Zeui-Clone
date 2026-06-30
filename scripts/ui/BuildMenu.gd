extends Control
## Left-side build menu: lists all 8 unit types with cost/role/hotkey, and
## purchases the selected type from whichever friendly HQ/outpost is both
## nearest to the commander and within that building's production radius.

const HOTKEY_KEYCODES: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
const NOT_IN_RANGE_MESSAGE: String = "Move near a friendly HQ or outpost to order units."
const INSUFFICIENT_FUNDS_MESSAGE: String = "Insufficient credits."
const UNIT_CAP_MESSAGE: String = "Unit cap reached (%d max)." % Constants.MAX_UNITS_PER_TEAM

@onready var options_container: VBoxContainer = $Panel/MarginContainer/ListContainer/OptionsContainer
@onready var close_button: Button = $Panel/MarginContainer/ListContainer/CloseButton

var _buttons_by_type: Dictionary = {}


func _ready() -> void:
	visible = false
	EventBus.build_menu_requested.connect(toggle)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.unit_created.connect(_on_unit_count_changed)
	EventBus.unit_destroyed.connect(_on_unit_count_changed)
	close_button.pressed.connect(close)
	_populate_options()
	_refresh_affordability()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if Input.is_action_just_pressed(Constants.ACTION_CANCEL):
		close()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = HOTKEY_KEYCODES.find(event.physical_keycode)
		if index != -1:
			_attempt_purchase(index)


func toggle() -> void:
	if visible:
		close()
	elif _commander_alive():
		open()


func open() -> void:
	visible = true
	EventBus.audio_event_requested.emit("ui_select")
	if not _buttons_by_type.is_empty():
		_buttons_by_type.values()[0].grab_focus()


func close() -> void:
	visible = false
	EventBus.audio_event_requested.emit("ui_cancel")


func _populate_options() -> void:
	for unit_type in Constants.UnitType.values():
		var button := Button.new()
		button.text = _option_text(unit_type)
		button.pressed.connect(_attempt_purchase.bind(unit_type))
		options_container.add_child(button)
		_buttons_by_type[unit_type] = button


func _option_text(unit_type: int) -> String:
	var data: Dictionary = UnitDatabase.get_unit_data(unit_type)
	return "[%d] %s\n%d cr — %s" % [
		unit_type + 1,
		UnitDatabase.get_unit_name(unit_type),
		int(data.get("cost", 0.0)),
		data.get("role", ""),
	]


func _refresh_affordability() -> void:
	var at_cap: bool = GameState.get_unit_count(Constants.Team.PLAYER) >= Constants.MAX_UNITS_PER_TEAM
	for unit_type in _buttons_by_type:
		var button: Button = _buttons_by_type[unit_type]
		button.disabled = at_cap or not Economy.can_afford(Constants.Team.PLAYER, UnitDatabase.get_cost(unit_type))


func _on_money_changed(team: int, _amount: float) -> void:
	if team == Constants.Team.PLAYER:
		_refresh_affordability()


func _on_unit_count_changed(_unit: Node) -> void:
	_refresh_affordability()


func _attempt_purchase(unit_type: int) -> void:
	if not _commander_alive():
		return

	if GameState.get_unit_count(Constants.Team.PLAYER) >= Constants.MAX_UNITS_PER_TEAM:
		EventBus.hud_message.emit(UNIT_CAP_MESSAGE)
		return

	EventBus.audio_event_requested.emit("ui_select")
	GameState.selected_unit_type = unit_type
	var commander: Node = GameState.player_commander
	var building: Node = GameState.get_nearest_friendly_production_building(Constants.Team.PLAYER, commander.global_position)
	var in_range: bool = building != null and commander.global_position.distance_to(building.global_position) <= building.production_radius

	if not in_range or not building.can_produce(unit_type):
		EventBus.hud_message.emit(NOT_IN_RANGE_MESSAGE)
		return

	if not Economy.spend(Constants.Team.PLAYER, UnitDatabase.get_cost(unit_type)):
		EventBus.hud_message.emit(INSUFFICIENT_FUNDS_MESSAGE)
		return

	building.enqueue_unit(unit_type, GameState.selected_order)
	EventBus.hud_message.emit("%s ordered (%s)" % [
		UnitDatabase.get_unit_name(unit_type),
		Constants.UNIT_ORDER_NAMES.get(GameState.selected_order, "Hold Position"),
	])


func _commander_alive() -> bool:
	return is_instance_valid(GameState.player_commander)
