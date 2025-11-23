extends TurretBase
class_name DeathTurret
## DeathTurret - Immobile ultra-powerful turret
##
## Can attack: BOTH air and ground units, AND main bases
## Cannot move: Immobile defensive structure
## Special: Can hit everything, prioritizes high-value targets and clusters

# Target priority scores (higher = more preferred)
const PRIORITY_ATTACKING_MY_BASE = 200  # Highest priority - defend the base!
const PRIORITY_ENEMY_HERO = 100
const PRIORITY_ENEMY_DEATH_TURRET = 95
const PRIORITY_ENEMY_TANK = 90
const PRIORITY_ENEMY_TURRET = 85
const PRIORITY_ENEMY_SOLDIER = 80
const PRIORITY_ENEMY_BASE = 75
const PRIORITY_ENEMY_PEON = 60


func _ready() -> void:
	super._ready()
	unit_name = "Death Turret"
	unit_type = "death_turret"
	max_health = 500.0
	current_health = max_health
	attack_range = 280.0
	attack_damage = 50.0
	attack_cooldown = 2.0
	detection_range = 400.0


## Find best target in range
## Targets BOTH ground and air units, AND bases
func _find_best_target_in_range():
	var potential_targets = []

	# Get ALL enemy units (ground and air)
	var all_units = get_tree().get_nodes_in_group("units")
	for unit in all_units:
		if _is_enemy(unit):
			var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, unit.global_position)
			if dist_sq <= detection_range * detection_range:
				potential_targets.append({
					"entity": unit,
					"priority": _get_unit_priority(unit),
					"distance_sq": dist_sq
				})

	# Get all enemy turrets
	var all_turrets = get_tree().get_nodes_in_group("turrets")
	for turret in all_turrets:
		if _is_enemy(turret) and turret != self:
			var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, turret.global_position)
			if dist_sq <= detection_range * detection_range:
				potential_targets.append({
					"entity": turret,
					"priority": _get_turret_priority(turret),
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


## Get priority score for a unit
func _get_unit_priority(unit) -> int:
	# Highest priority: enemies attacking our main base
	if _is_unit_attacking_my_base(unit):
		return PRIORITY_ATTACKING_MY_BASE

	if "unit_type" in unit:
		match unit.unit_type:
			"transformer_hero":
				return PRIORITY_ENEMY_HERO
			"tank", "missile_tank":
				return PRIORITY_ENEMY_TANK
			"ground_soldier", "missile_soldier":
				return PRIORITY_ENEMY_SOLDIER
			"peon":
				return PRIORITY_ENEMY_PEON

	return PRIORITY_ENEMY_SOLDIER  # Default


## Get priority score for a turret
func _get_turret_priority(turret) -> int:
	# Highest priority: turrets attacking our main base
	if _is_unit_attacking_my_base(turret):
		return PRIORITY_ATTACKING_MY_BASE

	if "unit_type" in turret:
		match turret.unit_type:
			"death_turret":
				return PRIORITY_ENEMY_DEATH_TURRET
			"gun_turret", "missile_turret":
				return PRIORITY_ENEMY_TURRET

	return PRIORITY_ENEMY_TURRET  # Default


## Check if enemy unit is attacking our main base
func _is_unit_attacking_my_base(unit) -> bool:
	# Check if unit has a target
	if not "current_target" in unit or unit.current_target == null:
		return false

	var target = unit.current_target

	# Check if target is a main base
	if not target.is_in_group("main_bases"):
		return false

	# Check if it's OUR main base (same team)
	if "team_color" in target:
		return target.team_color == team_color

	return false


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not "team_color" in entity:
		return false

	return entity.team_color != team_color
