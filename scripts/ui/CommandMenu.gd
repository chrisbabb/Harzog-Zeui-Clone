extends Control
## Placeholder radial-style command menu for ordering the selected unit.

signal command_selected(action: int)

@onready var options_container: VBoxContainer = $Panel/MarginContainer/ListContainer/OptionsContainer
@onready var close_button: Button = $Panel/MarginContainer/ListContainer/CloseButton

var command_labels: Dictionary = {
	Constants.CommandAction.MOVE: "Move",
	Constants.CommandAction.ATTACK: "Attack",
	Constants.CommandAction.HOLD: "Hold Position",
	Constants.CommandAction.FOLLOW: "Follow",
	Constants.CommandAction.STOP: "Stop",
}


func _ready() -> void:
	visible = false
	EventBus.command_menu_requested.connect(open)
	close_button.pressed.connect(close)
	_populate_options()


func _unhandled_input(_event: InputEvent) -> void:
	if visible and Input.is_action_just_pressed(Constants.ACTION_CANCEL):
		close()


func open() -> void:
	if GameState.selected_unit == null:
		return
	visible = true


func close() -> void:
	visible = false


func _populate_options() -> void:
	for action in command_labels.keys():
		var button := Button.new()
		button.text = command_labels[action]
		button.pressed.connect(_on_option_pressed.bind(action))
		options_container.add_child(button)


func _on_option_pressed(action: int) -> void:
	command_selected.emit(action)
	close()
