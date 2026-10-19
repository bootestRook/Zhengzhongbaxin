class_name AbilityFrameworkRegistry
extends RefCounted

const NodeRegistryScript = preload("res://src/runtime/ability/ability_node_registry.gd")
const ActionRegistryScript = preload("res://src/runtime/ability/ability_action_registry.gd")
const ManifestScript = preload("res://src/runtime/ability/ability_extension_manifest.gd")

var node_registry: RefCounted
var action_registry: RefCounted
var _manifests: Dictionary = {}


func _init(
	initial_nodes: RefCounted = null,
	initial_actions: RefCounted = null
) -> void:
	node_registry = initial_nodes if initial_nodes != null else NodeRegistryScript.create_default()
	action_registry = initial_actions if initial_actions != null else ActionRegistryScript.new()


func register_manifest(manifest: RefCounted) -> String:
	if not (manifest is ManifestScript):
		return "invalid_extension_manifest"
	var validation_error: String = manifest.validate()
	if not validation_error.is_empty():
		return validation_error
	if _manifests.has(manifest.extension_id):
		return "duplicate_extension_manifest"
	for descriptor: RefCounted in manifest.descriptors:
		if node_registry.has_descriptor(descriptor.type_id):
			return "duplicate_extension_node_type"
	for action_id: String in manifest.action_resolvers:
		if action_registry.has_action(action_id):
			return "duplicate_extension_action"
	for descriptor: RefCounted in manifest.descriptors:
		var node_error: String = node_registry.register_descriptor(descriptor)
		if not node_error.is_empty():
			return node_error
	for action_id: String in manifest.action_resolvers:
		var action_error: String = action_registry.register_action(action_id, manifest.action_resolvers[action_id])
		if not action_error.is_empty():
			return action_error
	_manifests[manifest.extension_id] = manifest
	return ""


func manifest_ids() -> Array[String]:
	var result: Array[String] = []
	for manifest_id: String in _manifests:
		result.append(manifest_id)
	result.sort()
	return result
