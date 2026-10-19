extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Support = preload("res://tests/test_support.gd")
const Files = preload("res://src/platform/lab_files.gd")
var args: PackedStringArray

func _initialize() -> void:
	args = OS.get_cmdline_user_args()
	call_deferred("run")

func argument(name: String, default: String = "") -> String:
	var index = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else default

func run() -> void:
	var test = Support.new()
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "runtime catalog loads")
	var began = Time.get_ticks_msec()
	var suite = argument("--suite", "controls")
	var report = {"suite": suite, "cases": []}
	match suite:
		"controls": preload("res://tests/test_defense_lab.gd").new().run(test)
		"heroes":
			for path in ["warrior_terms", "fire_terms", "druid_terms", "ice_terms", "assassin_terms", "assassin_final_multiplier", "skill_activation", "projectiles"]:
				load("res://tests/test_defense_%s.gd" % path).new().run(test)
		"cases", "case":
			var paths: Array = [argument("--input")] if suite == "case" else Files.presets()
			test.assert_true(not paths.is_empty(), "nonzero case selection")
			for path in paths:
				var data = Files.read_json(path)
				test.assert_true(data.has("value"), "case file is readable: " + path)
				if data.has("value"):
					report.cases.append(preload("res://tests/lab_case_support.gd").new().execute(catalog, data.value, test))
		"ui": await load("res://tests/test_defense_lab_ui.gd").new().run(test, self, args.has("--capture"))
		"coverage": report["coverage"] = load("res://tests/test_defense_lab_coverage.gd").new().run(test, catalog)
		"profile": report["profile"] = load("res://tests/profile_defense_lab.gd").new().run(test, catalog)
		_: test.assert_true(false, "unknown suite: " + suite)
	for failure in test.failures: push_error("TEST FAILURE: " + failure)
	report["assertions"] = test.assertions
	report["failures"] = test.failures
	report["duration_ms"] = Time.get_ticks_msec() - began
	report["source_hashes"] = catalog._data.source_hashes
	report["runtime_fingerprint"] = Files.fingerprint()
	var output = argument("--output")
	if not output.is_empty():
		var error = Files.write_json(output, report)
		if not error.is_empty(): test.assert_true(false, error); push_error(error)
	print("[LAB] suite=%s assertions=%d failures=%d duration_ms=%d" % [suite, test.assertions, test.failures.size(), report.duration_ms])
	quit(0 if test.failures.is_empty() else 1)
