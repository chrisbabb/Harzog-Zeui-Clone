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

# Bullet scene
const BulletScene = preload("res://scenes/projectiles/bullet.tscn")


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
	# Check raw mouse/trackpad input directly
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_player_attack(_delta)

	var attack_pressed = InputManager.is_action_pressed(player_index, "attack")
	if attack_pressed:
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


## Try to pickup packaged units from base or field units
func _try_pickup() -> void:
	if hero.current_form != TransformerHero.Form.PLANE:
		print("Player %d: Cannot pickup - must be in PLANE mode" % player_index)
		return

	# Hero will try base first, then field units automatically
	hero.pickup_packaged_unit()


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


## Shoot in the direction the player is aiming (spawns bullet projectile)
func _shoot_in_direction() -> void:
	# Create bullet
	var bullet = BulletScene.instantiate()

	# Bullets travel to edge of screen (2000 units should cover most viewport sizes)
	var bullet_range = 2000.0

	# Initialize bullet
	bullet.initialize(
		hero.global_position,
		hero.aim_direction,
		hero.attack_damage,
		bullet_range,
		hero.team_color,
		hero
	)

	# Add bullet to game world (find the game world node)
	var game_world = get_tree().root.get_node_or_null("GameWorld")
	if game_world:
		# Try to add to Projectiles group, or just to game world
		var projectiles_node = game_world.get_node_or_null("Projectiles")
		if projectiles_node:
			projectiles_node.add_child(bullet)
			print("Bullet added to Projectiles node")
		else:
			game_world.add_child(bullet)
			print("Bullet added to GameWorld")
	else:
		print("ERROR: Could not find GameWorld node!")


## Open build menu
func _open_build_menu() -> void:
	# TODO: Implement build menu UI
	print("Player %d: Build menu (not implemented yet)" % player_index)
