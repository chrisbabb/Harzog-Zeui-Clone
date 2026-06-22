extends Node
## Autoload singleton managing per-team resources and income ticks.

var _team_resources: Dictionary = {}
var _tick_accumulator: float = 0.0


func _ready() -> void:
	_team_resources[Constants.Team.PLAYER] = Constants.STARTING_RESOURCES
	_team_resources[Constants.Team.ENEMY] = Constants.STARTING_RESOURCES


func _process(delta: float) -> void:
	if GameState.is_paused or not GameState.is_match_active:
		return
	_tick_accumulator += delta
	if _tick_accumulator >= Constants.RESOURCE_TICK_INTERVAL:
		_tick_accumulator = 0.0
		for team in _team_resources.keys():
			add_resources(team, Constants.RESOURCE_TICK_AMOUNT)


func get_resources(team: int) -> int:
	return _team_resources.get(team, 0)


func add_resources(team: int, amount: int) -> void:
	_team_resources[team] = get_resources(team) + amount
	EventBus.resources_changed.emit(team, _team_resources[team])


func can_afford(team: int, cost: int) -> bool:
	return get_resources(team) >= cost


func spend_resources(team: int, cost: int) -> bool:
	if not can_afford(team, cost):
		return false
	_team_resources[team] = get_resources(team) - cost
	EventBus.resources_changed.emit(team, _team_resources[team])
	return true


func reset() -> void:
	_tick_accumulator = 0.0
	_team_resources[Constants.Team.PLAYER] = Constants.STARTING_RESOURCES
	_team_resources[Constants.Team.ENEMY] = Constants.STARTING_RESOURCES
