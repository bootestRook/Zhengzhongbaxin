extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_assassin_terms.gd").new().run(test)
	preload("res://tests/test_defense_assassin_final_multiplier.gd").new().run(test)
	for failure in test.failures:
		push_error(failure)
	print("[ASSASSIN FINAL MULTIPLIER] assertions=", test.assertions, " failures=", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
