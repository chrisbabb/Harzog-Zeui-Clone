extends Node3D
## One-shot muzzle flash: a small emissive sphere that pops to size and fades
## out quickly. Spawned by VFXManager.spawn_muzzle_flash() and configured
## immediately afterward via configure(); self-frees once its fade finishes.
## This is a procedural placeholder effect -- meant to be replaceable by an
## authored sprite/shader flash later without touching any caller.

const DURATION: float = 0.08
const BASE_RADIUS: float = 0.25
const PEAK_PULSE_SCALE: float = 1.15
const START_PULSE_SCALE: float = 0.4
const DIRECTIONAL_STRETCH: float = 1.4

var _age: float = 0.0
var _material: StandardMaterial3D

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.emission_enabled = true
	mesh_instance.material_override = _material


## direction is a world-space hint for which way the weapon is pointing --
## used to stretch the flash slightly along the fire direction; skipped
## (flash stays spherical) if direction is too small or nearly vertical.
func configure(direction: Vector3, color: Color, size: float = 1.0) -> void:
	_material.albedo_color = color
	_material.emission = color
	scale = Vector3.ONE * BASE_RADIUS * max(size, 0.05)
	VFXParticleUtil.orient_along(self, direction)


func _process(delta: float) -> void:
	_age += delta
	var progress: float = clamp(_age / DURATION, 0.0, 1.0)
	var pulse: float = sin(progress * PI)
	var pulse_scale: float = lerp(START_PULSE_SCALE, PEAK_PULSE_SCALE, pulse)
	mesh_instance.scale = Vector3(pulse_scale, pulse_scale, pulse_scale * DIRECTIONAL_STRETCH)
	_material.albedo_color.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()
