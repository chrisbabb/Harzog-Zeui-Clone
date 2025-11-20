extends Area2D
class_name Bullet
## Bullet - Projectile fired by units
##
## Features:
## - Travels in a straight line
## - Deals damage on collision
## - Auto-destroys after max range

# Bullet properties
var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: float = 10.0
var max_range: float = 150.0
var team_color: String = ""
var owner_unit = null

# Tracking
var distance_traveled: float = 0.0
var start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	start_position = global_position

	# Connect collision signal
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Set collision layers
	collision_layer = 0  # Bullet doesn't have a layer
	collision_mask = 1  # Can hit layer 1 (units/buildings)

	# Create visual
	_create_visual()


func _physics_process(delta: float) -> void:
	# Move bullet
	var movement = direction * speed * delta
	global_position += movement
	distance_traveled += movement.length()

	# Handle toroidal wrapping
	global_position = ToroidalWorld.wrap_position(global_position)

	# Destroy if exceeded max range
	if distance_traveled >= max_range:
		queue_free()


## Create visual representation
func _create_visual() -> void:
	# Create a small circle for the bullet
	var circle = ColorRect.new()
	circle.size = Vector2(6, 6)
	circle.position = Vector2(-3, -3)

	# Color based on team
	match team_color:
		"Red":
			circle.color = Color(1.0, 0.4, 0.4, 1.0)
		"Blue":
			circle.color = Color(0.4, 0.6, 1.0, 1.0)
		"Green":
			circle.color = Color(0.4, 1.0, 0.4, 1.0)
		"Yellow":
			circle.color = Color(1.0, 1.0, 0.4, 1.0)
		_:
			circle.color = Color.WHITE

	add_child(circle)

	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 3.0
	collision.shape = shape
	add_child(collision)


## Handle collision with bodies (CharacterBody2D units)
func _on_body_entered(body: Node) -> void:
	_try_damage_entity(body)


## Handle collision with areas (Area2D for potential future use)
func _on_area_entered(area: Node) -> void:
	_try_damage_entity(area)


## Try to damage an entity
func _try_damage_entity(entity: Node) -> void:
	# Don't hit ourselves
	if entity == owner_unit:
		return

	# Check if entity is an enemy
	if not "team_color" in entity:
		return

	if entity.team_color == team_color:
		return  # Friendly fire disabled

	# Check if entity is already dead
	if entity.has_method("is_dead") and entity.is_dead():
		return

	# Deal damage
	if entity.has_method("take_damage"):
		entity.take_damage(damage)

	# Destroy bullet after hit
	queue_free()


## Initialize bullet
func initialize(start_pos: Vector2, dir: Vector2, dmg: float, rng: float, team: String, owner) -> void:
	global_position = start_pos
	direction = dir.normalized()
	damage = dmg
	max_range = rng
	team_color = team
	owner_unit = owner
