extends SceneTree

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	var catalog = DefenseCatalog.new()
	catalog.load_default()
	var w = DefenseSession.new(catalog)
	w.start(3)
	print("[OPENING] " + JSON.stringify(w.offers))
	w.dispose()
	preload("res://tests/test_defense_initial_roster.gd").new().run(test)
	preload("res://tests/test_defense_choice_rules.gd").new().run(test)
	print("[ROSTER CHECK] assertions=%d failures=%s" % [test.assertions, test.failures])
	quit(0 if test.failures.is_empty() else 1)
