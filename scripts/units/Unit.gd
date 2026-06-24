extends CharacterBody3D
## Placeholder script for a generic ground unit.
## Uses NavigationAgent3D to move toward an ordered destination.

@export var max_health: float = 100.0
@export var move_speed: float = Constants.UNIT_DEFAULT_SPEED
@export var team: int = Constants.Team.PLAYER
@export var unit_type: int = Constants.UnitType.TANK

var current_health: float
var current_order: int = Constants.UnitOrder.HOLD_POSITION

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	current_health = max_health
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = Constants.UNIT_NAVIGATION_ARRIVAL_DISTANCE
	add_to_group("units")
	EventBus.unit_created.emit(self)


func _physics_process(_delta: float) -> void:
	if nav_agent.is_navigation_finished():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var next_path_position: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = (next_path_position - global_position)
	direction.y = 0.0
	direction = direction.normalized()
	velocity = direction * move_speed
	move_and_slide()


func move_to(destination: Vector3) -> void:
	current_order = Constants.UnitOrder.ADVANCE_TO_TARGET
	nav_agent.target_position = destination
	EventBus.unit_order_changed.emit(self, current_order)


func stop() -> void:
	current_order = Constants.UnitOrder.HOLD_POSITION
	nav_agent.target_position = global_position
	EventBus.unit_order_changed.emit(self, current_order)


func set_carried(carried: bool) -> void:
	# Disabling physics_process freezes movement in place; re-enabling it
	# naturally resumes whatever order/nav target was already set.
	visible = not carried
	collision_shape.disabled = carried
	set_physics_process(not carried)


func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0:
		die()


func die() -> void:
	EventBus.unit_destroyed.emit(self)
	queue_free()
