extends StaticBody3D
## Placeholder script for a capturable forward outpost.
## Outposts can change ownership but do not end the match when destroyed.

@export var max_health: float = Constants.OUTPOST_MAX_HP
@export var team: int = Constants.Team.NEUTRAL

var current_health: float


func _ready() -> void:
	current_health = max_health
	GameState.register_outpost(self)


func capture(new_team: int) -> void:
	if new_team == team:
		return
	team = new_team
	current_health = max_health
	EventBus.building_captured.emit(self, team)


func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0:
		destroy()


func destroy() -> void:
	GameState.outposts.erase(self)
	queue_free()
