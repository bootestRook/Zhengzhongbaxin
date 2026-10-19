extends SceneTree

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	var test_root: String = args[0] if not args.is_empty() else "res://tests"
	var test = load(test_root + "/test_support.gd").new()
	load(test_root + "/test_defense_melee_stability.gd").new().run(test)
	print("[MELEE STABILITY] assertions=", test.assertions, " failures=", test.failures.size(), " ", test.failures)
	quit(0 if test.failures.is_empty() else 1)
