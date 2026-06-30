class_name UnitDatabase
extends RefCounted
## Stateless loader/factory for unit stats defined in data/units.json.
## The file is parsed once and cached for the rest of the process.

const DATA_PATH: String = "res://data/units.json"
const FALLBACK_SCENE: PackedScene = preload("res://scenes/units/Unit.tscn")

const SCENE_BY_TYPE: Dictionary = {
	Constants.UnitType.SCOUT_BUGGY: preload("res://scenes/units/ScoutBuggy.tscn"),
	Constants.UnitType.TANK: preload("res://scenes/units/Tank.tscn"),
	Constants.UnitType.MISSILE_CRAWLER: preload("res://scenes/units/MissileCrawler.tscn"),
	Constants.UnitType.ARTILLERY: preload("res://scenes/units/Artillery.tscn"),
	Constants.UnitType.ANTI_AIR: preload("res://scenes/units/AntiAir.tscn"),
	Constants.UnitType.SUPPLY_TRUCK: preload("res://scenes/units/SupplyTruck.tscn"),
	Constants.UnitType.CAPTURE_DRONE: preload("res://scenes/units/CaptureDrone.tscn"),
	Constants.UnitType.HEAVY_WALKER: preload("res://scenes/units/HeavyWalker.tscn"),
}

static var _data: Dictionary = {}


static func get_unit_scene(unit_type: int) -> PackedScene:
	return SCENE_BY_TYPE.get(unit_type, FALLBACK_SCENE)


## Raw stat dictionary for unit_type (cost, hp, speed, fuel, ammo,
## ground_damage, air_damage, range, fire_rate, armor, capture_power,
## supply_radius, role), or an empty dictionary if unit_type is unknown.
static func get_unit_data(unit_type: int) -> Dictionary:
	_ensure_loaded()
	var key: String = Constants.UnitType.keys()[unit_type]
	return _data.get(key, {})


static func get_cost(unit_type: int) -> float:
	return get_unit_data(unit_type).get("cost", 0.0)


## Outpost capture speed multiplier for this unit type (see
## Constants.DEFAULT_UNIT_CAPTURE_POWER / CaptureZone.gd).
static func get_capture_power(unit_type: int) -> float:
	return get_unit_data(unit_type).get("capture_power", Constants.DEFAULT_UNIT_CAPTURE_POWER)


static func get_unit_name(unit_type: int) -> String:
	return Constants.UnitType.keys()[unit_type].capitalize()


## Instantiates and positions a unit; the caller is responsible for adding
## it to the scene tree, mirroring MapGenerator's create_hq/create_outpost.
static func create_unit(unit_type: int, team: int, position: Vector3) -> Node3D:
	var unit: Node3D = get_unit_scene(unit_type).instantiate() as Node3D
	unit.set("unit_type", unit_type)
	unit.set("team", team)
	unit.position = position
	return unit


static func _ensure_loaded() -> void:
	if not _data.is_empty():
		return

	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("UnitDatabase: failed to open %s" % DATA_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_data = parsed
	else:
		push_error("UnitDatabase: %s did not contain a JSON object" % DATA_PATH)
