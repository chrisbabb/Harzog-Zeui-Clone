extends UnitBase
class_name Soldier
## Soldier - Basic ground combat unit
##
## Can attack: Ground units only (not air units)
## Cannot attack: Air units (flying units, heroes in plane mode)
## Purpose: Basic ground combat, weakest combat unit

# Target priorities
const PRIORITY_ENEMY_HERO_GROUND = 100
const PRIORITY_ENEMY_DEATH_TURRET = 95
const PRIORITY_ENEMY_TANK = 90
const PRIORITY_ENEMY_TURRET = 85
const PRIORITY_ENEMY_SOLDIER = 80
const PRIORITY_ENEMY_PEON = 70
const PRIORITY_ENEMY_BASE = 50


func _ready() -> void:
	super._ready()
	unit_name = "Soldier"
	unit_type = "soldier"
	max_health = 80.0
	current_health = max_health
	move_speed = 100.0
	attack_range = 150.0
	attack_damage = 15.0
	attack_cooldown = 1.2
	detection_range = 350.0  # About 1/4 of viewable map
	is_flying = false


## Find best target in range (ground units only)
func _find_best_target_in_range():
	var potential_targets = []

	# Get all enemy units
	var all_units = get_tree().get_nodes_in_group("units")
	for unit in all_units:
		if _is_enemy(unit) and _can_target_unit(unit):
			var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, unit.global_position)
			if dist_sq <= detection_range * detection_range:
				potential_targets.append({
					"entity": unit,
					"priority": _get_unit_priority(unit),
					"distance_sq": dist_sq
				})

	# Can also target enemy bases
	var all_bases = get_tree().get_nodes_in_group("main_bases")
	for base in all_bases:
		if _is_enemy(base):
			var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, base.global_position)
			if dist_sq <= detection_range * detection_range:
				potential_targets.append({
					"entity": base,
					"priority": PRIORITY_ENEMY_BASE,
					"distance_sq": dist_sq
				})

	# Sort by priority (higher first), then by distance (closer first)
	potential_targets.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.distance_sq < b.distance_sq
	)

	if not potential_targets.is_empty():
		return potential_targets[0].entity

	return null


## Check if this unit can target another unit
func _can_target_unit(unit) -> bool:
	# Cannot target flying units
	if "is_flying" in unit and unit.is_flying:
		return false

	# For transformer heroes, check their form
	if "current_form" in unit:
		# If hero is in plane mode, cannot target them
		if unit.current_form == 1:  # 1 = PLANE form
			return false

	return true


## Get unit priority for targeting
func _get_unit_priority(unit) -> int:
	if not "unit_type" in unit:
		return 0

	# Check if transformer hero (prioritize ground form heroes)
	if unit.unit_type == "transformer_hero":
		if "current_form" in unit and unit.current_form == 0:  # HUMANOID form
			return PRIORITY_ENEMY_HERO_GROUND
		return 0  # Don't target plane mode

	match unit.unit_type:
		"death_turret":
			return PRIORITY_ENEMY_DEATH_TURRET
		"tank":
			return PRIORITY_ENEMY_TANK
		"turret":
			return PRIORITY_ENEMY_TURRET
		"soldier":
			return PRIORITY_ENEMY_SOLDIER
		"peon":
			return PRIORITY_ENEMY_PEON
		_:
			return 50  # Default priority


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not "team_color" in entity:
		return false

	return entity.team_color != team_color
