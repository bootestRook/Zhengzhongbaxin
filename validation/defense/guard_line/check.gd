extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_guard.gd").new().run(test)
	preload("res://tests/test_defense_ai_boundaries.gd").new().run(test)
	preload("res://tests/test_defense_skill_activation.gd").new().run(test)
	preload("res://tests/test_defense_projectiles.gd").new().run(test)
	preload("res://tests/test_defense_melee_stability.gd").new().run(test)
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	var load_error = catalog.load_default()
	if not load_error.is_empty():
		printerr(load_error)
		quit(1)
		return
	preload("res://tests/test_defense_experience.gd").new()._entry_cooldown(test, catalog)
	for failure in test.failures:
		printerr("TEST FAILURE: " + failure)
	print("[GUARD CHECK] %d assertions, %d failures" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
