extends Node3D
## "Materialize" effect for a freshly spawned unit: a tapered energy column
## that retracts into the ground, plus an upward particle burst. Spawned by
## VFXManager.spawn_spawn_warp(); self-frees once its animation finishes.

const DURATION: float = 0.5
## Must match the Column mesh's baked height in SpawnWarp.tscn.
const COLUMN_HEIGHT: float = 3.0
const PARTICLE_AMOUNT: int = 14
const PARTICLE_LIFETIME: float = 0.6
const PARTICLE_SIZE: float = 0.15
const MAX_LIFETIME: float = DURATION + PARTICLE_LIFETIME + 0.3

var _age: float = 0.0
var _material: StandardMaterial3D

@onready var column: MeshInstance3D = $Column
@onready var particles: GPUParticles3D = $GPUParticles3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	column.material_override = _material
	column.position.y = COLUMN_HEIGHT * 0.5

	particles.one_shot = true
	particles.emitting = false
	particles.lifetime = PARTICLE_LIFETIME
	particles.amount = PARTICLE_AMOUNT
	particles.local_coords = false
	particles.draw_pass_1 = VFXParticleUtil.make_quad_mesh(PARTICLE_SIZE)
	# Registered unconditionally (not in configure()) so a SpawnWarp instance
	# can never leak even if configure() is never called.
	get_tree().create_timer(MAX_LIFETIME).timeout.connect(queue_free)


func configure(color: Color) -> void:
	_material.albedo_color = color
	_material.emission = color

	var particle_material := ParticleProcessMaterial.new()
	particle_material.direction = Vector3.UP
	particle_material.spread = 25.0
	particle_material.initial_velocity_min = 1.5
	particle_material.initial_velocity_max = 3.0
	particle_material.gravity = Vector3(0.0, -1.5, 0.0)
	particle_material.scale_min = 0.5
	particle_material.scale_max = 1.0
	particle_material.color_ramp = VFXParticleUtil.make_fade_gradient(color)
	particles.process_material = particle_material
	particles.emitting = true


## The column retracts into the ground -- its bottom edge stays pinned at
## local y=0 while its top shrinks down to meet it, rather than shrinking
## toward its own center.
func _process(delta: float) -> void:
	_age += delta
	var progress: float = clamp(_age / DURATION, 0.0, 1.0)
	var remaining: float = 1.0 - progress
	column.scale.y = remaining
	column.position.y = COLUMN_HEIGHT * 0.5 * remaining
	_material.albedo_color.a = remaining
	if progress >= 1.0:
		column.visible = false
		set_process(false)
