extends SceneTree

const GraphResourceScript = preload("res://src/runtime/ability/ability_graph_resource.gd")
const NodeRegistryScript = preload("res://src/runtime/ability/ability_node_registry.gd")
const ActionRegistryScript = preload("res://src/runtime/ability/ability_action_registry.gd")
const CompilerScript = preload("res://src/runtime/ability/ability_graph_compiler.gd")
const SubgraphCatalogScript = preload("res://src/runtime/ability/ability_subgraph_catalog.gd")


class PlaceholderResolver extends RefCounted:
	func build_action() -> RefCounted:
		return RefCounted.new()


func _initialize() -> void:
	call_deferred("_compile")


func _compile() -> void:
	var paths: Array[String] = []
	_collect_graphs("res://authoring/combat/ability_graphs", paths)
	paths.sort()
	var action_registry := ActionRegistryScript.new()
	action_registry.register_action("editor.placeholder", PlaceholderResolver.new())
	action_registry.register_action("module.damage.deal", PlaceholderResolver.new())
	action_registry.register_action("module.effect.apply", PlaceholderResolver.new())
	action_registry.register_action("defense.cast", PlaceholderResolver.new())
	var node_registry := NodeRegistryScript.create_default()
	var generated: Dictionary = {"schema_version": 1, "plans": {}}
	var definitions: Dictionary = {}
	for path: String in paths:
		var graph: Resource = ResourceLoader.load(path)
		if not (graph is GraphResourceScript):
			push_error("invalid ability graph resource: %s" % path)
			quit(1)
		if definitions.has(graph.graph_id):
			push_error("duplicate ability graph id: %s" % graph.graph_id)
			quit(1)
		definitions[graph.graph_id] = graph.to_definition()
	var preliminary: Dictionary = {}
	for graph_id: String in definitions:
		var result = CompilerScript.new().compile(definitions[graph_id], node_registry, action_registry)
		if not result.accepted:
			push_error("ability graph compile failed: %s:%s" % [graph_id, result.error_code])
			quit(1)
		preliminary[graph_id] = result.plan
	var catalog := SubgraphCatalogScript.new()
	var graph_ids: Array[String] = []
	graph_ids.assign(definitions.keys())
	graph_ids.sort()
	for graph_id: String in graph_ids:
		var dependencies: Array[String] = []
		for reference: RefCounted in definitions[graph_id].subgraph_refs:
			dependencies.append(reference.graph_id)
		var catalog_error: String = catalog.register(graph_id, preliminary[graph_id], dependencies)
		if not catalog_error.is_empty():
			push_error("ability subgraph catalog failed: %s:%s" % [graph_id, catalog_error])
			quit(1)
	for graph_id: String in graph_ids:
		var result = CompilerScript.new().compile(definitions[graph_id], node_registry, action_registry, catalog)
		if not result.accepted:
			push_error("ability graph compile failed: %s:%s" % [graph_id, result.error_code])
			quit(1)
		generated.plans[graph_id] = result.plan.to_dictionary()
	var output := FileAccess.open("res://data/generated/ability_plans.json", FileAccess.WRITE)
	if output == null:
		push_error("cannot write generated ability plan catalog")
		quit(1)
	output.store_string(JSON.stringify(generated, "\t", true) + "\n")
	print("[OK] ability graph plans: %d" % paths.size())
	quit(0)


func _collect_graphs(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if file_name.ends_with(".tres"):
			output.append("%s/%s" % [directory_path, file_name])
	for child_directory: String in directory.get_directories():
		_collect_graphs("%s/%s" % [directory_path, child_directory], output)
