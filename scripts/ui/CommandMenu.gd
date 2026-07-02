extends Control
## Command menu: a vertical tactical list of the 7 unit orders, each row
## showing an icon/name/description/hotkey/reassignment cost. Selecting a
## row sets the default order for future purchases/drops, then spends
## credits to immediately apply it to whichever units the commander can
## currently redirect (see Commander.get_reorderable_units).

const HOTKEY_KEYCODES: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7]
const INSUFFICIENT_FUNDS_MESSAGE: String = "Insufficient credits."
const STATUS_POLL_INTERVAL: float = 0.25
const ROW_ICON_SIZE: float = 22.0
const ROW_MIN_HEIGHT: float = 52.0
const COST_TAG_INACTIVE_COLOR: Color = Color(0.7, 0.72, 0.78, 0.5)

@onready var panel: Panel = $Panel
@onready var options_container: VBoxContainer = $Panel/MarginContainer/ListContainer/ScrollContainer/OptionsContainer
@onready var status_label: Label = $Panel/MarginContainer/ListContainer/StatusPanel/StatusMargin/StatusLabel
@onready var close_button: Button = $Panel/MarginContainer/ListContainer/CloseButton

# Which player team this menu belongs to; set to ENEMY for P2 in local multiplayer.
@export var team: int = Constants.Team.PLAYER

var command_labels: Dictionary = Constants.UNIT_ORDER_NAMES

var _rows_by_order: Dictionary = {}
var _row_styles_by_order: Dictionary = {}
var _cost_labels_by_order: Dictionary = {}
var _selection_tween: Tween
var _status_poll_timer: float = 0.0


func _ready() -> void:
	visible = false
	UIThemeFactory.apply_team_accent(panel, team)
	EventBus.command_menu_requested.connect(_on_command_menu_requested)
	close_button.pressed.connect(close)
	_populate_options()
	_refresh_selection_highlight()


func _process(delta: float) -> void:
	if not visible:
		return
	_status_poll_timer -= delta
	if _status_poll_timer <= 0.0:
		_status_poll_timer = STATUS_POLL_INTERVAL
		_update_status_display()


func _on_command_menu_requested(requesting_team: int) -> void:
	if requesting_team != team:
		return
	toggle()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Two CommandMenu instances can be open at once in local multiplayer (one
	# per player); without this filter, a keyboard hotkey from P1 would also
	# reorder in P2's currently-open menu, and vice versa with a joypad
	# Cancel press. Mirrors the same filter in HUD.gd/BuildMenu.gd.
	if GameState.game_mode == Constants.GameMode.LOCAL_MULTIPLAYER:
		var is_joy_event: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if team == Constants.Team.PLAYER and is_joy_event:
			return
		if team == Constants.Team.ENEMY and not is_joy_event:
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
	_update_status_display()
	if not _rows_by_order.is_empty():
		_rows_by_order.values()[0].grab_focus()


func close() -> void:
	visible = false
	EventBus.audio_event_requested.emit("ui_cancel")


# ---------------------------------------------------------------------------
# Row construction
# ---------------------------------------------------------------------------

func _populate_options() -> void:
	for order in command_labels.keys():
		var row: Button = _build_row(order)
		options_container.add_child(row)
		_rows_by_order[order] = row


## Builds one order row as a Button root (see BuildMenu._build_card for the
## same MarginContainer-fill-a-Button technique and rationale).
func _build_row(order: int) -> Button:
	var accent: Color = UIThemeFactory.team_accent(team)
	var style: StyleBoxFlat = UIThemeFactory.make_card_style(accent)
	_row_styles_by_order[order] = style

	var row := Button.new()
	row.text = ""
	row.custom_minimum_size = Vector2(0.0, ROW_MIN_HEIGHT)
	row.add_theme_stylebox_override("normal", style)
	row.add_theme_stylebox_override("hover", style)
	row.add_theme_stylebox_override("pressed", style)
	row.pressed.connect(_attempt_select_order.bind(order))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	row.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var icon := TacticalIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(ROW_ICON_SIZE, ROW_ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.icon_type = IconFactory.icon_for_order(order)
	icon.team = team
	hbox.add_child(icon)

	var info_col := VBoxContainer.new()
	info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 0)
	hbox.add_child(info_col)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = "[%d] %s" % [order + 1, command_labels[order]]
	name_label.add_theme_font_size_override("font_size", 14)
	info_col.add_child(name_label)

	var desc_label := Label.new()
	desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_label.text = Constants.UNIT_ORDER_DESCRIPTIONS.get(order, "")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85, 0.75))
	info_col.add_child(desc_label)

	var cost_label := Label.new()
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.text = "%d cr" % Constants.ORDER_CHANGE_COST
	cost_label.custom_minimum_size = Vector2(48.0, 0.0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_label.add_theme_color_override("font_color", COST_TAG_INACTIVE_COLOR)
	hbox.add_child(cost_label)
	_cost_labels_by_order[order] = cost_label

	return row


# ---------------------------------------------------------------------------
# Selection highlight / status display
# ---------------------------------------------------------------------------

func _refresh_selection_highlight() -> void:
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()

	var selected_order: int = GameState.get_selected_order(team)
	var accent: Color = UIThemeFactory.team_accent(team)
	for order in _row_styles_by_order:
		var style: StyleBoxFlat = _row_styles_by_order[order]
		var is_selected: bool = order == selected_order
		style.bg_color = UIThemeFactory.CARD_BG_SELECTED if is_selected else UIThemeFactory.CARD_BG
		style.border_width_left = 3 if is_selected else 1
		style.border_color = Color(accent.r, accent.g, accent.b, 0.95 if is_selected else 0.45)

	if _row_styles_by_order.has(selected_order):
		_selection_tween = UIThemeFactory.animate_selection_pulse(self, _row_styles_by_order[selected_order])


## Refreshes the header strip and every row's cost-tag emphasis to reflect
## who the commander could currently reassign (carried unit / nearby ground
## units / nobody -- see Commander.get_reorderable_units). Polled rather
## than event-driven since carried/mode/position state changes continuously
## while the menu stays open over live gameplay.
func _update_status_display() -> void:
	var commander: Node = GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander
	var reorderable: Array = []
	if is_instance_valid(commander):
		reorderable = commander.get_reorderable_units()

	var available: bool = not reorderable.is_empty()
	if not is_instance_valid(commander):
		status_label.text = "No commander."
	elif commander.get("carried_unit") != null:
		status_label.text = "Carrying 1 unit -- reassign for %d cr." % Constants.ORDER_CHANGE_COST
	elif available:
		status_label.text = "%d unit(s) in range -- reassign for %d cr each." % [reorderable.size(), Constants.ORDER_CHANGE_COST]
	else:
		status_label.text = "No unit to reassign. Selecting still sets your next order."

	var cost_color: Color = UIThemeFactory.SUCCESS_COLOR if available else COST_TAG_INACTIVE_COLOR
	for order in _cost_labels_by_order:
		var cost_label: Label = _cost_labels_by_order[order]
		cost_label.add_theme_color_override("font_color", cost_color)


# ---------------------------------------------------------------------------
# Order selection
# ---------------------------------------------------------------------------

## Sets the default order for future purchases/drops, then spends credits to
## immediately apply it to every unit the commander can currently reorder
## (the carried unit, or nearby grounded units -- see Commander.gd).
func _attempt_select_order(order: int) -> void:
	EventBus.audio_event_requested.emit("ui_select")
	GameState.set_selected_order(team, order)
	_refresh_selection_highlight()

	var commander: Node = GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander
	if is_instance_valid(commander):
		for unit in commander.get_reorderable_units():
			if unit.get("current_order") == order:
				continue
			if not Economy.spend(team, Constants.ORDER_CHANGE_COST):
				EventBus.hud_message.emit(INSUFFICIENT_FUNDS_MESSAGE, team)
				break
			unit.give_order(order)

	close()


func _commander_alive() -> bool:
	var commander: Node = GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander
	return is_instance_valid(commander)
