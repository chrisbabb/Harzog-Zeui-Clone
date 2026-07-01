class_name VFXParticleUtil
extends RefCounted
## Shared helpers for the procedural VFX effect scenes under scenes/effects/
## (MuzzleFlash, SmokePuff, DustTrail, Contrail, CaptureBeam, RepairBeam,
## SpawnWarp, ShieldHit). Mirrors MaterialLibrary/UnitVisualFactory's
## stateless static-utility pattern -- without this, each of those small,
## self-contained effect scripts would duplicate the same handful of
## particle-material and orientation helpers.


static func make_quad_mesh(size: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = material
	return mesh


static func make_fade_gradient(color: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


## Rotates `node` so its local -Z faces `direction`, skipping the rare
## degenerate case where look_at() would fail (direction parallel to the up
## vector) so callers never need their own guard.
static func orient_along(node: Node3D, direction: Vector3) -> void:
	if direction.length() < 0.01:
		return
	var normalized: Vector3 = direction.normalized()
	if absf(normalized.dot(Vector3.UP)) > 0.999:
		return
	node.look_at(node.global_position + normalized, Vector3.UP)


## A beam-style ParticleProcessMaterial: particles travel in a straight line
## toward `direction` at a velocity tuned so they cover `distance` in
## `lifetime` seconds -- see CaptureBeam.gd/RepairBeam.gd.
static func make_beam_material(direction: Vector3, distance: float, lifetime: float, color: Color) -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	var speed: float = distance / max(lifetime, 0.01)
	material.direction = direction
	material.spread = 4.0
	material.initial_velocity_min = speed
	material.initial_velocity_max = speed
	material.gravity = Vector3.ZERO
	material.scale_min = 0.4
	material.scale_max = 0.8
	material.color_ramp = make_fade_gradient(color)
	return material
