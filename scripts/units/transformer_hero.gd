extends UnitBase
class_name TransformerHero
## TransformerHero - Player-controlled transformer unit
##
## Can transform between two forms:
## - Humanoid (ground unit): Can attack ground units and bases
## - Plane (air unit): Can fly, pickup packaged units, deploy units
##
## This is the main unit for each player

# Transformer forms
enum Form {
	HUMANOID,  # Ground form
	PLANE      # Air/flying form
}

var current_form: Form = Form.HUMANOID

# Plane mode specifics
var packaged_units_carried: Array = []
@export var max_packaged_units: int = 3

# Respawn system
var main_base = null  # Reference to player's main base for respawning
var respawn_delay: float = 3.0  # Seconds before respawn
var is_respawning: bool = false

# Player aiming (for mouse-controlled shooting)
var aim_direction: Vector2 = Vector2.RIGHT  # Direction player is aiming

# Form-specific stats
var humanoid_stats = {
	"move_speed": 150.0,
	"attack_range": 120.0,
	"attack_damage": 25.0,
	"attack_cooldown": 0.8
}

var plane_stats = {
	"move_speed": 250.0,
	"attack_range": 100.0,
	"attack_damage": 15.0,
	"attack_cooldown": 0.5
}

# Target priorities (same as ground soldier when in humanoid form)
const PRIORITY_ENEMY_HERO = 100
const PRIORITY_ENEMY_DEATH_TURRET = 95
const PRIORITY_ENEMY_TANK = 90
const PRIORITY_ENEMY_TURRET = 85
const PRIORITY_ENEMY_SOLDIER = 80
const PRIORITY_ENEMY_PEON = 70
const PRIORITY_ENEMY_BASE = 50


func _ready() -> void:
	super._ready()
	unit_name = "Transformer Hero"
	unit_type = "transformer_hero"
	max_health = 400.0
	current_health = max_health
	detection_range = 350.0
	_apply_form_stats()
	add_to_group("heroes")


## Transform between humanoid and plane mode
func transform() -> void:
	if current_form == Form.HUMANOID:
		_transform_to_plane()
	else:
		_transform_to_humanoid()


## Transform to plane mode (air unit)
func _transform_to_plane() -> void:
	current_form = Form.PLANE
	is_flying = true
	_apply_form_stats()
	_update_visual()
	print("%s transformed to PLANE mode" % unit_name)
	# TODO: Play transformation animation


## Transform to humanoid mode (ground unit)
func _transform_to_humanoid() -> void:
	current_form = Form.HUMANOID
	is_flying = false
	_apply_form_stats()

	# Drop all packaged units when transforming to humanoid
	if not packaged_units_carried.is_empty():
		print("Warning: Transforming to humanoid - dropping %d packaged units" % packaged_units_carried.size())
		packaged_units_carried.clear()

	_update_visual()
	print("%s transformed to HUMANOID mode" % unit_name)
	# TODO: Play transformation animation


## Update visual appearance based on current form
func _update_visual() -> void:
	# Update form label if it exists
	if has_node("FormLabel"):
		var label = get_node("FormLabel")
		if current_form == Form.PLANE:
			label.text = "PLANE"
		else:
			label.text = "HUMANOID"

	# Update color based on form
	if has_node("Visual"):
		var visual = get_node("Visual")
		if current_form == Form.PLANE:
			visual.color = Color(0.7, 0.9, 1.0, 1.0)  # Light blue for plane
		else:
			visual.color = Color(0.9, 0.7, 0.2, 1.0)  # Gold for humanoid


## Apply stats based on current form
func _apply_form_stats() -> void:
	if current_form == Form.HUMANOID:
		move_speed = humanoid_stats.move_speed
		attack_range = humanoid_stats.attack_range
		attack_damage = humanoid_stats.attack_damage
		attack_cooldown = humanoid_stats.attack_cooldown
	else:  # PLANE
		move_speed = plane_stats.move_speed
		attack_range = plane_stats.attack_range
		attack_damage = plane_stats.attack_damage
		attack_cooldown = plane_stats.attack_cooldown


## Pickup packaged units (only in plane mode, when over base)
func pickup_packaged_unit(packaged_unit) -> bool:
	if current_form != Form.PLANE:
		print("Cannot pickup - must be in PLANE mode")
		return false

	if packaged_units_carried.size() >= max_packaged_units:
		print("Cannot pickup - already carrying max units (%d)" % max_packaged_units)
		return false

	packaged_units_carried.append(packaged_unit)
	print("Picked up packaged unit (carrying %d/%d)" % [packaged_units_carried.size(), max_packaged_units])
	return true


## Deploy a packaged unit (only in plane mode)
func deploy_unit() -> bool:
	if current_form != Form.PLANE:
		print("Cannot deploy - must be in PLANE mode")
		return false

	if packaged_units_carried.is_empty():
		print("Cannot deploy - no units carried")
		return false

	var unit_to_deploy = packaged_units_carried.pop_front()
	# TODO: Spawn the actual unit at current position
	print("Deployed unit at position: %v (carrying %d/%d)" % [global_position, packaged_units_carried.size(), max_packaged_units])
	return true


## Find best target in range (depends on current form)
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

	# In humanoid mode, can also target bases
	if current_form == Form.HUMANOID:
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


## Check if this unit can target another unit (depends on form)
func _can_target_unit(unit) -> bool:
	if current_form == Form.HUMANOID:
		# Humanoid form: cannot attack air units
		if "is_flying" in unit and unit.is_flying:
			return false
		return true
	else:  # PLANE
		# Plane form: can attack both air and ground
		# (Assumption: planes have flexible weapons)
		return true


## Get priority score for a unit
func _get_unit_priority(unit) -> int:
	if "unit_type" in unit:
		match unit.unit_type:
			"transformer_hero":
				return PRIORITY_ENEMY_HERO
			"death_turret":
				return PRIORITY_ENEMY_DEATH_TURRET
			"tank", "missile_tank":
				return PRIORITY_ENEMY_TANK
			"gun_turret", "missile_turret":
				return PRIORITY_ENEMY_TURRET
			"ground_soldier", "missile_soldier":
				return PRIORITY_ENEMY_SOLDIER
			"peon":
				return PRIORITY_ENEMY_PEON

	return PRIORITY_ENEMY_SOLDIER  # Default


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not "team_color" in entity:
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


## Override die to respawn instead of being destroyed
func _die() -> void:
	if is_respawning:
		return  # Already respawning

	current_state = State.DEAD
	is_respawning = true

	print("%s killed! Respawning in %.1f seconds..." % [unit_name, respawn_delay])

	# Hide the hero temporarily
	visible = false

	# Disable collision
	set_physics_process(false)

	# Start respawn timer
	await get_tree().create_timer(respawn_delay).timeout

	_respawn()


## Respawn the hero at their main base
func _respawn() -> void:
	if not is_instance_valid(main_base):
		push_error("Cannot respawn - main base not found!")
		queue_free()
		return

	# Reset health
	current_health = max_health
	_update_health_bar()

	# Reset position to main base
	global_position = main_base.global_position + Vector2(100, 0)

	# Reset form to humanoid
	if current_form == Form.PLANE:
		_transform_to_humanoid()

	# Clear carried units
	packaged_units_carried.clear()

	# Clear target
	current_target = null

	# Reset state
	current_state = State.IDLE
	is_respawning = false

	# Re-enable
	visible = true
	set_physics_process(true)

	print("%s respawned at main base!" % unit_name)


## Set main base reference (called during initialization)
func set_main_base(base) -> void:
	main_base = base
