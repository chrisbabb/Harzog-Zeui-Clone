extends Node3D
## One-shot rising smoke puff. Spawned by VFXManager.spawn_smoke_puff() and
## self-frees once its particle burst finishes -- GPUParticles3D.finished is
## only emitted for one_shot systems, which this always is. Not team-colored
## (dark smoke reads the same for either side).

const AMOUNT: int = 10
const LIFETIME: float = 1.1
const PARTICLE_SIZE: float = 0.4
const SMOKE_COLOR: Color = Color(0.12, 0.12, 0.13, 0.55)
# Backup cleanup in case `finished` never fires (e.g. emitting was somehow
# never set) so a stray SmokePuff can never leak forever.
const MAX_LIFETIME: float = LIFETIME + 1.0

@onready var particles: GPUParticles3D = $GPUParticles3D


func _ready() -> void:
	particles.one_shot = true
	particles.emitting = false
	particles.lifetime = LIFETIME
	particles.amount = AMOUNT
	particles.local_coords = false
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(PARTICLE_SIZE)
	particles.process_material = _make_process_material()
	particles.finished.connect(queue_free)
	particles.emitting = true
	get_tree().create_timer(MAX_LIFETIME).timeout.connect(queue_free)


func _make_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 22.0
	material.initial_velocity_min = 0.4
	material.initial_velocity_max = 0.9
	material.gravity = Vector3(0.0, 0.35, 0.0)
	material.scale_min = 0.8
	material.scale_max = 1.6
	material.color_ramp = VFXParticleUtil.make_fade_gradient(SMOKE_COLOR)
	return material
