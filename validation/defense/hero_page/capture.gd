extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.position = Vector2i(-3000, 40)
	var test = preload("res://tests/test_support.gd").new()
	await preload("res://tests/test_defense_home_heroes_ui.gd").new().run(test, self, true)
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[OK] hero page input and capture: %d assertions" % test.assertions if test.failures.is_empty() else "[FAIL] hero page input and capture")
	quit(0 if test.failures.is_empty() else 1)
