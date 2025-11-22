extends StaticBody2D
## MainBase - The primary building for each player
##
## Features:
## - Has health that can be damaged
## - Destroying enemy main base = win condition
## - Cannot be moved or transformed

var max_health: float = 1000.0
var current_health: float = 1000.0
var team_color: String = ""
var owner_slot: int = -1

func _ready() -> void:
	# Get properties from metadata (set during creation)
	if has_meta("max_health"):
		max_health = get_meta("max_health")
	if has_meta("current_health"):
		current_health = get_meta("current_health")
	if has_meta("team_color"):
		team_color = get_meta("team_color")
	if has_meta("owner_slot"):
		owner_slot = get_meta("owner_slot")


## Take damage from attacks
func take_damage(amount: float) -> void:
	current_health -= amount
	_update_health_bar()

	if current_health <= 0:
		_destroy_base()


## Update health bar visual
func _update_health_bar() -> void:
	var health_bar = get_node_or_null("HealthBar")
	if health_bar:
		health_bar.value = current_health


## Base destroyed - trigger win condition
func _destroy_base() -> void:
	print("Main base of player %d destroyed!" % owner_slot)

	# Find game world to trigger win condition
	var game_world = get_tree().root.get_node_or_null("GameWorld")
	if game_world and game_world.has_method("on_base_destroyed"):
		game_world.on_base_destroyed(owner_slot)

	# Destroy this base
	queue_free()


## Check if base is dead
func is_dead() -> bool:
	return current_health <= 0
