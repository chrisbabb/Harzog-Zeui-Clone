extends TestBase
## Verify UnitDatabase exposes all 8 unit types and create_unit sets properties.


func run(_parent: Node = null) -> void:
	assert_eq(UnitDatabase.SCENE_BY_TYPE.size(), 8, "SCENE_BY_TYPE has 8 entries")

	var all_types: Array[int] = [
		Constants.UnitType.SCOUT_BUGGY,
		Constants.UnitType.TANK,
		Constants.UnitType.MISSILE_CRAWLER,
		Constants.UnitType.ARTILLERY,
		Constants.UnitType.ANTI_AIR,
		Constants.UnitType.SUPPLY_TRUCK,
		Constants.UnitType.CAPTURE_DRONE,
		Constants.UnitType.HEAVY_WALKER,
	]

	for unit_type in all_types:
		var scene: PackedScene = UnitDatabase.get_unit_scene(unit_type)
		assert_true(scene != null, "get_unit_scene(%d) is non-null" % unit_type)

		var unit: Node3D = UnitDatabase.create_unit(unit_type, Constants.Team.PLAYER, Vector3.ZERO)
		assert_true(is_instance_valid(unit), "create_unit(%d) returns valid node" % unit_type)
		if is_instance_valid(unit):
			assert_eq(unit.get("unit_type"), unit_type, "unit_type set on unit %d" % unit_type)
			assert_eq(unit.get("team"), Constants.Team.PLAYER, "team set on unit %d" % unit_type)
			unit.free()
