extends CharacterBody2D
class_name UnitBase
## UnitBase - Base class for all units in the game
##
## Features:
## - State machine
## - Targeting system
## - Movement
## - Health
## - Team/ownership

# Unit state enumeration
enum State {
	IDLE,
	MARCHING_TO_TARGET,
	ENGAGING_TARGET,
	DEAD
}

# Stance enumeration
enum Stance {
	HOLD_POSITION,
	ADVANCE
}

# Behavior mode enumeration (for deployed units)
enum BehaviorMode {
	NORMAL,              # Standard behavior
	GUARD_POSITION,      # Guard a specific spot, return after combat
	ATTACK_BASE_ONLY     # Only attack enemy main bases, ignore other units
}

# Unit properties
@export var unit_name: String = "Unit"
@export var unit_type: String = "generic"
@export var max_health: float = 100.0
@export var move_speed: float = 100.0
@export var attack_range: float = 150.0
@export var attack_damage: float = 10.0
@export var attack_cooldown: float = 1.0
@export var detection_range: float = 300.0
@export var is_flying: bool = false  # True for air units (plane mode, etc.)

# Ownership
var owner_slot: int = -1  # Which player owns this unit (1-4)
var team_color: String = ""

# State
var current_state: State = State.IDLE
var stance: Stance = Stance.ADVANCE
var behavior_mode: BehaviorMode = BehaviorMode.NORMAL

# Guard position (for GUARD_POSITION mode)
var guard_position: Vector2 = Vector2.ZERO
const GUARD_RETURN_THRESHOLD: float = 150.0  # Distance from guard position before returning

# Targeting
var current_target = null
var time_since_retarget: float = 0.0
const RETARGET_INTERVAL: float = 0.1  # 100ms

# Combat
var current_health: float
var time_since_attack: float = 0.0

# Movement
var strategic_target_position: Vector2 = Vector2.ZERO

# Player control
var player_controlled: bool = false  # Set to true when a PlayerController is attached

# Health bar
var health_bar: ProgressBar = null


func _ready() -> void:
	current_health = max_health
	add_to_group("units")
	_create_health_bar()


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Skip AI behavior if player is controlling this unit
	if player_controlled:
		return

	# Update retarget timer
	time_since_retarget += delta
	if time_since_retarget >= RETARGET_INTERVAL:
		time_since_retarget = 0.0
		_retarget()

	# Update state machine
	_update_state(delta)


## Main state machine update
func _update_state(delta: float) -> void:
	match current_state:
		State.IDLE:
			_state_idle(delta)
		State.MARCHING_TO_TARGET:
			_state_marching(delta)
		State.ENGAGING_TARGET:
			_state_engaging(delta)
		State.DEAD:
			pass


## IDLE state behavior
func _state_idle(_delta: float) -> void:
	# Guard position mode: return to guard position if too far away
	if behavior_mode == BehaviorMode.GUARD_POSITION:
		var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, guard_position)
		if dist_sq > GUARD_RETURN_THRESHOLD * GUARD_RETURN_THRESHOLD:
			strategic_target_position = guard_position
			_transition_to_marching()
		return

	# If in ADVANCE stance and no target, move toward strategic objective
	if stance == Stance.ADVANCE and not current_target:
		_transition_to_marching()


## MARCHING_TO_TARGET state behavior
func _state_marching(delta: float) -> void:
	# If we have a combat target, engage it
	if current_target and _is_valid_target(current_target):
		_transition_to_engaging()
		return

	# Otherwise, move toward strategic position
	if strategic_target_position != Vector2.ZERO:
		_move_towards(strategic_target_position, delta)


## ENGAGING_TARGET state behavior
func _state_engaging(delta: float) -> void:
	if not current_target or not _is_valid_target(current_target):
		_transition_to_idle()
		return

	var target_pos = _get_target_position(current_target)
	var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, target_pos)

	# Guard position mode: don't chase targets too far from guard position
	if behavior_mode == BehaviorMode.GUARD_POSITION:
		var dist_from_guard_sq = ToroidalWorld.toroidal_distance_squared(global_position, guard_position)
		if dist_from_guard_sq > detection_range * detection_range:
			# Too far from guard position, return
			current_target = null
			_transition_to_idle()
			return

	# If target is in attack range, attack
	if dist_sq <= attack_range * attack_range:
		_attack_target(delta)
	else:
		# Move closer (if not in HOLD_POSITION)
		if stance == Stance.ADVANCE:
			_move_towards(target_pos, delta)


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


## Move toward a position considering toroidal wrapping
func _move_towards(target_pos: Vector2, delta: float) -> void:
	var direction = ToroidalWorld.toroidal_direction(global_position, target_pos)
	velocity = direction * move_speed
	move_and_slide()

	# Wrap position if needed
	global_position = ToroidalWorld.wrap_position(global_position)


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


## Check if unit is dead
func is_dead() -> bool:
	return current_state == State.DEAD


## Die
func _die() -> void:
	current_state = State.DEAD
	# TODO: Play death animation, effects
	queue_free()


## State transitions
func _transition_to_idle() -> void:
	current_state = State.IDLE
	current_target = null


func _transition_to_marching() -> void:
	current_state = State.MARCHING_TO_TARGET
	strategic_target_position = _choose_strategic_target()


func _transition_to_engaging() -> void:
	current_state = State.ENGAGING_TARGET


## Choose strategic target (override in subclasses)
func _choose_strategic_target() -> Vector2:
	# Attack base only mode: always target closest enemy main base
	if behavior_mode == BehaviorMode.ATTACK_BASE_ONLY:
		return _find_closest_enemy_main_base()

	# Guard position mode: guard position is the strategic target
	if behavior_mode == BehaviorMode.GUARD_POSITION:
		return guard_position

	return Vector2.ZERO


## Create health bar above unit
func _create_health_bar() -> void:
	health_bar = ProgressBar.new()
	health_bar.size = Vector2(40, 6)
	health_bar.position = Vector2(-20, -30)
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


## Set unit ownership
func set_owner_info(slot: int, color: String) -> void:
	owner_slot = slot
	team_color = color


## Set stance
func set_stance(new_stance: Stance) -> void:
	stance = new_stance


## Set behavior mode to guard a specific position
func set_guard_position(position: Vector2) -> void:
	behavior_mode = BehaviorMode.GUARD_POSITION
	guard_position = position
	stance = Stance.ADVANCE  # Guards actively engage enemies
	print("%s set to GUARD position at %v" % [unit_name, position])


## Set behavior mode to attack base only
func set_attack_base_only() -> void:
	behavior_mode = BehaviorMode.ATTACK_BASE_ONLY
	stance = Stance.ADVANCE
	print("%s set to ATTACK BASE ONLY mode" % unit_name)


## Set behavior mode to normal
func set_normal_behavior() -> void:
	behavior_mode = BehaviorMode.NORMAL
	guard_position = Vector2.ZERO
	print("%s set to NORMAL behavior" % unit_name)


## Find closest enemy main base position
func _find_closest_enemy_main_base() -> Vector2:
	var enemy_bases = []
	for base in get_tree().get_nodes_in_group("main_bases"):
		if "team_color" in base and base.team_color != team_color:
			enemy_bases.append(base)

	if not enemy_bases.is_empty():
		var closest_base = ToroidalWorld.find_nearest(global_position, enemy_bases)
		if closest_base:
			return closest_base.global_position

	return global_position


## Check if unit should only target main bases (for ATTACK_BASE_ONLY mode)
func _should_only_target_bases() -> bool:
	return behavior_mode == BehaviorMode.ATTACK_BASE_ONLY
