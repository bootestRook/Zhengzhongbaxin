extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	await preload("res://tests/test_defense_druid_ui.gd").new().run(test, self, true)
	for failure in test.failures:
		push_error(failure)
	print("[DRUID UI] assertions=", test.assertions, " failures=", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
