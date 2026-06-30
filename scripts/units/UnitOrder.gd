class_name UnitOrder
extends RefCounted
## Stateless helpers that turn a unit's current_order into a concrete
## movement target. Orders are often assigned without an explicit
## destination (e.g. Base.gd's delivery queue only sets current_order), so
## most cases auto-pick a reasonable target the first time they're resolved
## and cache it on the unit (order_target_position/order_target_building)
## rather than requiring a caller to have set one already.

const PATROL_RADIUS: float = 14.0
const DEFEND_PATROL_RADIUS: float = 10.0


## Returns the world position a unit with the given order should currently
## be moving toward. Combat itself is handled independently by the unit's
## own detection area, regardless of order.
static func resolve_movement_target(unit: Node) -> Vector3:
	match unit.get("current_order"):
		Constants.UnitOrder.PATROL_RADIUS:
			return _resolve_patrol_target(unit)
		Constants.UnitOrder.ADVANCE_TO_TARGET:
			return _resolve_explicit_position(unit)
		Constants.UnitOrder.ATTACK_BASE:
			return _resolve_enemy_hq_target(unit)
		Constants.UnitOrder.CAPTURE_OUTPOST:
			return _resolve_outpost_target(unit, false)
		Constants.UnitOrder.DEFEND_OUTPOST:
			return _resolve_outpost_target(unit, true)
		Constants.UnitOrder.SUPPORT_ALLIES:
			return _resolve_ally_target(unit)
		_:
			# HOLD_POSITION and any unrecognized order: stay put.
			return unit.global_position


static func _resolve_explicit_position(unit: Node) -> Vector3:
	var target: Vector3 = unit.get("order_target_position")
	return target if target != Vector3.ZERO else unit.global_position


static func _resolve_patrol_target(unit: Node) -> Vector3:
	var anchor: Vector3 = unit.get("order_target_position")
	if anchor == Vector3.ZERO:
		anchor = unit.global_position
		unit.set("order_target_position", anchor)

	return NavigationManager.get_random_point_near(anchor, PATROL_RADIUS)


static func _resolve_enemy_hq_target(unit: Node) -> Vector3:
	var building: Node = unit.get("order_target_building")
	if building == null or not is_instance_valid(building):
		var enemy_team: int = GameState.get_enemy_team(unit.get("team"))
		building = GameState.enemy_hq if enemy_team == Constants.Team.ENEMY else GameState.player_hq
		unit.set("order_target_building", building)

	return building.global_position if building != null and is_instance_valid(building) else unit.global_position


## want_own_team true => defend a friendly outpost; false => capture one
## that isn't already friendly. Re-validates ownership every call so a
## cached target gets dropped if the outpost flips teams underneath it.
static func _resolve_outpost_target(unit: Node, want_own_team: bool) -> Vector3:
	var own_team: int = unit.get("team")
	var building: Node = unit.get("order_target_building")
	var still_valid: bool = building != null and is_instance_valid(building) \
		and (building.get("team") == own_team) == want_own_team

	if not still_valid:
		var candidates: Array[Node] = []
		for outpost in GameState.outposts:
			if is_instance_valid(outpost) and (outpost.get("team") == own_team) == want_own_team:
				candidates.append(outpost)
		building = _nearest_of(unit, candidates)
		unit.set("order_target_building", building)

	if building == null:
		return unit.global_position

	# Defenders patrol around their outpost rather than parking on its center.
	if want_own_team:
		return NavigationManager.get_random_point_near(building.global_position, DEFEND_PATROL_RADIUS)
	return building.global_position


## Combat units just follow the nearest friendly group. SupplyTrucks instead
## seek out whichever ally needs resupplying most, falling back to nearest
## when nobody is missing hp/fuel/ammo.
static func _resolve_ally_target(unit: Node) -> Vector3:
	var team_group: String = "player_units" if unit.get("team") == Constants.Team.PLAYER else "enemy_units"
	var allies: Array[Node] = []
	for ally in unit.get_tree().get_nodes_in_group(team_group):
		if ally != unit:
			allies.append(ally)

	var target: Node = null
	if unit.get("unit_type") == Constants.UnitType.SUPPLY_TRUCK:
		target = _neediest_of(allies)
	if target == null:
		target = _nearest_of(unit, allies)

	return target.global_position if target != null else unit.global_position


static func _neediest_of(allies: Array[Node]) -> Node:
	var neediest: Node = null
	var worst_score: float = 0.0
	for ally in allies:
		var score: float = _deficit_score(ally)
		if score > worst_score:
			neediest = ally
			worst_score = score
	return neediest


static func _deficit_score(ally: Node) -> float:
	var score: float = _missing_ratio(ally.get("hp"), ally.get("max_hp"))
	score += _missing_ratio(ally.get("fuel"), ally.get("max_fuel"))
	score += _missing_ratio(ally.get("ammo"), ally.get("max_ammo"))
	return score


static func _missing_ratio(value: float, max_value: float) -> float:
	return 1.0 - (value / max_value) if max_value > 0.0 else 0.0


static func _nearest_of(unit: Node, candidates: Array[Node]) -> Node:
	var nearest: Node = null
	var nearest_distance: float = INF
	for candidate in candidates:
		var distance: float = unit.global_position.distance_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest
