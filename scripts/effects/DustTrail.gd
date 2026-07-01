extends Node3D
## One-shot ground-dust burst kicked up behind a moving object. Spawned by
## VFXManager.spawn_dust_trail(); self-frees once its particle burst
## finishes. Not team-colored (dust reads the same for either side).

const AMOUNT: int = 8
const LIFETIME: float = 0.5
const PARTICLE_SIZE: float = 0.22
const DUST_COLOR: Color = Color(0.55, 0.48, 0.35, 0.45)
const MAX_LIFETIME: float = LIFETIME + 0.5

@onready var particles: GPUParticles3D = $GPUParticles3D


func _ready() -> void:
	particles.one_shot = true
	particles.emitting = false
	particles.lifetime = LIFETIME
	particles.amount = AMOUNT
	particles.local_coords = false
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(PARTICLE_SIZE)
	particles.finished.connect(queue_free)
	get_tree().create_timer(MAX_LIFETIME).timeout.connect(queue_free)


## velocity is the moving object's current velocity -- dust kicks up and
## trails opposite the direction of travel. A near-zero velocity still
## produces a plain upward puff rather than doing nothing.
func configure(velocity: Vector3) -> void:
	var material := ParticleProcessMaterial.new()
	var backward: Vector3 = Vector3.ZERO
	if velocity.length() > 0.1:
		backward = -Vector3(velocity.x, 0.0, velocity.z).normalized()
	material.direction = (Vector3.UP + backward * 0.6).normalized()
	material.spread = 40.0
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.4
	material.gravity = Vector3(0.0, -1.0, 0.0)
	material.scale_min = 0.5
	material.scale_max = 1.0
	material.color_ramp = VFXParticleUtil.make_fade_gradient(DUST_COLOR)
	particles.process_material = material
	particles.emitting = true
