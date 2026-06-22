extends Node
## Autoload singleton tracking the current state of an in-progress match.

var is_paused: bool = false
var is_match_active: bool = false
var player_team: int = Constants.Team.PLAYER

var registered_units: Array[Node] = []
var registered_buildings: Array[Node] = []

var selected_unit: Node = null


func start_match() -> void:
	is_match_active = true
	is_paused = false
	EventBus.match_started.emit()


func end_match(winning_team: int) -> void:
	is_match_active = false
	EventBus.match_ended.emit(winning_team)


func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	if paused:
		EventBus.game_paused.emit()
	else:
		EventBus.game_resumed.emit()


func register_unit(unit: Node) -> void:
	if unit not in registered_units:
		registered_units.append(unit)
		EventBus.unit_spawned.emit(unit)


func unregister_unit(unit: Node) -> void:
	registered_units.erase(unit)
	EventBus.unit_died.emit(unit)


func register_building(building: Node) -> void:
	if building not in registered_buildings:
		registered_buildings.append(building)
		EventBus.building_constructed.emit(building)


func unregister_building(building: Node) -> void:
	registered_buildings.erase(building)
	EventBus.building_destroyed.emit(building)


func set_selected_unit(unit: Node) -> void:
	if selected_unit == unit:
		return
	if selected_unit != null:
		EventBus.unit_deselected.emit(selected_unit)
	selected_unit = unit
	if selected_unit != null:
		EventBus.unit_selected.emit(selected_unit)


func reset() -> void:
	is_paused = false
	is_match_active = false
	registered_units.clear()
	registered_buildings.clear()
	selected_unit = null
