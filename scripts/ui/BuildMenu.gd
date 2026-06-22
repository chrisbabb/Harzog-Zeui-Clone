extends Control
## Placeholder build menu listing buildable units/structures.

signal build_item_selected(item_name: String)

@onready var options_container: VBoxContainer = $Panel/MarginContainer/ListContainer/OptionsContainer
@onready var close_button: Button = $Panel/MarginContainer/ListContainer/CloseButton

var build_options: Array[String] = ["Outpost", "Infantry Unit"]


func _ready() -> void:
	visible = false
	EventBus.build_menu_requested.connect(open)
	close_button.pressed.connect(close)
	_populate_options()


func _unhandled_input(_event: InputEvent) -> void:
	if visible and Input.is_action_just_pressed(Constants.ACTION_CANCEL):
		close()


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func _populate_options() -> void:
	for option_name in build_options:
		var button := Button.new()
		button.text = option_name
		button.pressed.connect(_on_option_pressed.bind(option_name))
		options_container.add_child(button)


func _on_option_pressed(item_name: String) -> void:
	build_item_selected.emit(item_name)
	close()
