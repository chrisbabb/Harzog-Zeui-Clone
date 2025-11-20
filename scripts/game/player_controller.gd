extends Node
class_name PlayerController
## PlayerController - Handles player input and controls their hero
##
## Attached to a player's transformer hero to handle:
## - Movement (WASD / D-Pad / Left Stick)
## - Transformation (Space / B button)
## - Attack (Mouse / A button)
## - Pickup (E / X button)
## - Deploy (R / Y button)
## - Build menu (B / L button)

@export var player_index: int = 1  # Which player this controller is for (1-4)
@export var enabled: bool = true

var hero: TransformerHero = null


func _ready() -> void:
	# Get reference to the hero this controller is attached to
	hero = get_parent() as TransformerHero
	if not hero:
		push_error("PlayerController must be a child of TransformerHero!")
		enabled = false
		return

	# Disable AI control for this unit
	hero.player_controlled = true
	print("Player %d controller enabled for %s" % [player_index, hero.unit_name])


func _process(_delta: float) -> void:
	if not enabled or not hero:
		return

	# Update hero rotation to face mouse cursor
	_update_rotation_to_mouse()

	# Handle transformation toggle
	if InputManager.is_action_just_pressed(player_index, "transform"):
		hero.transform()

	# Handle pickup (only in plane mode)
	if InputManager.is_action_just_pressed(player_index, "pickup"):
		_try_pickup()

	# Handle deploy (only in plane mode)
	if InputManager.is_action_just_pressed(player_index, "deploy"):
		hero.deploy_unit()

	# Handle build menu
	if InputManager.is_action_just_pressed(player_index, "build_menu"):
		_open_build_menu()

	# Handle continuous attack - hold button to keep attacking
	if InputManager.is_action_pressed(player_index, "attack"):
		_handle_player_attack(_delta)
	else:
		# Clear target when not attacking
		if hero.current_state == hero.State.ENGAGING_TARGET:
			hero.current_target = null
			hero.current_state = hero.State.IDLE


func _physics_process(_delta: float) -> void:
	if not enabled or not hero:
		return

	# Get movement input
	var movement = InputManager.get_movement_vector(player_index)

	if movement.length() > 0:
		# Player is controlling movement
		# velocity is in units per second, move_and_slide() handles delta internally
		hero.velocity = movement * hero.move_speed
	else:
		# No input - stop movement
		hero.velocity = Vector2.ZERO

	# Always call move_and_slide to apply velocity
	hero.move_and_slide()

	# Wrap position if needed (toroidal world)
	hero.global_position = ToroidalWorld.wrap_position(hero.global_position)


## Try to pickup packaged units from base
func _try_pickup() -> void:
	if hero.current_form != TransformerHero.Form.PLANE:
		print("Player %d: Cannot pickup - must be in PLANE mode" % player_index)
		return

	# Check if hero is near a friendly base
	var bases = get_tree().get_nodes_in_group("main_bases")
	for base in bases:
		if base.has_meta("team_color") and base.get_meta("team_color") == hero.team_color:
			var dist_sq = ToroidalWorld.toroidal_distance_squared(hero.global_position, base.global_position)
			if dist_sq <= 150.0 * 150.0:  # Within 150 units
				# TODO: Get packaged unit from base
				print("Player %d: Picking up unit from base" % player_index)
				hero.pickup_packaged_unit(null)  # Placeholder
				return

	print("Player %d: No friendly base nearby to pickup from" % player_index)


## Update hero rotation to face mouse cursor
func _update_rotation_to_mouse() -> void:
	# Get mouse position in world coordinates
	var mouse_pos = hero.get_global_mouse_position()

	# Calculate direction to mouse using toroidal distance
	var direction = ToroidalWorld.toroidal_direction(hero.global_position, mouse_pos)

	# Calculate angle and rotate hero
	var angle = direction.angle()
	hero.rotation = angle

	# Store the aim direction for shooting
	hero.aim_direction = direction.normalized()


## Handle player attack (called continuously while attack button held)
func _handle_player_attack(delta: float) -> void:
	# Check attack cooldown
	hero.time_since_attack += delta
	if hero.time_since_attack < hero.attack_cooldown:
		return  # Still on cooldown

	# Shoot in the direction of the mouse
	hero.time_since_attack = 0.0
	_shoot_in_direction()


## Shoot in the direction the player is aiming (mouse direction)
func _shoot_in_direction() -> void:
	# Find all potential targets
	var all_units = get_tree().get_nodes_in_group("units")
	var all_buildings = get_tree().get_nodes_in_group("buildings")
	var all_entities = all_units + all_buildings

	var best_target = null
	var best_score = -1.0

	# Check each entity to see if it's in our aim cone
	for entity in all_entities:
		if entity == hero:
			continue

		if not hero._is_enemy(entity):
			continue

		if entity.has_method("is_dead") and entity.is_dead():
			continue

		# Check if entity can be targeted based on form
		if "is_flying" in entity:
			if hero.current_form == hero.Form.HUMANOID and entity.is_flying:
				continue  # Humanoid can't target air units

		# Get direction to entity
		var entity_pos = entity.global_position if "global_position" in entity else entity.position
		var dist_sq = ToroidalWorld.toroidal_distance_squared(hero.global_position, entity_pos)

		# Check if in range
		if dist_sq > hero.attack_range * hero.attack_range:
			continue

		# Calculate direction to entity
		var dir_to_entity = ToroidalWorld.toroidal_direction(hero.global_position, entity_pos).normalized()

		# Calculate dot product (how aligned with aim direction)
		var alignment = hero.aim_direction.dot(dir_to_entity)

		# Only consider entities in front of us (alignment > 0.5 means within ~60 degree cone)
		if alignment > 0.5:
			# Score based on alignment and distance (prefer closer, more aligned targets)
			var score = alignment * 2.0 - (sqrt(dist_sq) / hero.attack_range)
			if score > best_score:
				best_score = score
				best_target = entity

	# Attack the best target if found
	if best_target:
		if best_target.has_method("take_damage"):
			best_target.take_damage(hero.attack_damage)
			print("Player %d hit target for %.0f damage!" % [player_index, hero.attack_damage])


## Open build menu
func _open_build_menu() -> void:
	# TODO: Implement build menu UI
	print("Player %d: Build menu (not implemented yet)" % player_index)
