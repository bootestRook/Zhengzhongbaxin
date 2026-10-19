extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var test = preload("res://tests/test_support.gd").new()
	await preload("res://tests/test_defense_encounter_ui.gd").new().run(test, self, true)
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[ENCOUNTER CAPTURE] assertions=", test.assertions, " failures=", test.failures.size(), "; pause, three rewards and victory at 3 sizes")
	quit(0 if test.failures.is_empty() else 1)
