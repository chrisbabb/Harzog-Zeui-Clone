extends Node3D
## Particle beam from one world position to another -- particles travel the
## distance in roughly LIFETIME seconds via VFXParticleUtil.make_beam_material
## (the same velocity=distance/lifetime technique UnitAnimator's Supply Truck
## repair beam uses). Spawned by VFXManager.spawn_capture_beam(); self-frees
## once its particles finish.

const AMOUNT: int = 16
const LIFETIME: float = 0.5
const PARTICLE_SIZE: float = 0.12
const MAX_LIFETIME: float = LIFETIME + 0.3

@onready var particles: GPUParticles3D = $GPUParticles3D


func _ready() -> void:
	particles.one_shot = true
	particles.emitting = false
	particles.lifetime = LIFETIME
	particles.amount = AMOUNT
	particles.local_coords = false
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(PARTICLE_SIZE)


## Positions this node at from_position and streams particles toward
## to_position. Safe if the two points coincide (falls back to a small
## upward direction rather than a zero-length one).
func configure(from_position: Vector3, to_position: Vector3, color: Color) -> void:
	global_position = from_position
	var offset: Vector3 = to_position - from_position
	var distance: float = offset.length()
	var direction: Vector3 = offset / distance if distance > 0.05 else Vector3.UP
	distance = max(distance, 0.5)

	particles.process_material = VFXParticleUtil.make_beam_material(direction, distance, LIFETIME, color)
	particles.emitting = true
	particles.finished.connect(queue_free)
	get_tree().create_timer(MAX_LIFETIME).timeout.connect(queue_free)
