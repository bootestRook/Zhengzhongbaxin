class_name AbilityExtensionManifest
extends RefCounted

var extension_id: String = ""
var version: int = 1
var descriptors: Array[RefCounted] = []
var action_resolvers: Dictionary = {}


func _init(
	manifest_id: String = "",
	manifest_version: int = 1,
	manifest_descriptors: Array[RefCounted] = [],
	manifest_actions: Dictionary = {}
) -> void:
	extension_id = manifest_id
	version = manifest_version
	descriptors = manifest_descriptors.duplicate()
	action_resolvers = manifest_actions.duplicate()


func validate() -> String:
	if extension_id.is_empty() or version <= 0:
		return "extension_manifest_identity_invalid"
	var descriptor_ids: Dictionary = {}
	for descriptor: RefCounted in descriptors:
		if descriptor == null or not descriptor.has_method("validate_node"):
			return "extension_descriptor_invalid"
		if descriptor_ids.has(descriptor.type_id):
			return "extension_duplicate_node_type"
		descriptor_ids[descriptor.type_id] = true
	for action_id: String in action_resolvers:
		if action_id.is_empty() or action_resolvers[action_id] == null:
			return "extension_action_invalid"
	return ""
