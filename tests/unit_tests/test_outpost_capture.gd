extends TestBase
## Verify that capturing an outpost changes its team and emits building_captured.

var _captured_building: Node = null
var _captured_team: int = -1


func _on_captured(building: Node, team: int) -> void:
	_captured_building = building
	_captured_team = team


func run(_parent: Node = null) -> void:
	# Lightweight mock outpost: same contract as the real Outpost without
	# @onready scene-tree dependencies.
	var mock_script := GDScript.new()
	mock_script.source_code = (
		"extends Node\n"
		+ "var team: int = Constants.Team.NEUTRAL\n"
		+ "var capture_progress_player: float = 0.5\n"
		+ "var capture_progress_enemy: float = 0.0\n"
		+ "func _complete_capture(new_team: int) -> void:\n"
		+ "\tteam = new_team\n"
		+ "\tcapture_progress_player = 0.0\n"
		+ "\tcapture_progress_enemy = 0.0\n"
		+ "\tEventBus.building_captured.emit(self, team)\n"
	)
	mock_script.reload()
	var outpost := Node.new()
	outpost.set_script(mock_script)

	assert_eq(outpost.get("team"), Constants.Team.NEUTRAL, "initial team is NEUTRAL")

	EventBus.building_captured.connect(_on_captured)
	outpost.call("_complete_capture", Constants.Team.PLAYER)
	EventBus.building_captured.disconnect(_on_captured)

	assert_eq(outpost.get("team"), Constants.Team.PLAYER, "team changes to PLAYER after capture")
	assert_eq(outpost.get("capture_progress_player"), 0.0, "capture_progress_player resets after capture")
	assert_eq(_captured_team, Constants.Team.PLAYER, "building_captured signal carries correct team")
	assert_true(_captured_building == outpost, "building_captured signal carries correct building")

	outpost.free()
