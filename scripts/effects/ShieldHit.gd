extends Node3D
## Quick expanding ring flash at an impact point -- a shield-deflect visual
## with no current gameplay trigger (no shield mechanic exists yet), kept
## available for future use via VFXManager.spawn_shield_hit(). Self-frees
## once its animation finishes.

const DURATION: float = 0.25
const START_SCALE: float = 0.3
const END_SCALE: float = 1.3

var _age: float = 0.0
var _material: StandardMaterial3D

@onready var ring: MeshInstance3D = $Ring


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	ring.material_override = _material
	scale = Vector3.ONE * START_SCALE


func configure(color: Color) -> void:
	_material.albedo_color = color
	_material.emission = color


func _process(delta: float) -> void:
	_age += delta
	var progress: float = clamp(_age / DURATION, 0.0, 1.0)
	scale = Vector3.ONE * lerp(START_SCALE, END_SCALE, progress)
	_material.albedo_color.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()
