extends CharacterBody3D
## Placeholder script for the player-controlled commander.
## Can transform between a ground form and an air form, each with its own
## movement feel. Combat and pickup/drop logic are stubbed for now.

@export var max_health: float = 250.0
@export var team: int = Constants.Team.PLAYER

var current_health: float
var mode: int = Constants.CommanderMode.GROUND
var carried_unit: Node = null

var _transform_cooldown_remaining: float = 0.0

@onready var ground_mesh: MeshInstance3D = $GroundMesh
@onready var air_mesh: MeshInstance3D = $AirMesh


func _ready() -> void:
	current_health = max_health
	_update_mode_visuals()


func _physics_process(delta: float) -> void:
	if _transform_cooldown_remaining > 0.0:
		_transform_cooldown_remaining -= delta

	var input_direction := Vector3.ZERO
	input_direction.x = Input.get_action_strength(Constants.ACTION_MOVE_RIGHT) - Input.get_action_strength(Constants.ACTION_MOVE_LEFT)
	input_direction.z = Input.get_action_strength(Constants.ACTION_MOVE_BACK) - Input.get_action_strength(Constants.ACTION_MOVE_FORWARD)
	input_direction = input_direction.normalized()

	var speed: float = Constants.COMMANDER_AIR_SPEED if mode == Constants.CommanderMode.AIR else Constants.COMMANDER_GROUND_SPEED
	velocity = input_direction * speed
	move_and_slide()

	if Input.is_action_just_pressed(Constants.ACTION_TRANSFORM_MODE):
		toggle_transform()

	if Input.is_action_just_pressed(Constants.ACTION_PICKUP_DROP):
		toggle_pickup_drop()

	if Input.is_action_just_pressed(Constants.ACTION_FIRE_PRIMARY):
		fire_primary()


func toggle_transform() -> void:
	if _transform_cooldown_remaining > 0.0:
		return
	mode = Constants.CommanderMode.AIR if mode == Constants.CommanderMode.GROUND else Constants.CommanderMode.GROUND
	_transform_cooldown_remaining = Constants.COMMANDER_TRANSFORM_COOLDOWN
	_update_mode_visuals()
	EventBus.commander_transformed.emit(self, mode)


func toggle_pickup_drop() -> void:
	# Placeholder hook for picking up/dropping a friendly unit while in air mode.
	pass


func fire_primary() -> void:
	# Placeholder hook for the commander's primary attack.
	pass


func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0:
		die()


func die() -> void:
	EventBus.commander_died.emit(self)
	queue_free()


func _update_mode_visuals() -> void:
	if ground_mesh == null or air_mesh == null:
		return
	ground_mesh.visible = mode == Constants.CommanderMode.GROUND
	air_mesh.visible = mode == Constants.CommanderMode.AIR
