extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_guard.gd").new().run(test)
	preload("res://tests/test_defense_ai_boundaries.gd").new().run(test)
	preload("res://tests/test_defense_assassin_terms.gd").new().run(test)
	for failure in test.failures:
		push_error(failure)
	print("front boundary assertions: ", test.assertions, "; failures: ", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
