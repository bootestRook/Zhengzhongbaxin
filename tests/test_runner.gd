extends SceneTree

const TestSupportScript = preload("res://tests/test_support.gd")
const GraphResourceScript = preload("res://src/runtime/ability/ability_graph_resource.gd")
const NodeResourceScript = preload("res://src/runtime/ability/ability_graph_node_resource.gd")
const ConnectionResourceScript = preload(
	"res://src/runtime/ability/ability_graph_connection_resource.gd"
)
const NodeRegistryScript = preload("res://src/runtime/ability/ability_node_registry.gd")
const Suites := [
	preload("res://tests/test_rng.gd"),
	preload("res://tests/test_data_and_assets.gd"),
	preload("res://tests/test_action_and_feature.gd"),
	preload("res://tests/test_ability_graph.gd"),
	preload("res://tests/test_core_framework.gd"),
	preload("res://tests/test_save.gd"),
	preload("res://tests/test_defense.gd"),
	preload("res://tests/test_defense_gems.gd"),
	preload("res://tests/test_defense_level_balance.gd"),
	preload("res://tests/test_defense_table_multipliers.gd"),
	preload("res://tests/test_defense_initial_roster.gd"),
	preload("res://tests/test_defense_hero_roster.gd"),
	preload("res://tests/test_defense_skill_activation.gd"),
	preload("res://tests/test_defense_warrior_terms.gd"),
	preload("res://tests/test_defense_taunt_visuals.gd"),
	preload("res://tests/test_defense_fire_terms.gd"),
	preload("res://tests/test_defense_fire_centers.gd"),
	preload("res://tests/test_defense_druid_terms.gd"),
	preload("res://tests/test_defense_ice_terms.gd"),
	preload("res://tests/test_defense_projectiles.gd"),
	preload("res://tests/test_defense_assassin_terms.gd"),
	preload("res://tests/test_defense_assassin_final_multiplier.gd"),
	preload("res://tests/test_defense_loot.gd"),
	preload("res://tests/test_defense_encounters.gd"),
	preload("res://tests/test_defense_choice_rules.gd"),
	preload("res://tests/test_defense_mixed_choices.gd"),
	preload("res://tests/test_defense_experience.gd"),
	preload("res://tests/test_defense_combat.gd"),
	preload("res://tests/test_defense_combat_edges.gd"),
	preload("res://tests/test_defense_movement.gd"),
	preload("res://tests/test_defense_ai_boundaries.gd"),
	preload("res://tests/test_defense_guard.gd"),
	preload("res://tests/test_defense_ranged_range.gd"),
	preload("res://tests/test_defense_melee_stability.gd"),
	preload("res://tests/test_defense_blocking_limit.gd"),
	preload("res://tests/test_defense_statue.gd"),
	preload("res://tests/test_defense_initial_effects.gd"),
	preload("res://tests/test_defense_hero_skill_contracts.gd"),
	preload("res://tests/test_defense_hero_passive_contracts.gd"),
	preload("res://tests/test_defense_lab.gd"),
	preload("res://tests/test_defense_lab_cases.gd"),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var test = TestSupportScript.new()
	for suite_script in Suites:
		suite_script.new().run(test)
	await _run_scene_smoke(test)
	await preload("res://tests/test_defense_home_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_home_heroes_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_home_hero_details_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_run_seed_ui.gd").new().run(test, self)
	preload("res://tests/test_defense_atlas_bindings.gd").new().run(test, self)
	await preload("res://tests/test_defense_choice_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_choice_text_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_choice_info_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_mixed_choice_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_battle_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_hero_terms_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_skill_range_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_hero_roster_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_warrior_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_fire_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_druid_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_ice_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_assassin_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_experience_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_result_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_chest_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_encounter_ui.gd").new().run(test, self)
	await preload("res://tests/test_defense_lab_ui.gd").new().run(test, self, false)
	if test.failures.is_empty():
		print("[OK] Godot tests: %d assertions" % test.assertions)
		quit(0)
		return
	for failure: String in test.failures:
		push_error("TEST FAILURE: %s" % failure)
	print("[FAIL] Godot tests: %d failure(s), %d assertions" % [test.failures.size(), test.assertions])
	quit(1)


func _run_scene_smoke(test: TestSupport) -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	test.assert_true(packed != null, "main scene must load")
	if packed == null:
		return
	var app = packed.instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	test.assert_true(app.is_ready_for_use(), "composition root must boot")
	var before: Dictionary = app.battle_snapshot()
	test.assert_equal(before.phase, "home", "game opens on level selection")
	var home = app.get_node("DefenseView/Home")
	for level in app._catalog.level_ids():
		app.submit("select_level", {"level": level})
		var row: Dictionary = app._catalog.record("levels", level)
		var bosses: Array = row.encounters.filter(func(entry): return entry.kind == "boss")
		if not bosses.is_empty():
			var final = bosses.back()
			test.assert_equal(home.final_boss.res, app._catalog.record("monsters", int(final.id)).res,
				"home shows the configured boss of level %d" % level)
	app.submit("select_level", {"level": 1})
	home.get_node("BattlePage/Start").pressed.emit()
	await process_frame
	var after: Dictionary = app.battle_snapshot()
	test.assert_equal(after.phase, "choice", "start button opens hero choice")
	app.get_node("DefenseView").intent_requested.emit("choose", {"index": 0})
	await process_frame
	test.assert_equal(app.battle_snapshot().heroes.size(), 1, "choice intent creates real hero")
	app.get_node("DefenseView").intent_requested.emit("quit", {})
	app.get_node("DefenseView").intent_requested.emit("home", {})
	test.assert_equal(app.battle_snapshot().phase, "home", "result can return to level selection")
	app.queue_free()
	await process_frame
	await _run_editor_graph_smoke(test)


func _run_editor_graph_smoke(test: TestSupport) -> void:
	var graph := GraphResourceScript.new()
	graph.graph_id = "smoke.editor_graph"
	var entry := NodeResourceScript.new()
	entry.node_id = "entry"
	entry.type_id = NodeRegistryScript.ON_CAST_TYPE
	var action := NodeResourceScript.new()
	action.node_id = "action"
	action.type_id = NodeRegistryScript.EXECUTE_ACTION_TYPE
	action.parameters = {"action_id": "editor.placeholder"}
	var end := NodeResourceScript.new()
	end.node_id = "end"
	end.type_id = NodeRegistryScript.END_TYPE
	graph.add_node_resource(entry, Vector2(40, 80))
	graph.add_node_resource(action, Vector2(280, 80))
	graph.add_node_resource(end, Vector2(520, 80))
	var first_connection := ConnectionResourceScript.new()
	first_connection.from_node_id = "entry"
	first_connection.from_pin_id = "then"
	first_connection.to_node_id = "action"
	first_connection.to_pin_id = "in"
	graph.add_connection_resource(first_connection)
	var second_connection := ConnectionResourceScript.new()
	second_connection.from_node_id = "action"
	second_connection.from_pin_id = "then"
	second_connection.to_node_id = "end"
	second_connection.to_pin_id = "in"
	graph.add_connection_resource(second_connection)
	var editor_scene: PackedScene = ResourceLoader.load(
		"res://addons/combat_framework_editor/editor/ability_graph_editor.tscn",
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	var editor: Control = editor_scene.instantiate()
	root.add_child(editor)
	editor.initialize(null)
	editor.set_graph_resource(graph)
	await process_frame
	var graph_edit: GraphEdit = editor.get_node("Root/Body/GraphEdit")
	var dynamic_node_count := 0
	for child: Node in graph_edit.get_children():
		if child is GraphNode:
			dynamic_node_count += 1
	test.assert_equal(dynamic_node_count, 3, "editor canvas must project Resource nodes into GraphNode views")
	var candidates: Array = editor.call("_candidate_descriptors")
	test.assert_true(candidates.size() > 0, "editor must expose a non-empty node candidate menu")
	test.assert_true(editor.get_node("CandidateMenu") is PopupMenu, "editor must mount the context candidate menu")
	editor.call("_compile")
	var diagnostics: ItemList = editor.get_node("Root/Body/InspectorPanel/Diagnostics")
	test.assert_true(diagnostics.item_count > 0, "editor compile command must surface diagnostics")
	editor.call("apply_debug_snapshot", {"run_id": "smoke", "state": "running", "current_node_id": "action", "trace": [{"sequence": 1, "kind": "edge", "data": {"from_node_id": "entry", "to_node_id": "action", "output_pin": "then"}}], "event_trace": [{"event_type": "damage.applied", "logical_tick": 2, "error_code": ""}]})
	var trace_list: ItemList = editor.get_node("Root/Body/InspectorPanel/Trace")
	test.assert_equal(trace_list.item_count, 1, "editor must render the ability execution trace")
	var event_trace_list: ItemList = editor.get_node("Root/Body/InspectorPanel/EventTrace")
	test.assert_equal(event_trace_list.item_count, 1, "editor must render the core event trace")
	editor.call("_on_trace_selected", 0)
	test.assert_equal(editor.get("_debug_node_id"), "action", "trace selection must jump back to its graph node")
	editor.free()
	editor_scene = null
