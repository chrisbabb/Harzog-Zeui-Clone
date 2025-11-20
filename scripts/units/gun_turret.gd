extends TurretBase
class_name GunTurret
## GunTurret - Immobile ground attacking turret
##
## Can attack: Ground units and bases
## Cannot attack: Air units
## Cannot move: Immobile defensive structure

# Target priority scores (higher = more preferred)
const PRIORITY_ENEMY_HERO_GROUND = 100
const PRIORITY_ENEMY_TANK = 90
const PRIORITY_ENEMY_SOLDIER = 85
const PRIORITY_ENEMY_PEON = 75
const PRIORITY_ENEMY_BASE = 50


func _ready() -> void:
	super._ready()
	unit_name = "Gun Turret"
	unit_type = "gun_turret"
	max_health = 350.0
	current_health = max_health
	attack_range = 200.0
	attack_damage = 20.0
	attack_cooldown = 0.8
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

	# Get all enemy bases (lower priority than units)
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


## Check if this turret can target another unit
func _can_target_unit(unit) -> bool:
	# Gun turrets cannot attack air units
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
			"ground_soldier", "missile_soldier":
				return PRIORITY_ENEMY_SOLDIER
			"peon":
				return PRIORITY_ENEMY_PEON

	return PRIORITY_ENEMY_SOLDIER  # Default


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not entity.has("team_color"):
		return false

	return entity.team_color != team_color
