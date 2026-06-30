extends Node3D
## Self-animating, self-freeing explosion: expands and fades out over a
## short duration. Spawned by Projectile on detonation -- small for units,
## large for buildings/terrain impacts (setup(is_large)).

const START_SCALE: float = 0.2
const SMALL_DURATION: float = 0.35
const SMALL_END_SCALE: float = 1.6
const SMALL_COLOR: Color = Color(1.0, 0.65, 0.15)
const LARGE_DURATION: float = 0.55
const LARGE_END_SCALE: float = 3.0
const LARGE_COLOR: Color = Color(1.0, 0.45, 0.1)

const SPARK_AMOUNT_SMALL: int = 14
const SPARK_AMOUNT_LARGE: int = 26
const SPARK_PARTICLE_SIZE: float = 0.15
const SPARK_LIFETIME: float = 0.45
const SPARK_COLOR: Color = Color(1.0, 0.8, 0.4)

const SHAKE_STRENGTH_SMALL: float = 0.15
const SHAKE_STRENGTH_LARGE: float = 0.4

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _material: StandardMaterial3D
var _duration: float = SMALL_DURATION
var _end_scale: float = SMALL_END_SCALE
var _age: float = 0.0
var _sparks: GPUParticles3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_material.albedo_color = SMALL_COLOR
	_material.emission = SMALL_COLOR
	mesh_instance.material_override = _material
	scale = Vector3.ONE * START_SCALE
	_create_sparks()


func setup(is_large: bool) -> void:
	_duration = LARGE_DURATION if is_large else SMALL_DURATION
	_end_scale = LARGE_END_SCALE if is_large else SMALL_END_SCALE
	var color: Color = LARGE_COLOR if is_large else SMALL_COLOR
	_material.albedo_color = color
	_material.emission = color
	_sparks.amount = SPARK_AMOUNT_LARGE if is_large else SPARK_AMOUNT_SMALL
	_sparks.emitting = true
	EventBus.audio_event_requested.emit("explosion_large" if is_large else "explosion_small")
	EventBus.camera_shake_requested.emit(SHAKE_STRENGTH_LARGE if is_large else SHAKE_STRENGTH_SMALL)


func _process(delta: float) -> void:
	_age += delta
	var progress: float = clamp(_age / _duration, 0.0, 1.0)
	scale = Vector3.ONE * lerp(START_SCALE, _end_scale, progress)
	_material.albedo_color.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()


## A brief outward burst of sparks layered on top of the scaling/fading
## fireball mesh above. One-shot and self-contained, so it just fires once
## in setup() and is left to finish and get cleaned up with the rest of this
## node. local_coords = false keeps the burst from being warped by this
## node's own scale-up animation.
func _create_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.one_shot = true
	_sparks.emitting = false
	_sparks.lifetime = SPARK_LIFETIME
	_sparks.local_coords = false
	_sparks.draw_pass_1 = _build_spark_mesh()
	_sparks.process_material = _build_spark_process_material()
	add_child(_sparks)


func _build_spark_mesh() -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(SPARK_PARTICLE_SIZE, SPARK_PARTICLE_SIZE)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	return mesh


func _build_spark_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 180.0
	material.initial_velocity_min = 2.0
	material.initial_velocity_max = 5.0
	material.gravity = Vector3(0.0, -4.0, 0.0)
	material.scale_min = 0.6
	material.scale_max = 1.3

	var gradient := Gradient.new()
	gradient.set_color(0, SPARK_COLOR)
	gradient.set_color(1, Color(SPARK_COLOR.r, SPARK_COLOR.g, SPARK_COLOR.b, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	material.color_ramp = texture

	return material
