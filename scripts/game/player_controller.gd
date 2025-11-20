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

	# Handle attack
	if InputManager.is_action_just_pressed(player_index, "attack"):
		_try_attack()


func _physics_process(delta: float) -> void:
	if not enabled or not hero:
		return

	# Get movement input
	var movement = InputManager.get_movement_vector(player_index)

	if movement.length() > 0:
		# Player is controlling movement - override AI
		hero.velocity = movement * hero.move_speed
		hero.move_and_slide()

		# Wrap position if needed
		hero.global_position = ToroidalWorld.wrap_position(hero.global_position)

		# Update stance to HOLD_POSITION when player is controlling
		# (prevents AI from taking over)
		hero.stance = hero.Stance.HOLD_POSITION
	else:
		# No input - allow unit's normal behavior
		# Could switch back to ADVANCE stance here if desired
		pass


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


## Try to attack nearest enemy
func _try_attack() -> void:
	# Find nearest enemy and set as target
	var best_target = hero._find_best_target_in_range()
	if best_target:
		hero.current_target = best_target
		hero.current_state = hero.State.ENGAGING_TARGET
		print("Player %d: Attacking target!" % player_index)
	else:
		print("Player %d: No valid targets in range" % player_index)


## Open build menu
func _open_build_menu() -> void:
	# TODO: Implement build menu UI
	print("Player %d: Build menu (not implemented yet)" % player_index)
