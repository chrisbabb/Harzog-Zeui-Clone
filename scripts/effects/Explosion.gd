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

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _material: StandardMaterial3D
var _duration: float = SMALL_DURATION
var _end_scale: float = SMALL_END_SCALE
var _age: float = 0.0


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	_material.albedo_color = SMALL_COLOR
	_material.emission = SMALL_COLOR
	mesh_instance.material_override = _material
	scale = Vector3.ONE * START_SCALE


func setup(is_large: bool) -> void:
	_duration = LARGE_DURATION if is_large else SMALL_DURATION
	_end_scale = LARGE_END_SCALE if is_large else SMALL_END_SCALE
	var color: Color = LARGE_COLOR if is_large else SMALL_COLOR
	_material.albedo_color = color
	_material.emission = color


func _process(delta: float) -> void:
	_age += delta
	var progress: float = clamp(_age / _duration, 0.0, 1.0)
	scale = Vector3.ONE * lerp(START_SCALE, _end_scale, progress)
	_material.albedo_color.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()
