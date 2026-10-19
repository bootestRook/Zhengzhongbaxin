extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_fire_centers.gd").new().run(test)
	print("[FIRE CENTER TESTS] assertions=", test.assertions, " failures=", test.failures)
	if not test.failures.is_empty():
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--capture"):
		await preload("res://tools/capture_fire_centers.gd").new().run(test, self)
	quit(0 if test.failures.is_empty() else 1)
