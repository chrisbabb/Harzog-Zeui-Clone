extends Control
## Command menu for selecting a unit's order. The selected order becomes the
## default for future purchases/drops, and is immediately (at a cost) applied
## to whichever units the commander is currently allowed to redirect.

const HOTKEY_KEYCODES: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
const INSUFFICIENT_FUNDS_MESSAGE: String = "Insufficient credits."

@onready var options_container: VBoxContainer = $Panel/MarginContainer/ListContainer/OptionsContainer
@onready var close_button: Button = $Panel/MarginContainer/ListContainer/CloseButton

var command_labels: Dictionary = Constants.UNIT_ORDER_NAMES


func _ready() -> void:
	visible = false
	EventBus.command_menu_requested.connect(toggle)
	close_button.pressed.connect(close)
	_populate_options()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if Input.is_action_just_pressed(Constants.ACTION_CANCEL):
		close()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = HOTKEY_KEYCODES.find(event.physical_keycode)
		if index != -1:
			_attempt_select_order(index)


func toggle() -> void:
	if visible:
		close()
	elif _commander_alive():
		open()


func open() -> void:
	visible = true
	EventBus.audio_event_requested.emit("ui_select")
	var buttons := options_container.get_children()
	if not buttons.is_empty():
		buttons[0].grab_focus()


func close() -> void:
	visible = false
	EventBus.audio_event_requested.emit("ui_cancel")


func _populate_options() -> void:
	for order in command_labels.keys():
		var button := Button.new()
		button.text = "[%d] %s" % [order + 1, command_labels[order]]
		button.pressed.connect(_attempt_select_order.bind(order))
		options_container.add_child(button)


## Sets the default order for future purchases/drops, then spends credits to
## immediately apply it to every unit the commander can currently reorder
## (the carried unit, or nearby grounded units -- see Commander.gd).
func _attempt_select_order(order: int) -> void:
	EventBus.audio_event_requested.emit("ui_select")
	GameState.selected_order = order

	var commander: Node = GameState.player_commander
	if is_instance_valid(commander):
		for unit in commander.get_reorderable_units():
			if unit.get("current_order") == order:
				continue
			if not Economy.spend(Constants.Team.PLAYER, Constants.ORDER_CHANGE_COST):
				EventBus.hud_message.emit(INSUFFICIENT_FUNDS_MESSAGE)
				break
			unit.give_order(order)

	close()


func _commander_alive() -> bool:
	return is_instance_valid(GameState.player_commander)
