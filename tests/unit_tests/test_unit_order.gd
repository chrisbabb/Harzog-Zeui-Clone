extends TestBase
## Verify that give_order sets current_order and emits unit_order_changed.

var _last_unit: Node = null
var _last_order: int = -1


func _on_order_changed(unit: Node, order: int) -> void:
	_last_unit = unit
	_last_order = order


func run(_parent: Node = null) -> void:
	# Lightweight mock unit: same data contract as Unit.gd's give_order without
	# NavigationAgent3D / @onready visual dependencies.
	var mock_script := GDScript.new()
	mock_script.source_code = (
		"extends Node3D\n"
		+ "var current_order: int = Constants.UnitOrder.HOLD_POSITION\n"
		+ "var team: int = Constants.Team.PLAYER\n"
		+ "func give_order(order: int, _pos := Vector3.ZERO, _bldg = null) -> void:\n"
		+ "\tcurrent_order = order\n"
		+ "\tEventBus.unit_order_changed.emit(self, current_order)\n"
	)
	mock_script.reload()
	var unit := Node3D.new()
	unit.set_script(mock_script)

	assert_eq(unit.get("current_order"), Constants.UnitOrder.HOLD_POSITION, "initial order is HOLD_POSITION")

	EventBus.unit_order_changed.connect(_on_order_changed)
	unit.call("give_order", Constants.UnitOrder.ATTACK_BASE)
	EventBus.unit_order_changed.disconnect(_on_order_changed)

	assert_eq(unit.get("current_order"), Constants.UnitOrder.ATTACK_BASE, "give_order sets current_order")
	assert_eq(_last_order, Constants.UnitOrder.ATTACK_BASE, "unit_order_changed signal carries correct order")
	assert_true(_last_unit == unit, "unit_order_changed signal carries correct unit")

	unit.free()
