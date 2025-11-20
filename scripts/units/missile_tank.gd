extends UnitBase
class_name MissileTank
## MissileTank - Heavy anti-air ground unit
##
## Can attack: ONLY flying units (air targets)
## Cannot attack: Ground units or bases
## Tougher and more dangerous than missile soldier

# Target priority scores (higher = more preferred)
const PRIORITY_ENEMY_HERO_PLANE = 100
const PRIORITY_ENEMY_AIR_UNIT_HEAVY = 95
const PRIORITY_ENEMY_AIR_UNIT = 90


func _ready() -> void:
	super._ready()
	unit_name = "Missile Tank"
	unit_type = "missile_tank"
	max_health = 200.0
	current_health = max_health
	move_speed = 70.0
	attack_range = 250.0
	attack_damage = 45.0
	attack_cooldown = 2.5
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


## Check if this unit can target another unit
## Missile tanks can ONLY attack flying units
func _can_target_unit(unit) -> bool:
	# Can ONLY attack flying/air units
	if "is_flying" in unit and unit.is_flying:
		return true

	return false


## Get priority score for a unit
func _get_unit_priority(unit) -> int:
	if "unit_type" in unit:
		match unit.unit_type:
			"transformer_hero":
				# Only if in plane mode (flying)
				return PRIORITY_ENEMY_HERO_PLANE
			"missile_tank", "tank":
				# Other heavy units if flying
				return PRIORITY_ENEMY_AIR_UNIT_HEAVY
			_:
				return PRIORITY_ENEMY_AIR_UNIT

	return PRIORITY_ENEMY_AIR_UNIT  # Default


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not "team_color" in entity:
		return false

	return entity.team_color != team_color


## Choose strategic target position
## Air-only units patrol near likely air unit locations
func _choose_strategic_target() -> Vector2:
	# Move toward nearest enemy main base (where air units often appear)
	var enemy_bases = []
	for base in get_tree().get_nodes_in_group("main_bases"):
		if _is_enemy(base):
			enemy_bases.append(base)

	if not enemy_bases.is_empty():
		var nearest_base = ToroidalWorld.find_nearest(global_position, enemy_bases)
		if nearest_base:
			# Position near but not directly at the base
			var direction = ToroidalWorld.toroidal_direction(global_position, nearest_base.global_position)
			return nearest_base.global_position - direction * 250.0

	return global_position
