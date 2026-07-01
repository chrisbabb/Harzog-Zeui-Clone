extends Node3D
## Trailing particle streak. Two modes:
## - standalone (continuous=false, the default): a brief one-shot burst
##   spawned by VFXManager.spawn_contrail(), oriented via `direction` and
##   self-freeing once its particles finish.
## - attached (continuous=true): parented directly onto a moving node (see
##   VFXManager.spawn_projectile_trail()) and left continuously emitting;
##   cleanup relies on the parent's own lifecycle, not a timer here.

const AMOUNT: int = 18
const LIFETIME: float = 0.45
const PARTICLE_SIZE: float = 0.16
const MAX_LIFETIME: float = LIFETIME + 0.3

@onready var particles: GPUParticles3D = $GPUParticles3D


func _ready() -> void:
	particles.lifetime = LIFETIME
	particles.amount = AMOUNT
	particles.local_coords = false
	particles.emitting = false
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(PARTICLE_SIZE)


## direction orients the streak (particles trail backward along it); a zero
## direction leaves the node's default orientation. continuous=true keeps
## emitting indefinitely (attached-to-projectile use, cleaned up when the
## parent frees); continuous=false bursts once and self-frees.
func configure(direction: Vector3, color: Color, continuous: bool = false) -> void:
	particles.one_shot = not continuous
	VFXParticleUtil.orient_along(self, direction)

	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.BACK
	material.spread = 10.0
	material.initial_velocity_min = 1.0
	material.initial_velocity_max = 2.5
	material.gravity = Vector3.ZERO
	material.scale_min = 0.5
	material.scale_max = 1.1
	material.color_ramp = VFXParticleUtil.make_fade_gradient(color)
	particles.process_material = material
	particles.emitting = true

	if not continuous:
		particles.finished.connect(queue_free)
		get_tree().create_timer(MAX_LIFETIME).timeout.connect(queue_free)
