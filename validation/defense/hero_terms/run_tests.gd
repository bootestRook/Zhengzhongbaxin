extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	await preload("res://tests/test_defense_hero_terms_ui.gd").new().run(test, self, "--capture" in OS.get_cmdline_user_args())
	if not "--panel-only" in OS.get_cmdline_user_args():
		await preload("res://tests/test_defense_battle_ui.gd").new().run(test, self)
		await preload("res://tests/test_defense_choice_info_ui.gd").new().run(test, self)
		await preload("res://tests/test_defense_result_ui.gd").new().run(test, self)
		await preload("res://tests/test_defense_experience_ui.gd").new().run(test, self)
		await preload("res://tests/test_defense_warrior_ui.gd").new().run(test, self)
	for failure: String in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[HERO TERMS UI] assertions=%d failures=%d" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
