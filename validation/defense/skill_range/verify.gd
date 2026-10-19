extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_skill_activation.gd").new().run(test)
	preload("res://tests/test_defense_warrior_terms.gd").new().run(test)
	await preload("res://tests/test_defense_skill_range_ui.gd").new().run(test, self)
	for failure in test.failures:
		push_error(failure)
	print("[OK] skill range UI assertions: ", test.assertions, "; failures: ", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
