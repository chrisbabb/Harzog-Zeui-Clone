extends Node3D
## Generic team-aware projectile fired by units and the commander. Travels
## from its spawn point toward target_position -- in a straight line, or a
## parabolic arc when is_arcing is set (artillery) -- and detonates either on
## touching the first valid enemy body in its path, or on reaching
## target_position with nothing in the way. Ignores its own source and
## anything on the same team.

const EXPLOSION_SCENE: PackedScene = preload("res://scenes/effects/Explosion.tscn")
const ARC_HEIGHT: float = 4.0

## Projectiles use punchier, more saturated colors than the muted team-strip
## color so shots stand out against the battlefield: player bolts read as
## blue/cyan, enemy bolts as red/orange. Artillery shells additionally glow
## brighter so their larger, slower-arcing shot reads as more powerful.
const PLAYER_PROJECTILE_COLOR: Color = Color(0.35, 0.85, 1.0)
const ENEMY_PROJECTILE_COLOR: Color = Color(1.0, 0.55, 0.15)
const DEFAULT_EMISSION_ENERGY: float = 1.4
const ARCING_EMISSION_ENERGY: float = 2.2

var team: int = Constants.Team.PLAYER
var damage: float = 10.0
var speed: float = 30.0
var lifetime: float = 3.0
var target_position: Vector3 = Vector3.ZERO
var can_hit_air: bool = true
var can_hit_ground: bool = true
var source: Node = null
var is_arcing: bool = false

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var hit_area: Area3D = $HitArea

static var _cached_player_mat: StandardMaterial3D
static var _cached_enemy_mat: StandardMaterial3D

var _start_position: Vector3
var _total_distance: float = 1.0
var _traveled: float = 0.0
var _age: float = 0.0
var _detonated: bool = false
var _initialized: bool = false


func _ready() -> void:
	hit_area.body_entered.connect(_on_body_entered)
	add_to_group("projectiles")


## Deferred to the first physics tick rather than _ready(), since callers
## add this to the tree (which fires _ready() synchronously) before they
## finish setting team/target_position via the duck-typed .set() pattern
## used at every call site -- mirroring how units/buildings are spawned
## elsewhere in this codebase.
func _initialize() -> void:
	_initialized = true
	_start_position = global_position
	_total_distance = max(_start_position.distance_to(target_position), 0.01)

	if is_arcing:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.emission_enabled = true
		var color: Color = _projectile_color()
		material.albedo_color = color
		material.emission = color
		material.emission_energy_multiplier = ARCING_EMISSION_ENERGY
		mesh_instance.material_override = material
	else:
		mesh_instance.material_override = _get_shared_material()


func _get_shared_material() -> StandardMaterial3D:
	if team == Constants.Team.PLAYER:
		if _cached_player_mat == null:
			_cached_player_mat = _make_mat(PLAYER_PROJECTILE_COLOR, DEFAULT_EMISSION_ENERGY)
		return _cached_player_mat
	else:
		if _cached_enemy_mat == null:
			_cached_enemy_mat = _make_mat(ENEMY_PROJECTILE_COLOR, DEFAULT_EMISSION_ENERGY)
		return _cached_enemy_mat


static func _make_mat(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.albedo_color = color
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _physics_process(delta: float) -> void:
	if not _initialized:
		_initialize()

	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	_traveled = min(_traveled + speed * delta, _total_distance)
	var progress: float = _traveled / _total_distance
	global_position = _start_position.lerp(target_position, progress)
	if is_arcing:
		global_position.y += sin(progress * PI) * ARC_HEIGHT

	if progress >= 1.0:
		_detonate(null)


func _on_body_entered(body: Node) -> void:
	if _detonated or body == source or body.get("team") == team:
		return
	if not _is_valid_target(body):
		return
	body.take_damage(damage, source)
	_detonate(body)


func _is_valid_target(body: Node) -> bool:
	if not body.has_method("take_damage") or body.get("is_destroyed") == true:
		return false
	var is_air_target: bool = _is_airborne_commander(body)
	return can_hit_air if is_air_target else can_hit_ground


func _projectile_color() -> Color:
	return PLAYER_PROJECTILE_COLOR if team == Constants.Team.PLAYER else ENEMY_PROJECTILE_COLOR


func _is_airborne_commander(body: Node) -> bool:
	var is_commander: bool = body == GameState.player_commander or body == GameState.enemy_commander
	return is_commander and body.get("mode") == Constants.CommanderMode.AIR


func _detonate(hit_body: Node) -> void:
	_detonated = true
	_spawn_explosion(hit_body)
	queue_free()


func _spawn_explosion(hit_body: Node) -> void:
	var explosion: Node3D = EXPLOSION_SCENE.instantiate() as Node3D
	get_parent().add_child(explosion)
	explosion.global_position = global_position
	explosion.call("setup", hit_body is StaticBody3D)
