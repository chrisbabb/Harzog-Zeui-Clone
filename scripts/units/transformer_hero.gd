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

var current_form: Form = Form.PLANE  # Start in plane mode

# Plane mode specifics (cargo system)
var cargo_unit_type: String = ""  # Type of unit being carried ("" means empty)
@export var max_packaged_units: int = 1  # Can only carry 1 unit at a time

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
	"move_speed": 250.0,  # Starting speed
	"max_speed": 280.0,   # Speed after 1 second acceleration
	"attack_range": 100.0,
	"attack_damage": 15.0,
	"attack_cooldown": 0.5
}

# Plane acceleration
var plane_acceleration_time: float = 0.0
const PLANE_ACCELERATION_DURATION: float = 1.0  # 1 second to reach max speed

# Cooldown indicator (shows attack cooldown)
var cooldown_indicator: CooldownIndicator = null

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
	_update_visual()  # Set initial visual based on starting form
	add_to_group("heroes")
	_create_cooldown_indicator()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Handle plane acceleration
	if current_form == Form.PLANE:
		if plane_acceleration_time < PLANE_ACCELERATION_DURATION:
			plane_acceleration_time += delta

			# Lerp from starting speed to max speed over 1 second
			var t = min(plane_acceleration_time / PLANE_ACCELERATION_DURATION, 1.0)
			move_speed = lerp(plane_stats.move_speed, plane_stats.max_speed, t)


## Transform between humanoid and plane mode
func transform() -> void:
	if current_form == Form.HUMANOID:
		_transform_to_plane()
	else:
		# Check if transformation to humanoid is allowed
		if not _can_transform_to_humanoid():
			return
		_transform_to_humanoid()


## Check if transformation to humanoid is allowed
func _can_transform_to_humanoid() -> bool:
	# Can't transform while over a base
	if _is_over_base():
		print("Cannot transform to humanoid - over a base")
		return false

	# Can't transform while carrying cargo
	if cargo_unit_type != "":
		print("Cannot transform to humanoid - carrying cargo (%s)" % cargo_unit_type)
		return false

	return true


## Transform to plane mode (air unit)
func _transform_to_plane() -> void:
	current_form = Form.PLANE
	is_flying = true
	plane_acceleration_time = 0.0  # Reset acceleration timer
	z_index = 10  # Render on top of bases and ground units
	_apply_form_stats()
	_update_visual()
	print("%s transformed to PLANE mode" % unit_name)
	# TODO: Play transformation animation


## Transform to humanoid mode (ground unit)
func _transform_to_humanoid() -> void:
	current_form = Form.HUMANOID
	is_flying = false
	z_index = 0  # Reset to default rendering layer
	_apply_form_stats()

	# Drop cargo when transforming to humanoid
	if cargo_unit_type != "":
		print("Warning: Transforming to humanoid - dropping %s" % cargo_unit_type)
		cargo_unit_type = ""

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
		is_flying = false
	else:  # PLANE
		move_speed = plane_stats.move_speed
		attack_range = plane_stats.attack_range
		attack_damage = plane_stats.attack_damage
		attack_cooldown = plane_stats.attack_cooldown
		is_flying = true


## Pickup packaged units from base OR field units (only in plane mode)
func pickup_packaged_unit() -> bool:
	if current_form != Form.PLANE:
		print("Cannot pickup - must be in PLANE mode")
		return false

	if cargo_unit_type != "":
		print("Cannot pickup - already carrying a unit (%s)" % cargo_unit_type)
		return false

	# First try to pickup from base (completed builds)
	var unit_type = GameManager.pickup_completed_unit(owner_slot)

	if unit_type != "":
		cargo_unit_type = unit_type
		print("Picked up %s from base (ready to deploy)" % unit_type)
		return true

	# If nothing at base, try to pickup from field
	return pickup_field_unit()


## Pickup a unit from the field (nearby friendly unit)
func pickup_field_unit() -> bool:
	if current_form != Form.PLANE:
		return false

	if cargo_unit_type != "":
		return false

	# Find nearby friendly units that can be picked up
	var all_units = get_tree().get_nodes_in_group("units")
	var pickup_range = 150.0

	for unit in all_units:
		# Skip self
		if unit == self:
			continue

		# Must be friendly
		if not "team_color" in unit or unit.team_color != team_color:
			continue

		# Must be a valid unit type we can pick up
		if not "unit_type" in unit:
			continue

		# Check distance
		var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, unit.global_position)
		if dist_sq <= pickup_range * pickup_range:
			# Pick up this unit
			var picked_unit_type = unit.unit_type

			# Remove unit from world
			unit.queue_free()

			# Store in cargo
			cargo_unit_type = picked_unit_type
			print("Picked up %s from field (ready to redeploy)" % picked_unit_type)
			return true

	print("No friendly units nearby to pickup")
	return false


## Deploy a packaged unit (only in plane mode)
func deploy_unit() -> bool:
	if current_form != Form.PLANE:
		print("Cannot deploy - must be in PLANE mode")
		return false

	if cargo_unit_type == "":
		print("Cannot deploy - no units carried")
		return false

	# Check if trying to deploy on a base (not allowed)
	if _is_over_base():
		print("Cannot deploy - cannot place units on bases")
		return false

	# Spawn the unit at current position
	_spawn_unit(cargo_unit_type, global_position)

	# Clear cargo
	cargo_unit_type = ""
	print("Deployed unit at position: %v" % global_position)
	return true


## Check if hero is over a base
func _is_over_base() -> bool:
	# Check main bases
	for base in get_tree().get_nodes_in_group("main_bases"):
		var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, base.global_position)
		if dist_sq <= 100.0 * 100.0:  # Within 100 units of base
			return true

	# Check mini bases
	for mini_base in get_tree().get_nodes_in_group("mini_bases"):
		var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, mini_base.global_position)
		if dist_sq <= 100.0 * 100.0:  # Within 100 units of mini base
			return true

	return false


## Spawn a unit at a position
func _spawn_unit(unit_type: String, position: Vector2) -> void:
	var unit_data = GameManager.UNIT_DATA.get(unit_type)

	if not unit_data:
		push_error("Unknown unit type: %s" % unit_type)
		return

	# Load unit scene
	var unit_scene = load(unit_data.scene)
	if not unit_scene:
		push_error("Failed to load scene for unit type: %s" % unit_type)
		return

	# Instantiate unit
	var unit = unit_scene.instantiate()
	unit.global_position = position
	unit.owner_slot = owner_slot
	unit.team_color = team_color

	# Add to Units group in the scene
	var units_node = get_tree().get_root().find_child("Units", true, false)
	if units_node:
		units_node.add_child(unit)
	else:
		# Fallback: add to current scene
		get_tree().current_scene.get_node("Units").add_child(unit)

	print("Spawned %s at %v for player %d" % [unit_type, position, owner_slot])


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

	# Reset form to plane mode
	if current_form == Form.HUMANOID:
		_transform_to_plane()

	# Clear cargo
	cargo_unit_type = ""

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


## Create cooldown indicator below unit
func _create_cooldown_indicator() -> void:
	cooldown_indicator = CooldownIndicator.new()
	cooldown_indicator.set_tracked_unit(self)
	add_child(cooldown_indicator)
