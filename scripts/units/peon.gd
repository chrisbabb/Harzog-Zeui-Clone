extends UnitBase
class_name Peon
## Peon - Non-combat utility unit
##
## Can attack: NONE
## Cannot attack: ALL (completely non-combat)
## Purpose: Capture mini-bases, economic/utility roles

@export var capture_range: float = 50.0
@export var capture_rate: float = 1.0  # Points per second

var current_capture_target = null


func _ready() -> void:
	super._ready()
	unit_name = "Peon"
	unit_type = "peon"
	max_health = 50.0
	current_health = max_health
	move_speed = 80.0
	attack_range = 0.0  # Cannot attack
	attack_damage = 0.0
	attack_cooldown = 0.0
	detection_range = 200.0


## Peons NEVER attack anything
func _find_best_target_in_range():
	# Peons don't engage in combat
	return null


## Override attack behavior - peons never attack
func _perform_attack() -> void:
	# Peons cannot attack
	pass


## Override state behavior for peon-specific logic
func _state_idle(_delta: float) -> void:
	# If in ADVANCE stance, look for mini-bases to capture or return to main base
	if stance == Stance.ADVANCE:
		_look_for_capture_target()


## Look for mini-bases or control points to capture
func _look_for_capture_target() -> void:
	# Find nearest uncaptured or enemy mini-base
	var mini_bases = get_tree().get_nodes_in_group("mini_bases")
	var valid_targets = []

	for base in mini_bases:
		if _is_enemy(base) or not base.has_meta("owner_slot"):
			var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, base.global_position)
			if dist_sq <= detection_range * detection_range:
				valid_targets.append(base)

	if not valid_targets.is_empty():
		current_capture_target = ToroidalWorld.find_nearest(global_position, valid_targets)
		if current_capture_target:
			_transition_to_marching()


## Choose strategic target - move to mini-base or main base
func _choose_strategic_target() -> Vector2:
	# If we have a capture target, move to it
	if current_capture_target and is_instance_valid(current_capture_target):
		return current_capture_target.global_position

	# Otherwise, return to friendly main base
	var friendly_bases = []
	for base in get_tree().get_nodes_in_group("main_bases"):
		if not _is_enemy(base):
			friendly_bases.append(base)

	if not friendly_bases.is_empty():
		var nearest_base = ToroidalWorld.find_nearest(global_position, friendly_bases)
		if nearest_base:
			return nearest_base.global_position

	return global_position


## Override process to handle capturing
func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Check if near capture target
	if current_capture_target and is_instance_valid(current_capture_target):
		var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, current_capture_target.global_position)
		if dist_sq <= capture_range * capture_range:
			_attempt_capture(delta)
		else:
			# Move toward capture target
			if stance == Stance.ADVANCE:
				_move_towards(current_capture_target.global_position, delta)


## Attempt to capture a mini-base
func _attempt_capture(delta: float) -> void:
	if current_capture_target and current_capture_target.has_method("capture"):
		current_capture_target.capture(owner_slot, team_color, capture_rate * delta)


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not entity.has_meta("team_color"):
		return false

	return entity.get_meta("team_color") != team_color
