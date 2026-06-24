extends Area3D
## Simple energy-shot projectile fired by the commander's primary weapon.
## Travels in a straight line and damages the first enemy body it touches.

const SPEED: float = 40.0
const DAMAGE: float = 25.0
const LIFETIME: float = 3.0

var team: int = Constants.Team.PLAYER
var direction: Vector3 = Vector3.FORWARD

var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * SPEED * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.get("team") == team:
		return
	if body.has_method("take_damage"):
		body.take_damage(DAMAGE)
	queue_free()
