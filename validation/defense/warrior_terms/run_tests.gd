extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_warrior_terms.gd").new().run(test)
	preload("res://tests/test_defense_hero_roster.gd").new().run(test)
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[WARRIOR TESTS] assertions=", test.assertions, " failures=", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
