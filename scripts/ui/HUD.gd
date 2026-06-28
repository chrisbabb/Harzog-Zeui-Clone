extends CanvasLayer
## Placeholder in-match HUD: resource readout and menu open buttons.

@onready var resource_label: Label = $Root/TopBar/ResourceLabel
@onready var build_menu_button: Button = $Root/TopBar/BuildMenuButton
@onready var command_menu_button: Button = $Root/TopBar/CommandMenuButton
@onready var feedback_label: Label = $Root/StatusBar/FeedbackLabel
@onready var queue_label: Label = $Root/StatusBar/QueueLabel


func _ready() -> void:
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.hud_message.connect(_on_hud_message)
	build_menu_button.pressed.connect(_on_build_menu_button_pressed)
	command_menu_button.pressed.connect(_on_command_menu_button_pressed)
	_on_money_changed(Constants.Team.PLAYER, Economy.get_money(Constants.Team.PLAYER))


func _process(_delta: float) -> void:
	_update_queue_label()


func _unhandled_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed(Constants.ACTION_OPEN_BUILD_MENU):
		EventBus.build_menu_requested.emit()
	elif Input.is_action_just_pressed(Constants.ACTION_OPEN_COMMAND_MENU):
		EventBus.command_menu_requested.emit()


func _on_money_changed(team: int, amount: float) -> void:
	if team == Constants.Team.PLAYER:
		resource_label.text = "Money: %d" % int(amount)


func _on_hud_message(text: String) -> void:
	feedback_label.text = text


func _update_queue_label() -> void:
	var commander: Node = GameState.player_commander
	if not is_instance_valid(commander):
		queue_label.visible = false
		return

	var building: Node = GameState.get_nearest_friendly_production_building(Constants.Team.PLAYER, commander.global_position)
	if building == null or commander.global_position.distance_to(building.global_position) > building.production_radius:
		queue_label.visible = false
		return

	queue_label.visible = true
	queue_label.text = "Queue: %d" % building.get_queue_size()


func _on_build_menu_button_pressed() -> void:
	EventBus.build_menu_requested.emit()


func _on_command_menu_button_pressed() -> void:
	EventBus.command_menu_requested.emit()
