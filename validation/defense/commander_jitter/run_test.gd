extends SceneTree

func _initialize() -> void:
	var test = load("res://tests/test_support.gd").new()
	load("res://tests/test_defense_ai_boundaries.gd").new().run(test)
	print("[AI CONTACT] assertions=", test.assertions, " failures=", test.failures.size(), " ", test.failures)
	quit(0 if test.failures.is_empty() else 1)
