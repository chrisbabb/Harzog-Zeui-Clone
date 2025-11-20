extends StaticBody2D
class_name TurretBase
## TurretBase - Base class for all turrets (immobile defensive structures)
##
## Features:
## - Cannot move (immobile)
## - Targeting system
## - Health
## - Team/ownership
## Similar to UnitBase but for stationary defenses

# Unit properties
@export var unit_name: String = "Turret"
@export var unit_type: String = "turret"
@export var max_health: float = 300.0
@export var attack_range: float = 250.0
@export var attack_damage: float = 20.0
@export var attack_cooldown: float = 1.0
@export var detection_range: float = 350.0
@export var is_flying: bool = false  # Turrets are always ground-based

# Ownership
var owner_slot: int = -1  # Which player owns this turret (1-4)
var team_color: String = ""

# Targeting
var current_target = null
var time_since_retarget: float = 0.0
const RETARGET_INTERVAL: float = 0.1  # 100ms

# Combat
var current_health: float
var time_since_attack: float = 0.0

# Health bar
var health_bar: ProgressBar = null


func _ready() -> void:
	current_health = max_health
	add_to_group("turrets")
	add_to_group("buildings")
	_create_health_bar()


func _process(delta: float) -> void:
	if is_dead():
		return

	# Update retarget timer
	time_since_retarget += delta
	if time_since_retarget >= RETARGET_INTERVAL:
		time_since_retarget = 0.0
		_retarget()

	# Engage target if we have one
	if current_target and _is_valid_target(current_target):
		_engage_target(delta)
	else:
		current_target = null


## Engage current target
func _engage_target(delta: float) -> void:
	var target_pos = _get_target_position(current_target)
	var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, target_pos)

	# If target is in attack range, attack
	if dist_sq <= attack_range * attack_range:
		_attack_target(delta)


## Retarget - find best target in range
func _retarget() -> void:
	var best_target = _find_best_target_in_range()
	if best_target:
		current_target = best_target


## Find the best target within detection range
## Override this in subclasses to implement specific targeting logic
func _find_best_target_in_range():
	return null  # Base implementation - subclasses override


## Check if a target is still valid
func _is_valid_target(target) -> bool:
	if not is_instance_valid(target):
		return false

	if target.has_method("is_dead") and target.is_dead():
		return false

	# Check if still in detection range
	var target_pos = _get_target_position(target)
	var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, target_pos)
	return dist_sq <= detection_range * detection_range


## Get position of a target
func _get_target_position(target) -> Vector2:
	if "global_position" in target:
		return target.global_position
	elif "position" in target:
		return target.position
	return Vector2.ZERO


## Attack current target
func _attack_target(delta: float) -> void:
	time_since_attack += delta
	if time_since_attack >= attack_cooldown:
		time_since_attack = 0.0
		_perform_attack()


## Perform attack (override in subclasses for specific behavior)
func _perform_attack() -> void:
	if current_target and current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)


## Take damage
func take_damage(amount: float) -> void:
	current_health -= amount
	_update_health_bar()
	if current_health <= 0:
		_die()


## Check if turret is dead
func is_dead() -> bool:
	return current_health <= 0


## Die
func _die() -> void:
	# TODO: Play death animation, effects
	queue_free()


## Create health bar above turret
func _create_health_bar() -> void:
	health_bar = ProgressBar.new()
	health_bar.size = Vector2(50, 8)
	health_bar.position = Vector2(-25, -40)
	health_bar.min_value = 0
	health_bar.max_value = max_health
	health_bar.value = current_health
	health_bar.show_percentage = false

	# Style the health bar
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	health_bar.add_theme_stylebox_override("background", style_bg)

	var style_fg = StyleBoxFlat.new()
	style_fg.bg_color = Color(0.2, 0.8, 0.2, 1.0)  # Green
	health_bar.add_theme_stylebox_override("fill", style_fg)

	add_child(health_bar)


## Update health bar to reflect current health
func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health

		# Change color based on health percentage
		var health_percent = current_health / max_health
		var style_fg = StyleBoxFlat.new()

		if health_percent > 0.6:
			style_fg.bg_color = Color(0.2, 0.8, 0.2, 1.0)  # Green
		elif health_percent > 0.3:
			style_fg.bg_color = Color(0.9, 0.9, 0.2, 1.0)  # Yellow
		else:
			style_fg.bg_color = Color(0.9, 0.2, 0.2, 1.0)  # Red

		health_bar.add_theme_stylebox_override("fill", style_fg)


## Set turret ownership
func set_owner_info(slot: int, color: String) -> void:
	owner_slot = slot
	team_color = color
