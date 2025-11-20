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


## Handle player attack (called continuously while attack button held)
func _handle_player_attack(delta: float) -> void:
	# Update retarget timer
	hero.time_since_retarget += delta
	if hero.time_since_retarget >= hero.RETARGET_INTERVAL:
		hero.time_since_retarget = 0.0
		# Find and acquire new target
		var best_target = hero._find_best_target_in_range()
		if best_target:
			hero.current_target = best_target
			hero.current_state = hero.State.ENGAGING_TARGET

	# If we have a target, attack it
	if hero.current_target and hero._is_valid_target(hero.current_target):
		var target_pos = hero._get_target_position(hero.current_target)
		var dist_sq = ToroidalWorld.toroidal_distance_squared(hero.global_position, target_pos)

		# If target is in attack range, attack
		if dist_sq <= hero.attack_range * hero.attack_range:
			hero._attack_target(delta)
	else:
		hero.current_target = null


## Open build menu
func _open_build_menu() -> void:
	# TODO: Implement build menu UI
	print("Player %d: Build menu (not implemented yet)" % player_index)
