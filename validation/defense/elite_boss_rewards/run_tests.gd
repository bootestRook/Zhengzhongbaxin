extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_loot.gd").new().run(test)
	await preload("res://tests/test_defense_chest_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_druid_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_assassin_ui.gd").new().run(test, self)
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[ELITE/BOSS REWARDS] assertions=", test.assertions, " failures=", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
