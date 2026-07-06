extends Control
## Left-side build menu: a scrollable card list of all 8 unit types with
## icon/name/cost/role/hotkey/availability, plus a live production-queue
## readout. Purchases the selected type from whichever friendly HQ/outpost
## is both nearest to the commander and within that building's production
## radius.

const HOTKEY_KEYCODES: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
const NOT_IN_RANGE_MESSAGE: String = "Move near a friendly HQ or outpost to order units."
const INSUFFICIENT_FUNDS_MESSAGE: String = "Insufficient credits."
const UNIT_CAP_MESSAGE: String = "Unit cap reached (%d max)." % Constants.MAX_UNITS_PER_TEAM
const QUEUE_POLL_INTERVAL: float = 0.25
const OPEN_ANIMATION_DURATION: float = 0.16
const DIMMED_ALPHA: float = 0.45
const CARD_ICON_SIZE: float = 28.0
const CARD_MIN_HEIGHT: float = 64.0

@onready var panel: Panel = $Panel
@onready var options_container: VBoxContainer = $Panel/MarginContainer/ListContainer/ScrollContainer/OptionsContainer
@onready var queue_label: Label = $Panel/MarginContainer/ListContainer/QueuePanel/QueueMargin/QueueLabel
@onready var close_button: Button = $Panel/MarginContainer/ListContainer/CloseButton

# Which player team this menu belongs to; set to ENEMY for P2 in local multiplayer.
@export var team: int = Constants.Team.PLAYER

var _cards_by_type: Dictionary = {}
var _card_styles_by_type: Dictionary = {}
var _status_labels_by_type: Dictionary = {}
var _selection_tween: Tween
var _open_tween: Tween
var _queue_poll_timer: float = 0.0


func _ready() -> void:
	visible = false
	UIThemeFactory.apply_team_accent(panel, team)
	EventBus.build_menu_requested.connect(_on_build_menu_requested)
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.unit_created.connect(_on_unit_count_changed)
	EventBus.unit_destroyed.connect(_on_unit_count_changed)
	close_button.pressed.connect(close)
	_populate_options()
	_refresh_affordability()
	_refresh_selection_highlight()


func _process(delta: float) -> void:
	if not visible:
		return
	_queue_poll_timer -= delta
	if _queue_poll_timer <= 0.0:
		_queue_poll_timer = QUEUE_POLL_INTERVAL
		_update_queue_display()


func _on_build_menu_requested(requesting_team: int) -> void:
	if requesting_team != team:
		return
	toggle()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Two BuildMenu instances can be open at once in local multiplayer (one
	# per player); without this filter, a keyboard hotkey from P1 would also
	# purchase in P2's currently-open menu, and vice versa with a joypad
	# Cancel press. Mirrors the same filter in HUD.gd/CommandMenu.gd.
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
			_attempt_purchase(index)


func toggle() -> void:
	if visible:
		close()
	elif _commander_alive():
		open()


func open() -> void:
	visible = true
	EventBus.audio_event_requested.emit("ui_select")
	_play_open_animation()
	_update_queue_display()
	if not _cards_by_type.is_empty():
		_cards_by_type.values()[0].grab_focus()


## Quick scale/fade-in punch on the panel; closing stays instant (snappy).
## Pivot at the panel's left-center so it grows out from the screen edge.
func _play_open_animation() -> void:
	if _open_tween != null and _open_tween.is_valid():
		_open_tween.kill()
	panel.pivot_offset = Vector2(0.0, panel.size.y * 0.5)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	_open_tween = create_tween()
	_open_tween.set_parallel(true)
	_open_tween.tween_property(panel, "modulate:a", 1.0, OPEN_ANIMATION_DURATION)
	_open_tween.tween_property(panel, "scale", Vector2.ONE, OPEN_ANIMATION_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	visible = false
	EventBus.audio_event_requested.emit("ui_cancel")


# ---------------------------------------------------------------------------
# Card construction
# ---------------------------------------------------------------------------

func _populate_options() -> void:
	for unit_type in Constants.UnitType.values():
		var card: Button = _build_card(unit_type)
		options_container.add_child(card)
		_cards_by_type[unit_type] = card


## Builds one card as a Button root (so it stays clickable/focusable/
## hotkey-purchasable exactly like the original flat button list) with a
## MarginContainer child manually stretched to PRESET_FULL_RECT to host the
## real layout, since Button does not auto-arrange children the way a
## Container would. All child Controls are MOUSE_FILTER_IGNORE so clicks
## always land on the Button itself.
func _build_card(unit_type: int) -> Button:
	var data: Dictionary = UnitDatabase.get_unit_data(unit_type)
	var accent: Color = UIThemeFactory.team_accent(team)
	var style: StyleBoxFlat = UIThemeFactory.make_card_style(accent)
	_card_styles_by_type[unit_type] = style

	var card := Button.new()
	card.text = ""
	card.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	# Same shared StyleBoxFlat on all three interactive slots so a Tween
	# mutating its border_color pulses consistently no matter which state
	# (normal/hover/pressed) is currently being drawn. "disabled" is
	# deliberately left at the theme default -- combined with modulate.a
	# dimming below, an unaffordable card reads as inert without needing a
	# fourth style variant.
	card.add_theme_stylebox_override("normal", style)
	card.add_theme_stylebox_override("hover", style)
	card.add_theme_stylebox_override("pressed", style)
	card.pressed.connect(_attempt_purchase.bind(unit_type))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var icon := TacticalIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
	icon.icon_type = IconFactory.icon_for_unit_type(unit_type)
	icon.team = team
	top_row.add_child(icon)

	var info_col := VBoxContainer.new()
	info_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 0)
	top_row.add_child(info_col)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = "[%d] %s" % [unit_type + 1, UnitDatabase.get_unit_name(unit_type)]
	name_label.add_theme_font_size_override("font_size", 15)
	info_col.add_child(name_label)

	var role_label := Label.new()
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_label.text = data.get("role", "")
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85, 0.75))
	info_col.add_child(role_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_row)

	var cost_label := Label.new()
	cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_label.text = "%d cr" % int(data.get("cost", 0.0))
	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", accent)
	bottom_row.add_child(cost_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer)

	var status_label := Label.new()
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.text = "Ready"
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", UIThemeFactory.SUCCESS_COLOR)
	bottom_row.add_child(status_label)
	_status_labels_by_type[unit_type] = status_label

	return card


# ---------------------------------------------------------------------------
# Affordability / selection / queue display
# ---------------------------------------------------------------------------

func _refresh_affordability() -> void:
	var at_cap: bool = GameState.get_unit_count(team) >= Constants.MAX_UNITS_PER_TEAM
	for unit_type in _cards_by_type:
		var card: Button = _cards_by_type[unit_type]
		var affordable: bool = Economy.can_afford(team, UnitDatabase.get_cost(unit_type))
		var available: bool = affordable and not at_cap
		card.disabled = not available
		card.modulate.a = 1.0 if available else DIMMED_ALPHA

		var status_label: Label = _status_labels_by_type.get(unit_type)
		if status_label == null:
			continue
		if at_cap:
			status_label.text = "Cap Reached"
			status_label.add_theme_color_override("font_color", UIThemeFactory.DANGER_COLOR)
		elif not affordable:
			status_label.text = "Can't Afford"
			status_label.add_theme_color_override("font_color", UIThemeFactory.WARNING_COLOR)
		else:
			status_label.text = "Ready"
			status_label.add_theme_color_override("font_color", UIThemeFactory.SUCCESS_COLOR)


func _refresh_selection_highlight() -> void:
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()

	var selected_type: int = GameState.get_selected_unit_type(team)
	var accent: Color = UIThemeFactory.team_accent(team)
	for unit_type in _card_styles_by_type:
		var style: StyleBoxFlat = _card_styles_by_type[unit_type]
		var is_selected: bool = unit_type == selected_type
		style.bg_color = UIThemeFactory.CARD_BG_SELECTED if is_selected else UIThemeFactory.CARD_BG
		style.border_width_left = 3 if is_selected else 1
		style.border_color = Color(accent.r, accent.g, accent.b, 0.95 if is_selected else 0.45)

	if _card_styles_by_type.has(selected_type):
		_selection_tween = UIThemeFactory.animate_selection_pulse(self, _card_styles_by_type[selected_type])


func _update_queue_display() -> void:
	if not _commander_alive():
		queue_label.text = "No commander."
		return

	var commander: Node = GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander
	var building: Node = GameState.get_nearest_friendly_production_building(team, commander.global_position)
	var in_range: bool = building != null and commander.global_position.distance_to(building.global_position) <= building.production_radius
	if not in_range:
		queue_label.text = "No production building in range."
		return

	var count: int = building.get_queue_size()
	queue_label.text = "Queue empty." if count == 0 else "Queue: %d unit(s) pending" % count


func _on_money_changed(changed_team: int, _amount: float) -> void:
	if changed_team == team:
		_refresh_affordability()


func _on_unit_count_changed(_unit: Node) -> void:
	_refresh_affordability()


# ---------------------------------------------------------------------------
# Purchase
# ---------------------------------------------------------------------------

func _attempt_purchase(unit_type: int) -> void:
	if not _commander_alive():
		return

	if GameState.get_unit_count(team) >= Constants.MAX_UNITS_PER_TEAM:
		EventBus.hud_message.emit(UNIT_CAP_MESSAGE, team)
		return

	EventBus.audio_event_requested.emit("ui_select")
	GameState.set_selected_unit_type(team, unit_type)
	_refresh_selection_highlight()
	var commander: Node = GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander
	var building: Node = GameState.get_nearest_friendly_production_building(team, commander.global_position)
	var in_range: bool = building != null and commander.global_position.distance_to(building.global_position) <= building.production_radius

	if not in_range or not building.can_produce(unit_type):
		EventBus.hud_message.emit(NOT_IN_RANGE_MESSAGE, team)
		return

	if not Economy.spend(team, UnitDatabase.get_cost(unit_type)):
		EventBus.hud_message.emit(INSUFFICIENT_FUNDS_MESSAGE, team)
		return

	building.enqueue_unit(unit_type, GameState.get_selected_order(team))
	_update_queue_display()
	EventBus.hud_message.emit("%s ordered (%s)" % [
		UnitDatabase.get_unit_name(unit_type),
		Constants.UNIT_ORDER_NAMES.get(GameState.get_selected_order(team), "Hold Position"),
	], team)


func _commander_alive() -> bool:
	var commander: Node = GameState.player_commander if team == Constants.Team.PLAYER else GameState.enemy_commander
	return is_instance_valid(commander)
