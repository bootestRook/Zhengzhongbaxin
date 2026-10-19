extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_combat.gd").new().run(test)
	preload("res://tests/test_defense_combat_edges.gd").new().run(test)
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[OK] combat edges: %d assertions, %d failures" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
