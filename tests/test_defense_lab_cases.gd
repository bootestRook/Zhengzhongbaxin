extends RefCounted

func run(test) -> void:
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	test.assert_equal(catalog.load_default(), "", "case catalog loads")
	var files = preload("res://src/platform/lab_files.gd")
	var paths = files.presets()
	test.assert_true(not paths.is_empty(), "full gate includes nonzero laboratory cases")
	for path in paths:
		var value = files.read_json(path)
		test.assert_true(value.has("value"), "built-in laboratory case readable")
		if value.has("value"):
			preload("res://tests/lab_case_support.gd").new().execute(catalog, value.value, test)
