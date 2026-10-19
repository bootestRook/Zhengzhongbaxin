extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.position = Vector2i(-3000, 40)
	var test := TestSupport.new()
	await preload("res://tests/test_defense_home_hero_details_ui.gd").new().run(test, self, true)
	print("[SUITE] hero details: %d checks, %d failures" % [test.assertions, test.failures.size()])
	await preload("res://tests/test_defense_home_heroes_ui.gd").new().run(test, self)
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("HERO DETAILS CHECKS: %d, FAILURES: %d" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
