class_name TestBase
extends RefCounted
## Minimal assert helpers shared by all test scripts.

var passed: int = 0
var failed: int = 0
var errors: Array[String] = []


func assert_true(condition: bool, message: String = "") -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		errors.append("FAIL  " + message)


func assert_false(condition: bool, message: String = "") -> void:
	assert_true(not condition, message)


func assert_eq(a: Variant, b: Variant, message: String = "") -> void:
	if a == b:
		passed += 1
	else:
		failed += 1
		errors.append("FAIL  %s — got %s, want %s" % [message, str(a), str(b)])


func run(_parent: Node = null) -> void:
	pass
