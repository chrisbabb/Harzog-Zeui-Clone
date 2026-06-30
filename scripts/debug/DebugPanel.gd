extends CanvasLayer
## In-game debug panel (F1 to toggle). Disabled automatically in release builds.

const SPAWN_OFFSET := Vector3(6.0, 0.0, 0.0)
const MONEY_DELTA := 500
const HQ_DAMAGE := 500.0
const COMMANDER_MAX_HP := 500.0

@onready var panel: Panel = $Panel
@onready var fps_label: Label = $Panel/M/VBox/Stats/FPSLabel
@onready var player_money_label: Label = $Panel/M/VBox/Stats/PlayerMoneyLabel
@onready var enemy_money_label: Label = $Panel/M/VBox/Stats/EnemyMoneyLabel
@onready var player_units_label: Label = $Panel/M/VBox/Stats/PlayerUnitsLabel
@onready var enemy_units_label: Label = $Panel/M/VBox/Stats/EnemyUnitsLabel
@onready var outposts_label: Label = $Panel/M/VBox/Stats/OutpostsLabel
@onready var ai_label: Label = $Panel/M/VBox/Stats/AILabel
@onready var commander_pos_label: Label = $Panel/M/VBox/Stats/CommanderPosLabel
@onready var toggle_ai_button: Button = $Panel/M/VBox/ToggleAIButton
@onready var toggle_god_button: Button = $Panel/M/VBox/ToggleGodButton

var _ai_enabled: bool = true
var _god_mode: bool = false


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return

	panel.visible = false

	$Panel/M/VBox/AddPlayerMoneyButton.pressed.connect(_on_add_player_money)
	$Panel/M/VBox/AddEnemyMoneyButton.pressed.connect(_on_add_enemy_money)
	$Panel/M/VBox/SpawnPlayerUnitButton.pressed.connect(_on_spawn_player_unit)
	$Panel/M/VBox/SpawnEnemyUnitButton.pressed.connect(_on_spawn_enemy_unit)
	$Panel/M/VBox/CaptureOutpostButton.pressed.connect(_on_capture_nearest_outpost)
	$Panel/M/VBox/DamageEnemyHQButton.pressed.connect(_on_damage_enemy_hq)
	toggle_ai_button.pressed.connect(_on_toggle_ai)
	toggle_god_button.pressed.connect(_on_toggle_god)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F1:
			panel.visible = not panel.visible
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _god_mode and is_instance_valid(GameState.player_commander):
		var c := GameState.player_commander
		c.set("hp", COMMANDER_MAX_HP)
		c.set("fuel", Constants.MAX_PLAYER_FUEL)
		c.set("ammo", Constants.MAX_PLAYER_AMMO)

	if not panel.visible:
		return

	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	player_money_label.text = "Player: $%d" % int(Economy.player_money)
	enemy_money_label.text = "Enemy:  $%d" % int(Economy.enemy_money)

	var all_units: Array = get_tree().get_nodes_in_group("units")
	var player_count := 0
	var enemy_count := 0
	for u in all_units:
		if u.get("team") == Constants.Team.PLAYER:
			player_count += 1
		elif u.get("team") == Constants.Team.ENEMY:
			enemy_count += 1
	player_units_label.text = "Player units: %d" % player_count
	enemy_units_label.text = "Enemy units:  %d" % enemy_count

	var total_outposts := GameState.outposts.size()
	var player_outposts := 0
	for o in GameState.outposts:
		if is_instance_valid(o) and o.get("team") == Constants.Team.PLAYER:
			player_outposts += 1
	outposts_label.text = "Outposts: %d / %d" % [player_outposts, total_outposts]

	ai_label.text = "AI: %s" % _ai_objective_text()

	if is_instance_valid(GameState.player_commander):
		var pos := GameState.player_commander.global_position
		commander_pos_label.text = "Cmd: (%.1f, %.1f, %.1f)" % [pos.x, pos.y, pos.z]
	else:
		commander_pos_label.text = "Cmd: N/A"


func _ai_objective_text() -> String:
	var enemy_ai: Node = get_tree().current_scene.get_node_or_null("EnemyAI")
	if not is_instance_valid(enemy_ai):
		return "N/A"
	if not enemy_ai.is_processing():
		return "DISABLED"
	var owned := 0
	for o in GameState.outposts:
		if is_instance_valid(o) and o.get("team") == Constants.Team.ENEMY:
			owned += 1
	if owned < 2:
		return "Capturing"
	if owned >= 3:
		return "Attacking"
	return "Holding"


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_add_player_money() -> void:
	Economy.add_money(Constants.Team.PLAYER, MONEY_DELTA)


func _on_add_enemy_money() -> void:
	Economy.add_money(Constants.Team.ENEMY, MONEY_DELTA)


func _on_spawn_player_unit() -> void:
	_spawn_unit(Constants.Team.PLAYER)


func _on_spawn_enemy_unit() -> void:
	_spawn_unit(Constants.Team.ENEMY)


func _spawn_unit(team: int) -> void:
	var units_root: Node = get_tree().current_scene.get_node_or_null("WorldRoot/UnitsRoot")
	if units_root == null:
		return
	var spawn_pos := Vector3.ZERO
	if is_instance_valid(GameState.player_commander):
		spawn_pos = GameState.player_commander.global_position + SPAWN_OFFSET
	var unit: Node3D = UnitDatabase.create_unit(Constants.UnitType.TANK, team, spawn_pos)
	units_root.add_child(unit)


func _on_capture_nearest_outpost() -> void:
	if not is_instance_valid(GameState.player_commander):
		return
	var cmd_pos := GameState.player_commander.global_position
	var closest: Node = null
	var closest_dist := INF
	for o in GameState.outposts:
		if not is_instance_valid(o):
			continue
		if o.get("team") == Constants.Team.PLAYER:
			continue
		var d := cmd_pos.distance_to(o.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = o
	if closest != null:
		closest.call("_complete_capture", Constants.Team.PLAYER)


func _on_damage_enemy_hq() -> void:
	if is_instance_valid(GameState.enemy_hq):
		GameState.enemy_hq.take_damage(HQ_DAMAGE)


func _on_toggle_ai() -> void:
	var enemy_ai: Node = get_tree().current_scene.get_node_or_null("EnemyAI")
	if not is_instance_valid(enemy_ai):
		return
	_ai_enabled = not _ai_enabled
	enemy_ai.set_process(_ai_enabled)
	toggle_ai_button.text = "Enable AI" if not _ai_enabled else "Disable AI"


func _on_toggle_god() -> void:
	_god_mode = not _god_mode
	toggle_god_button.text = "Disable God Mode" if _god_mode else "Enable God Mode"
