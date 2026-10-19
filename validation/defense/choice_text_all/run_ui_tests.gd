extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	await preload("res://tests/test_defense_choice_text_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_mixed_choice_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_hero_roster_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_warrior_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_chest_ui.gd").new().run(test, self)
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[TEXT CARD UI TESTS] assertions=", test.assertions, " failures=", test.failures.size())
	quit(0 if test.failures.is_empty() else 1)
