extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_ai_boundaries.gd").new().run(test)
	preload("res://tests/test_defense_choice_rules.gd").new().run(test)
	for failure in test.failures:
		push_error(failure)
	print("[RESULT] assertions=%d failures=%d" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
