extends Node3D
## Particle beam from one world position to another, in a fixed "support"
## blue -- spawned as short repeated pulses by VFXManager.spawn_repair_beam()
## while a Supply Truck is actively repairing something. Self-frees once its
## particles finish.

const AMOUNT: int = 10
const LIFETIME: float = 0.35
const PARTICLE_SIZE: float = 0.1
const MAX_LIFETIME: float = LIFETIME + 0.2

@onready var particles: GPUParticles3D = $GPUParticles3D


func _ready() -> void:
	particles.one_shot = true
	particles.emitting = false
	particles.lifetime = LIFETIME
	particles.amount = AMOUNT
	particles.local_coords = false
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(PARTICLE_SIZE)


func configure(from_position: Vector3, to_position: Vector3) -> void:
	global_position = from_position
	var offset: Vector3 = to_position - from_position
	var distance: float = offset.length()
	var direction: Vector3 = offset / distance if distance > 0.05 else Vector3.UP
	distance = max(distance, 0.5)

	var color: Color = MaterialLibrary.energy_blue().albedo_color
	particles.process_material = VFXParticleUtil.make_beam_material(direction, distance, LIFETIME, color)
	particles.emitting = true
	particles.finished.connect(queue_free)
	get_tree().create_timer(MAX_LIFETIME).timeout.connect(queue_free)
