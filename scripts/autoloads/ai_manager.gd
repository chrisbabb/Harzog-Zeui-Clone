extends Node
## AIManager - Coordinates AI player behavior
##
## Manages:
## - AI difficulty levels (Easy, Normal, Hard)
## - High-level AI decision making
## - Build orders and composition
## - Strategic targeting
## - Mini-base capture logic

# AI difficulty levels
enum Difficulty {
	EASY,
	NORMAL,
	HARD
}

# AI player instances
var ai_players: Array = []

# AI update intervals (seconds)
const AI_DECISION_INTERVALS = {
	Difficulty.EASY: 5.0,
	Difficulty.NORMAL: 3.0,
	Difficulty.HARD: 1.5
}


func _ready() -> void:
	print("AIManager initialized")


## Register an AI player
func register_ai_player(player_slot: int, difficulty: Difficulty) -> void:
	var ai_player = {
		"slot": player_slot,
		"difficulty": difficulty,
		"time_since_decision": 0.0,
		"decision_interval": AI_DECISION_INTERVALS[difficulty],
		"build_queue": [],
		"target_base": null,
		"unit_composition": _get_default_composition(difficulty)
	}
	ai_players.append(ai_player)
	print("Registered AI player (slot %d, difficulty %d)" % [player_slot, difficulty])


## Update all AI players
func _process(delta: float) -> void:
	for ai_player in ai_players:
		ai_player.time_since_decision += delta

		if ai_player.time_since_decision >= ai_player.decision_interval:
			ai_player.time_since_decision = 0.0
			_make_strategic_decision(ai_player)


## Make a strategic decision for an AI player
func _make_strategic_decision(ai_player: Dictionary) -> void:
	match ai_player.difficulty:
		Difficulty.EASY:
			_easy_ai_decision(ai_player)
		Difficulty.NORMAL:
			_normal_ai_decision(ai_player)
		Difficulty.HARD:
			_hard_ai_decision(ai_player)


## Easy AI decision making
func _easy_ai_decision(ai_player: Dictionary) -> void:
	# Simple logic:
	# - Build peons first (up to 8) for mini base capture
	# - Then build soldiers for defense/attack
	# - Basic resource management

	var player_slot = ai_player.slot
	var resources = GameManager.get_player_resources(player_slot)
	var current_build = GameManager.get_current_build(player_slot)

	# Don't queue if already building
	if not current_build.is_empty():
		return

	# Count current units
	var peon_count = _count_units_of_type(player_slot, "peon")
	var soldier_count = _count_units_of_type(player_slot, "soldier")

	# Strategy: Build peons first (up to 8), then soldiers
	if peon_count < 8 and resources >= 10:
		GameManager.start_building_unit(player_slot, "peon")
		print("AI Player %d: Building peon (%d/8)" % [player_slot, peon_count + 1])
	elif resources >= 10:
		GameManager.start_building_unit(player_slot, "soldier")
		print("AI Player %d: Building soldier (%d total)" % [player_slot, soldier_count + 1])

	# Try to pickup and deploy units
	_ai_manage_unit_deployment(ai_player)


## Normal AI decision making
func _normal_ai_decision(ai_player: Dictionary) -> void:
	# Moderate logic - for now same as Easy, will differentiate later
	# - Build peons first (up to 12) for faster mini base capture
	# - Then build soldiers

	var player_slot = ai_player.slot
	var resources = GameManager.get_player_resources(player_slot)
	var current_build = GameManager.get_current_build(player_slot)

	# Don't queue if already building
	if not current_build.is_empty():
		return

	# Count current units
	var peon_count = _count_units_of_type(player_slot, "peon")
	var soldier_count = _count_units_of_type(player_slot, "soldier")

	# Strategy: Build more peons than Easy AI
	if peon_count < 12 and resources >= 10:
		GameManager.start_building_unit(player_slot, "peon")
		print("AI Player %d: Building peon (%d/12)" % [player_slot, peon_count + 1])
	elif resources >= 10:
		GameManager.start_building_unit(player_slot, "soldier")
		print("AI Player %d: Building soldier (%d total)" % [player_slot, soldier_count + 1])

	# Try to pickup and deploy units
	_ai_manage_unit_deployment(ai_player)


## Hard AI decision making
func _hard_ai_decision(ai_player: Dictionary) -> void:
	# Advanced logic - for now same as Normal, will differentiate later
	# - Build peons first (up to 16) for aggressive mini base control
	# - Then build soldiers

	var player_slot = ai_player.slot
	var resources = GameManager.get_player_resources(player_slot)
	var current_build = GameManager.get_current_build(player_slot)

	# Don't queue if already building
	if not current_build.is_empty():
		return

	# Count current units
	var peon_count = _count_units_of_type(player_slot, "peon")
	var soldier_count = _count_units_of_type(player_slot, "soldier")

	# Strategy: Build even more peons for aggressive map control
	if peon_count < 16 and resources >= 10:
		GameManager.start_building_unit(player_slot, "peon")
		print("AI Player %d: Building peon (%d/16)" % [player_slot, peon_count + 1])
	elif resources >= 10:
		GameManager.start_building_unit(player_slot, "soldier")
		print("AI Player %d: Building soldier (%d total)" % [player_slot, soldier_count + 1])

	# Try to pickup and deploy units
	_ai_manage_unit_deployment(ai_player)


## Get default unit composition for difficulty
func _get_default_composition(difficulty: Difficulty) -> Dictionary:
	match difficulty:
		Difficulty.EASY:
			return {
				"basic_soldier": 0.40,
				"tank": 0.30,
				"missile_soldier": 0.20,
				"turret": 0.10
			}
		Difficulty.NORMAL:
			return {
				"basic_soldier": 0.30,
				"tank": 0.30,
				"missile_soldier": 0.20,
				"missile_tank": 0.10,
				"turret": 0.10
			}
		Difficulty.HARD:
			return {
				"basic_soldier": 0.25,
				"tank": 0.25,
				"missile_soldier": 0.20,
				"missile_tank": 0.15,
				"turret": 0.10,
				"death_turret": 0.05
			}

	return {}


## Convert difficulty string to enum
static func string_to_difficulty(difficulty_string: String) -> Difficulty:
	match difficulty_string:
		"AI_Easy":
			return Difficulty.EASY
		"AI_Normal":
			return Difficulty.NORMAL
		"AI_Hard":
			return Difficulty.HARD
		_:
			return Difficulty.NORMAL


## Count units of a specific type for a player
func _count_units_of_type(player_slot: int, unit_type: String) -> int:
	var count = 0
	var all_units = get_tree().get_nodes_in_group("units")
	for unit in all_units:
		if "owner_slot" in unit and unit.owner_slot == player_slot:
			if "unit_type" in unit and unit.unit_type == unit_type:
				count += 1
	return count


## Find AI player's hero
func _find_ai_hero(player_slot: int) -> Node:
	var heroes = get_tree().get_nodes_in_group("heroes")
	for hero in heroes:
		if "owner_slot" in hero and hero.owner_slot == player_slot:
			return hero
	return null


## Manage AI unit deployment (pickup from base and deploy)
func _ai_manage_unit_deployment(ai_player: Dictionary) -> void:
	var player_slot = ai_player.slot
	var hero = _find_ai_hero(player_slot)

	if not hero:
		return

	# Check if hero is in plane mode
	if hero.current_form != 1:  # 1 = PLANE mode
		# Transform to plane mode if not flying
		hero.transform()
		return

	# Check if hero has cargo
	if hero.cargo_unit_type != "":
		# Deploy the unit if not over a base
		if not hero._is_over_base():
			hero.deploy_unit()
		else:
			# Move away from base to deploy
			_ai_move_hero_away_from_base(hero, player_slot)
	else:
		# Try to pickup a unit from base
		if GameManager.has_completed_units(player_slot):
			# Move toward base and pickup
			var main_base = _find_main_base(player_slot)
			if main_base:
				var dist_sq = ToroidalWorld.toroidal_distance_squared(hero.global_position, main_base.global_position)
				if dist_sq <= 150.0 * 150.0:  # Within pickup range
					hero.pickup_packaged_unit()
				else:
					# Move toward base
					_ai_move_hero_toward(hero, main_base.global_position)
		else:
			# No units to transport - transform to humanoid for combat
			# Check if safe to transform (not over a base)
			if not hero._is_over_base():
				hero.transform()  # Transform to humanoid mode
			else:
				# Move away from base first
				_ai_move_hero_away_from_base(hero, player_slot)


## Move AI hero toward a target position
func _ai_move_hero_toward(hero: Node, target_pos: Vector2) -> void:
	var direction = ToroidalWorld.toroidal_direction(hero.global_position, target_pos)
	hero.velocity = direction * hero.move_speed
	hero.move_and_slide()
	hero.global_position = ToroidalWorld.wrap_position(hero.global_position)


## Move AI hero away from base
func _ai_move_hero_away_from_base(hero: Node, player_slot: int) -> void:
	var main_base = _find_main_base(player_slot)
	if main_base:
		# Move in opposite direction from base
		var direction = ToroidalWorld.toroidal_direction(main_base.global_position, hero.global_position)
		hero.velocity = direction * hero.move_speed
		hero.move_and_slide()
		hero.global_position = ToroidalWorld.wrap_position(hero.global_position)


## Find player's main base
func _find_main_base(player_slot: int) -> Node:
	var bases = get_tree().get_nodes_in_group("main_bases")
	for base in bases:
		if base.has_meta("owner_slot") and base.get_meta("owner_slot") == player_slot:
			return base
	return null
