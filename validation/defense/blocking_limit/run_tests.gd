extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_blocking_limit.gd").new().run(test)
	for failure: String in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[BLOCK TESTS] assertions=%d failures=%d" % [test.assertions,test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
