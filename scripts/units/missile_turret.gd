extends TurretBase
class_name MissileTurret
## MissileTurret - Immobile anti-air turret
##
## Can attack: ONLY flying units (air targets)
## Cannot attack: Ground units or bases
## Cannot move: Immobile defensive structure

# Target priority scores (higher = more preferred)
const PRIORITY_ENEMY_HERO_PLANE = 100
const PRIORITY_ENEMY_AIR_UNIT = 90


func _ready() -> void:
	super._ready()
	unit_name = "Missile Turret"
	unit_type = "missile_turret"
	max_health = 300.0
	current_health = max_health
	attack_range = 300.0
	attack_damage = 30.0
	attack_cooldown = 1.2
	detection_range = 400.0


## Find best target in range
## Targets ONLY flying/air units
func _find_best_target_in_range():
	var potential_targets = []

	# Get all enemy units that are FLYING
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
## Missile turrets can ONLY attack flying units
func _can_target_unit(unit) -> bool:
	# Can ONLY attack flying/air units
	if unit.has("is_flying") and unit.is_flying:
		return true

	return false


## Get priority score for a unit
func _get_unit_priority(unit) -> int:
	if unit.has("unit_type"):
		match unit.unit_type:
			"transformer_hero":
				# Only if in plane mode (flying)
				return PRIORITY_ENEMY_HERO_PLANE
			_:
				return PRIORITY_ENEMY_AIR_UNIT

	return PRIORITY_ENEMY_AIR_UNIT  # Default


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not entity.has("team_color"):
		return false

	return entity.team_color != team_color
