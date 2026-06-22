extends StaticBody3D
## Placeholder script for a team's main base.
## Losing a main base is intended to end the match for that team.

@export var max_health: float = Constants.BASE_STARTING_HEALTH
@export var team: int = Constants.Team.PLAYER

var current_health: float


func _ready() -> void:
	current_health = max_health
	GameState.register_building(self)


func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0:
		destroy()


func destroy() -> void:
	GameState.unregister_building(self)
	var winning_team: int = Constants.Team.ENEMY if team == Constants.Team.PLAYER else Constants.Team.PLAYER
	GameState.end_match(winning_team)
	queue_free()
