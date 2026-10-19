extends SceneTree

func _initialize() -> void:
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	catalog.load_default()
	for seed_value in [3, 17]:
		var w = preload("res://src/features/defense/domain/defense_session.gd").new(catalog)
		w.start(seed_value)
		print("[OPENING] seed=%d ids=%s" % [seed_value, str(w.offers.map(func(item): return item.id))])
		w.dispose()
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_initial_roster.gd").new().run(test)
	preload("res://tests/test_defense_choice_rules.gd").new().run(test)
	preload("res://tests/test_defense_mixed_choices.gd").new().run(test)
	for failure: String in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[ROSTER] assertions=%d failures=%d" % [test.assertions,test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
