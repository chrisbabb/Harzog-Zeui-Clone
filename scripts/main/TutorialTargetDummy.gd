class_name TutorialTargetDummy
extends StaticBody3D
## Stationary, unarmed practice target for the tutorial's combat objective.
## Built entirely in code (like MapGenerator's obstacles), it mimics just
## enough of Unit.gd/Base.gd's interface -- team, hp/max_hp, is_destroyed,
## take_damage() -- to be a valid attack target under the normal
## targeting/damage pipeline (see Unit.gd's _is_valid_target/_find_target).

const BODY_SIZE: Vector3 = Vector3(2.0, 2.4, 2.0)
const BODY_COLOR: Color = Color(0.55, 0.2, 0.2)
const HEALTH_BAR_HEIGHT: float = 3.6
const HEALTH_BAR_SIZE: Vector3 = Vector3(1.6, 0.2, 0.05)

@export var team: int = Constants.Team.ENEMY
@export var max_hp: float = 120.0

var hp: float
var is_destroyed: bool = false
var _body_material: StandardMaterial3D
var _flash_remaining: float = 0.0
var _health_bar: MeshInstance3D
var _health_bar_material: StandardMaterial3D


func _ready() -> void:
	hp = max_hp
	_build_visuals()


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return
	_update_flash(delta)
	_update_health_bar()


func take_damage(amount: float, _attacker: Node = null) -> void:
	if is_destroyed:
		return
	hp = max(0.0, hp - amount)
	_flash_remaining = Constants.DAMAGE_FLASH_DURATION
	if hp <= 0.0:
		_destroy()


func _destroy() -> void:
	is_destroyed = true
	visible = false
	collision_layer = 0
	collision_mask = 0


func _build_visuals() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = BODY_COLOR

	var mesh := BoxMesh.new()
	mesh.size = BODY_SIZE
	mesh.material = _body_material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, BODY_SIZE.y * 0.5, 0.0)
	add_child(mesh_instance)

	var shape := BoxShape3D.new()
	shape.size = BODY_SIZE
	var collision_shape := CollisionShape3D.new()
	collision_shape.shape = shape
	collision_shape.position = mesh_instance.position
	add_child(collision_shape)

	_health_bar = MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = HEALTH_BAR_SIZE
	_health_bar.mesh = bar_mesh
	_health_bar_material = StandardMaterial3D.new()
	_health_bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_health_bar_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_health_bar_material.albedo_color = Constants.team_color(team)
	_health_bar.material_override = _health_bar_material
	_health_bar.position = Vector3(0.0, HEALTH_BAR_HEIGHT, 0.0)
	add_child(_health_bar)


func _update_health_bar() -> void:
	var ratio: float = hp / max_hp if max_hp > 0.0 else 0.0
	_health_bar.scale.x = clamp(ratio, 0.05, 1.0)


func _update_flash(delta: float) -> void:
	if _flash_remaining <= 0.0:
		return
	_flash_remaining -= delta
	_body_material.albedo_color = Constants.DAMAGE_FLASH_COLOR if _flash_remaining > 0.0 else BODY_COLOR
