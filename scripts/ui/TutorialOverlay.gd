extends CanvasLayer
## Drives the tutorial's 13-step objective sequence: shows instructional text,
## points Tutorial.gd's highlight marker at whatever's relevant, and advances
## one step at a time by listening for the same EventBus signals/state the
## rest of the game already emits (no tutorial-specific hooks added
## elsewhere). Progression is gated -- the player can freely roam, but the
## current step only completes when its specific condition is met.

enum Step {
	MOVE_COMMANDER,
	TRANSFORM_MODE,
	REFUEL_AT_HQ,
	OPEN_BUILD_MENU,
	BUILD_CAPTURE_DRONE,
	PICK_UP_DRONE,
	DROP_NEAR_OUTPOST,
	ASSIGN_CAPTURE_ORDER,
	CAPTURE_OUTPOST,
	BUILD_TANK,
	SEND_TANK_TO_DUMMY,
	DESTROY_DUMMY,
	FINISH_TUTORIAL,
}

const STEP_TITLES: Array[String] = [
	"Move Your Commander",
	"Transform Modes",
	"Refuel At Your HQ",
	"Open The Build Menu",
	"Build A Capture Drone",
	"Pick Up The Capture Drone",
	"Drop It Near The Outpost",
	"Assign A Capture Order",
	"Capture The Outpost",
	"Build A Tank",
	"Send Your Tank To Attack",
	"Destroy The Target",
	"Tutorial Complete",
]

const STEP_BODIES: Array[String] = [
	"Use W/A/S/D or the left stick to move your commander. Move away from your starting spot to continue.",
	"Press E (or B on controller) to toggle your commander between GROUND and AIR mode. Try it now.",
	"Flying burns fuel fast. Return to your HQ (highlighted) -- standing nearby refuels you automatically.",
	"Press B (or LB on controller) to open the Build Menu, where you spend credits on units.",
	"While near your HQ, select the Capture Drone ([7]) in the Build Menu to purchase one. Use D-pad or mouse to navigate.",
	"Switch to AIR mode (E / B), fly to the new Capture Drone (highlighted), and press Q (or X) to pick it up.",
	"Fly to the neutral outpost (highlighted) and press Q (or X) again to drop the drone right on top of it.",
	"Switch to GROUND mode (E / B), land near the drone (highlighted), press C (or Y), and select Capture Nearest Outpost ([5]).",
	"Wait while the Capture Drone secures the outpost (highlighted) for your team.",
	"Open the Build Menu (B / LB) near a friendly HQ or outpost and purchase a Tank ([2]).",
	"Stand near your new Tank, press C (or Y), and select Attack Enemy HQ ([4]) to send it at the target dummy (highlighted).",
	"Your Tank will engage automatically once in range. Wait for the target dummy (highlighted) to be destroyed.",
	"You've learned movement, transforming, refueling, building, capturing, and combat. You're ready for a real skirmish!",
]

const MOVE_DISTANCE_THRESHOLD: float = 4.0
const OUTPOST_ZONE_RADIUS: float = 6.0

@onready var instruction_panel: Panel = $InstructionPanel
@onready var step_label: Label = $InstructionPanel/M/Box/StepLabel
@onready var title_label: Label = $InstructionPanel/M/Box/TitleLabel
@onready var body_label: Label = $InstructionPanel/M/Box/BodyLabel

@onready var finish_panel: Control = $FinishPanel
@onready var finish_title_label: Label = $FinishPanel/Panel/M/Box/TitleLabel
@onready var finish_body_label: Label = $FinishPanel/Panel/M/Box/BodyLabel
@onready var finish_main_menu_button: Button = $FinishPanel/Panel/M/Box/MainMenuButton

var current_step: int = Step.MOVE_COMMANDER

var _initialized: bool = false
var _commander: Node = null
var _player_hq: Node = null
var _outpost: Node = null
var _target_dummy: Node = null
var _capture_drone: Node = null
var _tank: Node = null
var _move_start_position: Vector3 = Vector3.ZERO


func _ready() -> void:
	finish_main_menu_button.pressed.connect(_on_main_menu_pressed)
	EventBus.commander_mode_changed.connect(_on_commander_mode_changed)
	EventBus.build_menu_requested.connect(_on_build_menu_requested)
	EventBus.unit_created.connect(_on_unit_created)
	EventBus.unit_picked_up.connect(_on_unit_picked_up)
	EventBus.unit_dropped.connect(_on_unit_dropped)
	EventBus.unit_order_changed.connect(_on_unit_order_changed)
	EventBus.building_captured.connect(_on_building_captured)


func _process(_delta: float) -> void:
	if not _initialized:
		_initialized = true
		_commander = GameState.player_commander
		_player_hq = GameState.player_hq
		_outpost = GameState.outposts[0] if not GameState.outposts.is_empty() else null
		_target_dummy = get_tree().current_scene.get("target_dummy")
		_enter_step(Step.MOVE_COMMANDER)
		return

	if not is_instance_valid(_commander):
		return

	match current_step:
		Step.MOVE_COMMANDER:
			if _commander.global_position.distance_to(_move_start_position) >= MOVE_DISTANCE_THRESHOLD:
				_advance_step()
		Step.REFUEL_AT_HQ:
			if float(_commander.get("fuel")) >= Constants.MAX_PLAYER_FUEL:
				_advance_step()
		Step.DESTROY_DUMMY:
			if is_instance_valid(_target_dummy) and _target_dummy.get("is_destroyed") == true:
				_advance_step()


# ---------------------------------------------------------------------------
# Step transitions
# ---------------------------------------------------------------------------

func _advance_step() -> void:
	if current_step >= STEP_TITLES.size() - 1:
		return
	_enter_step(current_step + 1)


func _enter_step(step: int) -> void:
	current_step = step
	step_label.text = "Step %d of %d" % [current_step + 1, STEP_TITLES.size()]
	title_label.text = STEP_TITLES[current_step]
	body_label.text = STEP_BODIES[current_step]

	match step:
		Step.MOVE_COMMANDER:
			_move_start_position = _commander.global_position
			_clear_highlight()
		Step.TRANSFORM_MODE, Step.OPEN_BUILD_MENU, Step.BUILD_CAPTURE_DRONE, Step.BUILD_TANK:
			_clear_highlight()
		Step.REFUEL_AT_HQ:
			_commander.set("fuel", Constants.MAX_PLAYER_FUEL * 0.4)
			EventBus.commander_fuel_changed.emit(Constants.Team.PLAYER, _commander.get("fuel"))
			if is_instance_valid(_player_hq):
				_set_highlight(_player_hq.global_position)
		Step.PICK_UP_DRONE, Step.ASSIGN_CAPTURE_ORDER:
			if is_instance_valid(_capture_drone):
				_set_highlight(_capture_drone.global_position)
		Step.DROP_NEAR_OUTPOST, Step.CAPTURE_OUTPOST:
			if is_instance_valid(_outpost):
				_set_highlight(_outpost.global_position)
		Step.SEND_TANK_TO_DUMMY:
			GameState.enemy_hq = _target_dummy
			if is_instance_valid(_target_dummy):
				_set_highlight(_target_dummy.global_position)
		Step.DESTROY_DUMMY:
			if is_instance_valid(_target_dummy):
				_set_highlight(_target_dummy.global_position)
		Step.FINISH_TUTORIAL:
			_clear_highlight()
			_show_finish_panel()


func _show_finish_panel() -> void:
	instruction_panel.visible = false
	finish_title_label.text = STEP_TITLES[Step.FINISH_TUTORIAL]
	finish_body_label.text = STEP_BODIES[Step.FINISH_TUTORIAL]
	finish_panel.visible = true


# ---------------------------------------------------------------------------
# Highlight marker -- delegates to Tutorial.gd's reusable marker (see its
# set_highlight_target()/clear_highlight()) via the duck-typed
# get_tree().current_scene.call(...) convention used elsewhere in the
# codebase for scene-specific behavior that doesn't belong on an autoload.
# ---------------------------------------------------------------------------

func _set_highlight(world_position: Vector3) -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("set_highlight_target"):
		scene.call("set_highlight_target", world_position)


func _clear_highlight() -> void:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("clear_highlight"):
		scene.call("clear_highlight")


# ---------------------------------------------------------------------------
# EventBus-driven step completion
# ---------------------------------------------------------------------------

func _on_commander_mode_changed(_team: int, _mode: int) -> void:
	if current_step == Step.TRANSFORM_MODE:
		_advance_step()


func _on_build_menu_requested(_team: int) -> void:
	if current_step == Step.OPEN_BUILD_MENU:
		_advance_step()


func _on_unit_created(unit: Node) -> void:
	if current_step == Step.BUILD_CAPTURE_DRONE and unit.get("unit_type") == Constants.UnitType.CAPTURE_DRONE:
		_capture_drone = unit
		_advance_step()
	elif current_step == Step.BUILD_TANK and unit.get("unit_type") == Constants.UnitType.TANK:
		_tank = unit
		_advance_step()


func _on_unit_picked_up(unit: Node) -> void:
	if current_step == Step.PICK_UP_DRONE and unit == _capture_drone:
		_advance_step()


func _on_unit_dropped(unit: Node) -> void:
	if current_step != Step.DROP_NEAR_OUTPOST or unit != _capture_drone or not is_instance_valid(_outpost):
		return
	if unit.global_position.distance_to(_outpost.global_position) <= OUTPOST_ZONE_RADIUS:
		_advance_step()


func _on_unit_order_changed(unit: Node, order: int) -> void:
	if current_step == Step.ASSIGN_CAPTURE_ORDER and unit == _capture_drone and order == Constants.UnitOrder.CAPTURE_OUTPOST:
		_advance_step()
	elif current_step == Step.SEND_TANK_TO_DUMMY and unit == _tank and order == Constants.UnitOrder.ATTACK_BASE:
		_advance_step()


func _on_building_captured(building: Node, new_team: int) -> void:
	if current_step == Step.CAPTURE_OUTPOST and building == _outpost and new_team == Constants.Team.PLAYER:
		_advance_step()


# ---------------------------------------------------------------------------
# Finish
# ---------------------------------------------------------------------------

func _on_main_menu_pressed() -> void:
	GameState.reset_match_state()
	Economy.reset()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
