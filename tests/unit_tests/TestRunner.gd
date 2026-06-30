extends Node
## Entry point for the headless test suite.
## Run from the project root:
##   godot --headless --path . -s tests/unit_tests/TestRunner.gd
## Exit code 0 = all tests passed; 1 = one or more failures.

const TESTS: Array = [
	preload("res://tests/unit_tests/test_unit_database.gd"),
	preload("res://tests/unit_tests/test_economy.gd"),
	preload("res://tests/unit_tests/test_outpost_capture.gd"),
	preload("res://tests/unit_tests/test_unit_order.gd"),
	preload("res://tests/unit_tests/test_projectile_team.gd"),
	preload("res://tests/unit_tests/test_match_end.gd"),
]


func _ready() -> void:
	var sandbox := Node.new()
	add_child(sandbox)

	var total_passed := 0
	var total_failed := 0

	for test_class in TESTS:
		var test = test_class.new()
		test.run(sandbox)
		for err in test.errors:
			print(err)
		total_passed += test.passed
		total_failed += test.failed
		var label: String = test_class.resource_path.get_file().trim_suffix(".gd")
		var status: String = "PASS" if test.failed == 0 else "FAIL"
		print("[%s] %s  (%d / %d)" % [status, label, test.passed, test.passed + test.failed])

	print("\n=== %d passed, %d failed ===" % [total_passed, total_failed])

	sandbox.free()
	get_tree().quit(0 if total_failed == 0 else 1)
