extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	for suite in [
		preload("res://tests/test_defense_movement.gd"),
		preload("res://tests/test_defense_ai_boundaries.gd"),
		preload("res://tests/test_defense_blocking_limit.gd"),
		preload("res://tests/test_defense_melee_stability.gd"),
		preload("res://tests/test_defense_guard.gd"),
		preload("res://tests/test_defense_statue.gd")]:
		suite.new().run(test)
	for failure in test.failures:
		push_error(failure)
	print("[MOVEMENT] assertions=%d failures=%d" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
