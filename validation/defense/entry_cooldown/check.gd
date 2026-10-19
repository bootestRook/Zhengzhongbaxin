extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	catalog.load_default()
	preload("res://tests/test_defense_experience.gd").new()._entry_cooldown(test, catalog)
	for failure in test.failures:
		printerr("TEST FAILURE: " + failure)
	print("[ENTRY COOLDOWN] %d assertions, %d failures" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
