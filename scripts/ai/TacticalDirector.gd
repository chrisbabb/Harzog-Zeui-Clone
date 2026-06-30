class_name TacticalDirector
extends RefCounted
## Stateless battlefield-analysis helpers used by EnemyAI.
## All functions take explicit arguments rather than reading global state where
## practical, so the same logic is easy to unit-test or reuse.


## Nearest outpost to position, optionally filtered to a specific team.
## Pass filter_team = -1 to include all outposts regardless of ownership.
static func get_nearest_outpost(position: Vector3, filter_team: int = -1) -> Node:
	var nearest: Node = null
	var nearest_dist: float = INF
	for outpost in GameState.outposts:
		if not is_instance_valid(outpost):
			continue
		if filter_team != -1 and outpost.get("team") != filter_team:
			continue
		var dist: float = position.distance_to(outpost.global_position)
		if dist < nearest_dist:
			nearest = outpost
			nearest_dist = dist
	return nearest


## Team-owned outpost with the lowest hp/max_hp ratio.
static func get_weakest_owned_outpost(team: int) -> Node:
	var weakest: Node = null
	var worst_ratio: float = INF
	for outpost in GameState.outposts:
		if not is_instance_valid(outpost) or outpost.get("team") != team:
			continue
		var max_hp: float = outpost.get("max_hp") if outpost.get("max_hp") != null else 1.0
		var ratio: float = outpost.get("hp") / max_hp
		if ratio < worst_ratio:
			weakest = outpost
			worst_ratio = ratio
	return weakest


## Team-owned outpost farthest from that team's own HQ — the "frontline".
## Returns null when the team owns no outposts.
static func get_frontline_outpost(team: int) -> Node:
	var own_hq: Node = GameState.player_hq if team == Constants.Team.PLAYER else GameState.enemy_hq
	if own_hq == null or not is_instance_valid(own_hq):
		return null
	var frontline: Node = null
	var farthest_dist: float = -1.0
	for outpost in GameState.outposts:
		if not is_instance_valid(outpost) or outpost.get("team") != team:
			continue
		var dist: float = own_hq.global_position.distance_to(outpost.global_position)
		if dist > farthest_dist:
			frontline = outpost
			farthest_dist = dist
	return frontline


## Number of player-team units within radius of position.
## Caller provides the pre-fetched units list to avoid repeated tree queries.
static func get_enemy_pressure_near(position: Vector3, radius: float, all_units: Array) -> int:
	var count: int = 0
	for unit in all_units:
		if not is_instance_valid(unit) or unit.get("is_destroyed"):
			continue
		if unit.get("team") != Constants.Team.PLAYER:
			continue
		if position.distance_to(unit.global_position) <= radius:
			count += 1
	return count


## Choose a unit type to build next given the current situation.
## Urgency overrides take priority; otherwise delegates to per-difficulty logic.
static func choose_next_ai_unit(
		difficulty: int,
		owned_outpost_count: int,
		under_hq_threat: bool,
		all_units: Array) -> int:

	var drone_count: int = 0
	var defender_count: int = 0
	var supply_count: int = 0
	var attacker_count: int = 0
	for unit in all_units:
		if not is_instance_valid(unit) or unit.get("is_destroyed"):
			continue
		if unit.get("team") != Constants.Team.ENEMY:
			continue
		match unit.get("unit_type"):
			Constants.UnitType.CAPTURE_DRONE:
				drone_count += 1
			Constants.UnitType.MISSILE_CRAWLER, Constants.UnitType.ANTI_AIR:
				defender_count += 1
			Constants.UnitType.SUPPLY_TRUCK:
				supply_count += 1
			_:
				attacker_count += 1

	# Urgency overrides — handled before role weights so the AI stays reactive.
	if under_hq_threat and defender_count < 2:
		return Constants.UnitType.MISSILE_CRAWLER if difficulty > 0 else Constants.UnitType.TANK

	if drone_count == 0 and owned_outpost_count < 5:
		return Constants.UnitType.CAPTURE_DRONE

	if supply_count == 0 and attacker_count >= 3:
		return Constants.UnitType.SUPPLY_TRUCK

	match difficulty:
		0:
			return _easy_unit_choice(owned_outpost_count)
		1:
			return _normal_unit_choice(owned_outpost_count)
		_:
			return _hard_unit_choice(owned_outpost_count)


static func _easy_unit_choice(outposts: int) -> int:
	if outposts < 2:
		return Constants.UnitType.CAPTURE_DRONE
	var roll: float = randf()
	if roll < 0.5:
		return Constants.UnitType.SCOUT_BUGGY
	elif roll < 0.8:
		return Constants.UnitType.TANK
	return Constants.UnitType.SUPPLY_TRUCK


static func _normal_unit_choice(outposts: int) -> int:
	if outposts < 3:
		return Constants.UnitType.CAPTURE_DRONE if randf() < 0.4 else Constants.UnitType.TANK
	var roll: float = randf()
	if roll < 0.35:
		return Constants.UnitType.TANK
	elif roll < 0.52:
		return Constants.UnitType.MISSILE_CRAWLER
	elif roll < 0.67:
		return Constants.UnitType.CAPTURE_DRONE
	elif roll < 0.79:
		return Constants.UnitType.SUPPLY_TRUCK
	return Constants.UnitType.ARTILLERY


static func _hard_unit_choice(outposts: int) -> int:
	if outposts < 3:
		var roll: float = randf()
		if roll < 0.30:
			return Constants.UnitType.CAPTURE_DRONE
		elif roll < 0.58:
			return Constants.UnitType.TANK
		return Constants.UnitType.SCOUT_BUGGY
	var roll: float = randf()
	if roll < 0.22:
		return Constants.UnitType.TANK
	elif roll < 0.38:
		return Constants.UnitType.HEAVY_WALKER
	elif roll < 0.52:
		return Constants.UnitType.ARTILLERY
	elif roll < 0.65:
		return Constants.UnitType.ANTI_AIR
	elif roll < 0.78:
		return Constants.UnitType.MISSILE_CRAWLER
	elif roll < 0.88:
		return Constants.UnitType.SUPPLY_TRUCK
	return Constants.UnitType.CAPTURE_DRONE
