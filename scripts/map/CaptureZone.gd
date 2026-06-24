extends Area3D
## Detects commanders and units standing inside a building's capture radius.
## Tracks raw occupancy via body_entered/body_exited, but always re-evaluates
## qualification (order/mode) live, since a body can change orders or
## transform mode while still standing inside the zone.

const COMMANDER_CAPTURE_RATE: float = 0.6
const CAPTURE_DRONE_CAPTURE_RATE: float = 2.0
const UNIT_CAPTURE_RATE: float = 1.0

var _occupants: Array[Node] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Returns the single team currently capturing, or -1 if nobody qualifies
## or the zone is contested by multiple teams.
func get_capturing_team() -> int:
	var teams: Array[int] = _qualifying_teams()
	return teams[0] if teams.size() == 1 else -1


func is_contested() -> bool:
	return _qualifying_teams().size() >= 2


## Best (fastest) capture rate among for_team's qualifying occupants, or 0.0
## if for_team has none currently qualifying.
func get_capture_rate(for_team: int) -> float:
	var best_rate: float = 0.0
	for body in _occupants:
		if not is_instance_valid(body) or body.get("team") != for_team:
			continue
		if not _is_qualifying(body):
			continue
		best_rate = max(best_rate, _rate_for_body(body))
	return best_rate


func _qualifying_teams() -> Array[int]:
	var teams: Array[int] = []
	for body in _occupants:
		if not is_instance_valid(body) or not _is_qualifying(body):
			continue
		var team: int = body.get("team")
		if team not in teams:
			teams.append(team)
	return teams


func _is_qualifying(body: Node) -> bool:
	if body == GameState.player_commander or body == GameState.enemy_commander:
		return body.get("mode") == Constants.CommanderMode.GROUND
	if body.is_in_group("units"):
		return body.get("current_order") == Constants.UnitOrder.CAPTURE_OUTPOST
	return false


func _rate_for_body(body: Node) -> float:
	if body == GameState.player_commander or body == GameState.enemy_commander:
		return COMMANDER_CAPTURE_RATE
	if body.get("unit_type") == Constants.UnitType.CAPTURE_DRONE:
		return CAPTURE_DRONE_CAPTURE_RATE
	return UNIT_CAPTURE_RATE


func _on_body_entered(body: Node) -> void:
	if body not in _occupants:
		_occupants.append(body)


func _on_body_exited(body: Node) -> void:
	_occupants.erase(body)
