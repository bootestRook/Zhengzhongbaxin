extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	await preload("res://tests/test_defense_home_ui.gd").new().run(test, self)
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[OK] shared shell and dynamic card atlas: %d assertions" % test.assertions if test.failures.is_empty() else "[FAIL] home atlas")
	quit(0 if test.failures.is_empty() else 1)
