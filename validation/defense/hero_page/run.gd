extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.position = Vector2i(-3000, 40)
	var test = preload("res://tests/test_support.gd").new()
	await preload("res://tests/test_defense_home_heroes_ui.gd").new().run(test, self, true)
	for path: String in ["test_defense_home_ui", "test_defense_run_seed_ui", "test_defense_hero_roster_ui", "test_defense_druid_ui", "test_defense_assassin_ui"]:
		var before: int = test.assertions
		await load("res://tests/" + path + ".gd").new().run(test, self)
		test.assert_true(test.assertions > before, path + " ran assertions")
		print("[SUITE] %s: %d assertions" % [path, test.assertions - before])
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[OK] hero page L2: %d assertions" % test.assertions if test.failures.is_empty() else "[FAIL] hero page L2")
	quit(0 if test.failures.is_empty() else 1)
