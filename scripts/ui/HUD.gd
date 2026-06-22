extends CanvasLayer
## Placeholder in-match HUD: resource readout and menu open buttons.

@onready var resource_label: Label = $Root/TopBar/ResourceLabel
@onready var build_menu_button: Button = $Root/TopBar/BuildMenuButton
@onready var command_menu_button: Button = $Root/TopBar/CommandMenuButton


func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	build_menu_button.pressed.connect(_on_build_menu_button_pressed)
	command_menu_button.pressed.connect(_on_command_menu_button_pressed)
	_on_money_changed(Constants.Team.PLAYER, Economy.get_money(Constants.Team.PLAYER))


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(Constants.ACTION_OPEN_BUILD_MENU):
		EventBus.build_menu_requested.emit()
	elif Input.is_action_just_pressed(Constants.ACTION_OPEN_COMMAND_MENU):
		EventBus.command_menu_requested.emit()


func _on_money_changed(team: int, amount: float) -> void:
	if team == Constants.Team.PLAYER:
		resource_label.text = "Money: %d" % int(amount)


func _on_build_menu_button_pressed() -> void:
	EventBus.build_menu_requested.emit()


func _on_command_menu_button_pressed() -> void:
	EventBus.command_menu_requested.emit()
