extends Node
## Enemy AI controller. Runs on a periodic decision timer, evaluating economy,
## threat, and unit composition to issue build orders and unit assignments that
## simulate a competent opponent at three difficulty levels.
##
## Attach this to the Game scene. The difficulty export controls how
## aggressively the AI plays; debug_logging prints each decision to the Output.

enum Difficulty { EASY, NORMAL, HARD }

@export var difficulty: Difficulty = Difficulty.NORMAL
@export var debug_logging: bool = false

# Per-difficulty tuning tables indexed by Difficulty enum value.
const _DECISION_INTERVALS: Array[float] = [5.0, 3.0, 1.5]
const _BONUS_INCOME_PER_SEC: Array[float] = [0.0, 2.0, 6.0]
const _WAVE_THRESHOLDS: Array[int] = [2, 3, 5]
const _WAVE_INTERVALS: Array[float] = [36.0, 24.0, 15.0]

# Distance from enemy HQ that counts as "under threat" from player units.
const THREAT_RADIUS: float = 30.0

var _decision_timer: float = 0.0
var _wave_timer: float = 0.0


func _ready() -> void:
	difficulty = clamp(GameState.selected_difficulty, Difficulty.EASY, Difficulty.HARD)
	# Stagger the first decision so buildings have registered with GameState.
	_decision_timer = _DECISION_INTERVALS[difficulty]
	_wave_timer = _WAVE_INTERVALS[difficulty]


func _process(delta: float) -> void:
	if not GameState.match_active:
		return

	var bonus: float = _BONUS_INCOME_PER_SEC[difficulty]
	if bonus > 0.0:
		Economy.add_money(Constants.Team.ENEMY, bonus * delta)

	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = _DECISION_INTERVALS[difficulty]
		_make_decisions()

	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = _WAVE_INTERVALS[difficulty]
		_launch_wave()


# ---------------------------------------------------------------------------
# Core decision loop
# ---------------------------------------------------------------------------

func _make_decisions() -> void:
	var all_units: Array = get_tree().get_nodes_in_group("units")
	var owned_outposts: int = _count_owned_outposts()
	var under_hq_threat: bool = _is_hq_under_threat(all_units)

	_log("tick | outposts=%d hq_threat=%s money=%.0f" % [
		owned_outposts, str(under_hq_threat),
		Economy.get_money(Constants.Team.ENEMY)
	])

	_try_build_unit(all_units, owned_outposts, under_hq_threat)
	_assign_unit_orders(all_units, owned_outposts, under_hq_threat)


# ---------------------------------------------------------------------------
# Building units
# ---------------------------------------------------------------------------

func _try_build_unit(all_units: Array, owned_outposts: int, under_hq_threat: bool) -> void:
	var unit_type: int = TacticalDirector.choose_next_ai_unit(
		difficulty, owned_outposts, under_hq_threat, all_units
	)
	var cost: float = UnitDatabase.get_cost(unit_type)
	if not Economy.can_afford(Constants.Team.ENEMY, cost):
		return

	var building: Node = _get_production_building(unit_type)
	if building == null:
		return

	Economy.spend(Constants.Team.ENEMY, cost)
	var order: int = _default_order_for(unit_type, owned_outposts)
	building.enqueue_unit(unit_type, order)
	_log("built %s at %s (order=%s)" % [
		UnitDatabase.get_unit_name(unit_type),
		building.name,
		Constants.UNIT_ORDER_NAMES.get(order, str(order))
	])


func _get_production_building(unit_type: int) -> Node:
	# HARD: spawn from the frontline outpost when possible so units arrive
	# closer to the action — simulated forward logistics.
	if difficulty == Difficulty.HARD:
		var frontline: Node = TacticalDirector.get_frontline_outpost(Constants.Team.ENEMY)
		if frontline != null and frontline.can_produce(unit_type):
			return frontline

	if GameState.enemy_hq != null and is_instance_valid(GameState.enemy_hq):
		return GameState.enemy_hq

	# Fallback: any owned outpost that can produce this type.
	for outpost in GameState.outposts:
		if is_instance_valid(outpost) and outpost.get("team") == Constants.Team.ENEMY:
			if outpost.can_produce(unit_type):
				return outpost
	return null


func _default_order_for(unit_type: int, owned_outposts: int) -> int:
	match unit_type:
		Constants.UnitType.CAPTURE_DRONE:
			return Constants.UnitOrder.CAPTURE_OUTPOST
		Constants.UnitType.SUPPLY_TRUCK:
			return Constants.UnitOrder.SUPPORT_ALLIES
		Constants.UnitType.MISSILE_CRAWLER, Constants.UnitType.ANTI_AIR:
			return Constants.UnitOrder.DEFEND_OUTPOST
		Constants.UnitType.ARTILLERY:
			return Constants.UnitOrder.ATTACK_BASE if owned_outposts >= 3 else Constants.UnitOrder.DEFEND_OUTPOST
		_:
			# SCOUT_BUGGY, TANK, HEAVY_WALKER: capture first, then attack.
			return Constants.UnitOrder.CAPTURE_OUTPOST if owned_outposts < 2 else Constants.UnitOrder.ATTACK_BASE


# ---------------------------------------------------------------------------
# Order assignment
# ---------------------------------------------------------------------------

func _assign_unit_orders(all_units: Array, owned_outposts: int, under_hq_threat: bool) -> void:
	for unit in all_units:
		if not is_instance_valid(unit) or unit.get("is_destroyed"):
			continue
		if unit.get("team") != Constants.Team.ENEMY:
			continue

		var unit_type: int = unit.get("unit_type") if unit.get("unit_type") != null else Constants.UnitType.TANK
		var desired: int = _choose_order_for(unit_type, owned_outposts, under_hq_threat)

		# Only re-issue when the order changes — prevents interrupting nav
		# targets that UnitOrder.gd caches on the unit between ticks.
		if unit.get("current_order") != desired:
			unit.call("give_order", desired)


func _choose_order_for(unit_type: int, owned_outposts: int, under_hq_threat: bool) -> int:
	match unit_type:
		Constants.UnitType.CAPTURE_DRONE:
			return Constants.UnitOrder.CAPTURE_OUTPOST

		Constants.UnitType.SUPPLY_TRUCK:
			return Constants.UnitOrder.SUPPORT_ALLIES

		Constants.UnitType.MISSILE_CRAWLER, Constants.UnitType.ANTI_AIR:
			# These units patrol defensive positions; their detection areas
			# already handle engaging an airborne player commander that wanders
			# within range without needing a special order.
			return Constants.UnitOrder.DEFEND_OUTPOST

		Constants.UnitType.ARTILLERY:
			if owned_outposts >= 3 and not under_hq_threat:
				return Constants.UnitOrder.ATTACK_BASE
			return Constants.UnitOrder.DEFEND_OUTPOST

		Constants.UnitType.HEAVY_WALKER:
			if under_hq_threat:
				return Constants.UnitOrder.DEFEND_OUTPOST
			return Constants.UnitOrder.ATTACK_BASE

		_:  # SCOUT_BUGGY, TANK
			if under_hq_threat:
				return Constants.UnitOrder.DEFEND_OUTPOST
			elif owned_outposts < 3:
				return Constants.UnitOrder.CAPTURE_OUTPOST
			return Constants.UnitOrder.ATTACK_BASE


# ---------------------------------------------------------------------------
# Attack wave
# ---------------------------------------------------------------------------

## When enough combat units have accumulated, send them all at the player HQ
## simultaneously. Support/capture units are excluded so they stay on task.
func _launch_wave() -> void:
	var threshold: int = _WAVE_THRESHOLDS[difficulty]
	var wave_units: Array[Node] = []

	for unit in get_tree().get_nodes_in_group("units"):
		if not is_instance_valid(unit) or unit.get("is_destroyed"):
			continue
		if unit.get("team") != Constants.Team.ENEMY:
			continue
		var unit_type: int = unit.get("unit_type")
		if unit_type == Constants.UnitType.SUPPLY_TRUCK \
				or unit_type == Constants.UnitType.CAPTURE_DRONE:
			continue
		wave_units.append(unit)

	if wave_units.size() < threshold:
		_log("wave not ready: %d/%d" % [wave_units.size(), threshold])
		return

	_log("launching wave with %d units" % wave_units.size())
	for unit in wave_units:
		# Force ATTACK_BASE regardless of standing order; the decision tick
		# will revise if the situation changes before the next wave timer.
		if unit.get("current_order") != Constants.UnitOrder.ATTACK_BASE:
			unit.call("give_order", Constants.UnitOrder.ATTACK_BASE)


# ---------------------------------------------------------------------------
# Situation assessment
# ---------------------------------------------------------------------------

func _is_hq_under_threat(all_units: Array) -> bool:
	if GameState.enemy_hq == null or not is_instance_valid(GameState.enemy_hq):
		return false
	return TacticalDirector.get_enemy_pressure_near(
		GameState.enemy_hq.global_position, THREAT_RADIUS, all_units
	) > 0


func _count_owned_outposts() -> int:
	var count: int = 0
	for outpost in GameState.outposts:
		if is_instance_valid(outpost) and outpost.get("team") == Constants.Team.ENEMY:
			count += 1
	return count


# ---------------------------------------------------------------------------
# Debug
# ---------------------------------------------------------------------------

func _log(message: String) -> void:
	if debug_logging:
		print("[EnemyAI] ", message)
