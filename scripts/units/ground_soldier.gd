extends UnitBase
class_name GroundSoldier
## GroundSoldier - Basic ground attacking unit
##
## Can attack: Ground units and bases
## Cannot attack: Air units

# Target priority scores (higher = more preferred)
const PRIORITY_ENEMY_HERO_GROUND = 100
const PRIORITY_ENEMY_TANK = 90
const PRIORITY_ENEMY_DEATH_TURRET = 85
const PRIORITY_ENEMY_SOLDIER = 80
const PRIORITY_ENEMY_TURRET = 75
const PRIORITY_ENEMY_PEON = 70
const PRIORITY_ENEMY_BASE = 50


func _ready() -> void:
	super._ready()
	unit_name = "Ground Soldier"
	max_health = 100.0
	current_health = max_health
	move_speed = 120.0
	attack_range = 100.0
	attack_damage = 15.0
	attack_cooldown = 1.0
	detection_range = 300.0


## Find best target in range
## Targets ground units and bases only
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

	# Get all enemy bases
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

	# No targets found
	if potential_targets.is_empty():
		return null

	# Sort by priority (descending), then by distance (ascending)
	potential_targets.sort_custom(func(a, b):
		if a.priority != b.priority:
			return a.priority > b.priority
		return a.distance_sq < b.distance_sq
	)

	return potential_targets[0].entity


## Check if this unit can target another unit
func _can_target_unit(unit) -> bool:
	# Ground soldiers cannot attack air units
	if unit.has("is_flying") and unit.is_flying:
		return false

	return true


## Get priority score for a unit
func _get_unit_priority(unit) -> int:
	if unit.has("unit_type"):
		match unit.unit_type:
			"transformer_hero":
				return PRIORITY_ENEMY_HERO_GROUND
			"tank", "missile_tank":
				return PRIORITY_ENEMY_TANK
			"death_turret":
				return PRIORITY_ENEMY_DEATH_TURRET
			"ground_soldier", "missile_soldier":
				return PRIORITY_ENEMY_SOLDIER
			"gun_turret", "missile_turret":
				return PRIORITY_ENEMY_TURRET
			"peon":
				return PRIORITY_ENEMY_PEON

	return PRIORITY_ENEMY_SOLDIER  # Default


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not entity.has("team_color"):
		return false

	return entity.team_color != team_color


## Choose strategic target position
func _choose_strategic_target() -> Vector2:
	# Move toward nearest enemy main base
	var enemy_bases = []
	for base in get_tree().get_nodes_in_group("main_bases"):
		if _is_enemy(base):
			enemy_bases.append(base)

	if not enemy_bases.is_empty():
		var nearest_base = ToroidalWorld.find_nearest(global_position, enemy_bases)
		if nearest_base:
			return nearest_base.global_position

	return global_position
