extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_skill_activation.gd").new().run(test)
	preload("res://tests/test_defense_melee_stability.gd").new().run(test)
	print("[OK] regression fixtures assertions: ", test.assertions, "; failures: ", test.failures)
	quit(0 if test.failures.is_empty() else 1)
