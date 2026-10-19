extends RefCounted

const DataRegistryScript = preload("res://src/data/data_registry.gd")
const ResourceCatalogScript = preload("res://src/resources/resource_catalog.gd")


func run(test: TestSupport) -> void:
	var data = DataRegistryScript.new()
	test.assert_equal(data.load_default(), "", "generated data must load")
	test.assert_equal(data.setting("app.target_fps"), 60, "typed integer setting")
	test.assert_equal(data.setting("presentation.ui_scale", 0.0, "mobile"), 1.15, "platform override")
	test.assert_equal(data.tuning_value("sample.interaction_target", "max_value"), 10.0, "tuning lookup")
	var definition := data.definition("sample.interaction_target")
	test.assert_not_empty(definition, "definition lookup")
	definition["definition_type"] = "mutated"
	test.assert_equal(data.definition("sample.interaction_target").definition_type, "counter_target", "definitions are returned as immutable copies")
	test.assert_equal(data.relations_from("sample.interaction_target", "unlocks").size(), 1, "relation lookup")

	var resources = ResourceCatalogScript.new()
	test.assert_equal(resources.load_default(), "", "asset manifest must load")
	test.assert_equal(resources.path("ui.sample_badge"), "res://assets/runtime/ui/sample_badge.svg", "logical resource path")
	test.assert_true(resources.load_resource("ui.sample_badge") is Texture2D, "runtime UI asset must import as Texture2D")
