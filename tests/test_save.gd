extends RefCounted

const SaveCodecScript = preload("res://src/foundation/save_codec.gd")
const SaveStoreScript = preload("res://src/platform/save_store.gd")

const TEST_PATH := "user://universal_framework_test_save.json"


func run(test: TestSupport) -> void:
	var codec = SaveCodecScript.new()
	var payload: Dictionary = codec.encode({"sample": {"value": 4}}, {"base_seed": 7, "streams": {}}, 1)
	var decoded: Dictionary = codec.decode(payload)
	test.assert_true(decoded.ok, "current save must decode")
	test.assert_equal(decoded.data.features.sample.value, 4, "feature state must survive codec")

	var legacy := {
		"schema_version": 1,
		"feature_state": {"value": 2},
		"rng": {"base_seed": 7, "streams": {}},
	}
	var migrated: Dictionary = codec.decode(legacy)
	test.assert_true(migrated.ok, "legacy save must migrate")
	test.assert_equal(migrated.data.schema_version, 2, "migration must reach current schema")
	test.assert_equal(migrated.data.features.sample.value, 2, "migration must preserve feature state")
	test.assert_true(not codec.decode({"schema_version": 99}).ok, "future save must be rejected")

	var store = SaveStoreScript.new()
	test.assert_equal(store.write_atomic(TEST_PATH, payload), "", "atomic save write")
	var loaded: Dictionary = store.read(TEST_PATH)
	test.assert_true(loaded.ok, "saved payload must read")
	test.assert_equal(int(loaded.data.schema_version), 2, "stored schema version")
	var absolute_path := ProjectSettings.globalize_path(TEST_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	if FileAccess.file_exists(absolute_path + ".bak"):
		DirAccess.remove_absolute(absolute_path + ".bak")
