extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	await preload("res://tests/test_defense_ice_ui.gd").new().run(test, self)
	for failure in test.failures:
		printerr("TEST FAILURE: " + failure)
	print("[ICE UI] %d assertions, %d failures" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
