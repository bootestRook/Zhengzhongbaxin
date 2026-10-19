extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_skill_activation.gd").new().run(test)
	preload("res://tests/test_defense_projectiles.gd").new().run(test)
	preload("res://tests/test_defense_melee_stability.gd").new().run(test)
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[COMBAT REGRESSION] assertions=", test.assertions, " failures=", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
