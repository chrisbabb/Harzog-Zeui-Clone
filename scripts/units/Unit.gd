extends CharacterBody3D
## Placeholder script for a generic ground unit.
## Uses NavigationAgent3D to move toward an ordered destination.

@export var max_health: float = 100.0
@export var move_speed: float = Constants.UNIT_DEFAULT_SPEED
@export var team: int = Constants.Team.PLAYER
@export var unit_class: int = Constants.UnitClass.INFANTRY

var current_health: float
var current_order: int = Constants.CommandAction.HOLD

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D


func _ready() -> void:
	current_health = max_health
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = Constants.UNIT_NAVIGATION_ARRIVAL_DISTANCE
	GameState.register_unit(self)


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
	current_order = Constants.CommandAction.MOVE
	nav_agent.target_position = destination


func stop() -> void:
	current_order = Constants.CommandAction.STOP
	nav_agent.target_position = global_position


func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0:
		die()


func die() -> void:
	GameState.unregister_unit(self)
	queue_free()
