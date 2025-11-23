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
var time_since_ownership_check: float = 0.0
const OWNERSHIP_CHECK_INTERVAL: float = 0.1  # Check every 100ms


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
	z_index = 0  # Ground units render below air units


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
	# Always look for mini-bases to capture (not just in ADVANCE stance)
	_look_for_capture_target()


## Look for mini-bases or control points to capture
func _look_for_capture_target() -> void:
	# Find ALL mini-bases that we don't own
	var mini_bases = get_tree().get_nodes_in_group("mini_bases")
	var uncaptured_bases = []

	for base in mini_bases:
		# Check if base is not owned by this player
		var is_owned_by_me = false
		if "owner_slot" in base and "is_neutral" in base:
			if not base.is_neutral and base.owner_slot == owner_slot:
				is_owned_by_me = true

		# Add to targets if we don't own it
		if not is_owned_by_me:
			uncaptured_bases.append(base)

	# Find the closest one (considering toroidal wrapping)
	if not uncaptured_bases.is_empty():
		var closest_base = null
		var closest_dist_sq = INF

		for base in uncaptured_bases:
			var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, base.global_position)
			if dist_sq < closest_dist_sq:
				closest_dist_sq = dist_sq
				closest_base = base

		# Set as capture target and start moving
		if closest_base:
			current_capture_target = closest_base
			if current_state == State.IDLE:
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

	# Update ownership check timer
	time_since_ownership_check += delta
	if time_since_ownership_check >= OWNERSHIP_CHECK_INTERVAL:
		time_since_ownership_check = 0.0
		_check_capture_target_ownership()

	# Always look for targets if we don't have one
	if not current_capture_target or not is_instance_valid(current_capture_target):
		_look_for_capture_target()

	# Check if near capture target
	if current_capture_target and is_instance_valid(current_capture_target):
		var dist_sq = ToroidalWorld.toroidal_distance_squared(global_position, current_capture_target.global_position)
		# Don't do anything special - the mini base area detection will handle capture
		# Just make sure we keep moving toward it if not there yet
		if dist_sq > 100.0 * 100.0:  # Not inside capture zone yet
			# Move toward capture target using base class logic
			if current_state == State.IDLE or current_state == State.MARCHING_TO_TARGET:
				current_state = State.MARCHING_TO_TARGET


## Check if current capture target is already owned by us
func _check_capture_target_ownership() -> void:
	if not current_capture_target or not is_instance_valid(current_capture_target):
		return

	# Check if the target is now owned by us
	if "owner_slot" in current_capture_target and "is_neutral" in current_capture_target:
		var is_owned_by_me = not current_capture_target.is_neutral and current_capture_target.owner_slot == owner_slot

		# If we already own it, pick a different target
		if is_owned_by_me:
			current_capture_target = null
			_look_for_capture_target()


## Attempt to capture a mini-base
func _attempt_capture(delta: float) -> void:
	if current_capture_target and current_capture_target.has_method("capture"):
		current_capture_target.capture(owner_slot, team_color, capture_rate * delta)


## Check if entity is an enemy
func _is_enemy(entity) -> bool:
	if not "team_color" in entity:
		return false

	return entity.team_color != team_color
