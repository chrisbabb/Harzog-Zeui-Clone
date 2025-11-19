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
	# - Build units based on fixed ratios
	# - Attack nearest enemy base
	# - Poor focus fire
	# - No real adaptation
	pass  # TODO: Implement when game systems are ready


## Normal AI decision making
func _normal_ai_decision(ai_player: Dictionary) -> void:
	# Moderate logic:
	# - Adapt composition based on enemy units
	# - Reasonable focus fire
	# - Capture mini-bases
	# - Send coordinated waves
	pass  # TODO: Implement when game systems are ready


## Hard AI decision making
func _hard_ai_decision(ai_player: Dictionary) -> void:
	# Advanced logic:
	# - Strong counter-building
	# - Excellent focus fire
	# - Strategic mini-base control
	# - Coordinated attacks
	# - Predictive behavior
	pass  # TODO: Implement when game systems are ready


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
