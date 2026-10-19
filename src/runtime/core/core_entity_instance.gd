class_name CoreEntityInstance
extends RefCounted

const AttributeStoreScript = preload("res://src/runtime/core/core_attribute_store.gd")
const TagStoreScript = preload("res://src/runtime/core/core_tag_store.gd")
const EffectStoreScript = preload("res://src/runtime/core/core_effect_store.gd")
const AbilityGrantStoreScript = preload("res://src/runtime/ability/ability_grant_store.gd")
const AbilityCooldownStoreScript = preload("res://src/runtime/ability/ability_cooldown_store.gd")

var entity_id: String = ""
var sequence: int = 0
var lifecycle: String = "active"
var attributes: RefCounted = AttributeStoreScript.new()
var tags: RefCounted = TagStoreScript.new()
var effects: RefCounted = null
var abilities: RefCounted = AbilityGrantStoreScript.new()
var cooldowns: RefCounted = AbilityCooldownStoreScript.new()


func _init(instance_entity_id: String = "", instance_sequence: int = 0) -> void:
	entity_id = instance_entity_id
	sequence = instance_sequence
	effects = EffectStoreScript.new(tags, attributes)


func snapshot() -> Dictionary:
	return {
		"entity_id": entity_id,
		"sequence": sequence,
		"lifecycle": lifecycle,
		"attributes": attributes.full_snapshot(),
		"tags": tags.snapshot(),
		"effects": effects.full_snapshot(),
		"abilities": abilities.snapshot(),
		"cooldowns": cooldowns.snapshot(),
	}


func restore(snapshot: Dictionary) -> String:
	if String(snapshot.get("entity_id", "")) != entity_id:
		return "entity_snapshot_identity_mismatch"
	lifecycle = String(snapshot.get("lifecycle", lifecycle))
	var restore_steps: Array[Dictionary] = [
		{"store": attributes, "snapshot": snapshot.get("attributes", {})},
		{"store": tags, "snapshot": snapshot.get("tags", {})},
		{"store": effects, "snapshot": snapshot.get("effects", {})},
		{"store": abilities, "snapshot": snapshot.get("abilities", {})},
		{"store": cooldowns, "snapshot": snapshot.get("cooldowns", {})},
	]
	for step: Dictionary in restore_steps:
		var store: RefCounted = step.store
		if not store.has_method("restore"):
			return "entity_store_restore_unsupported"
		var error: String = store.restore(step.snapshot)
		if not error.is_empty():
			return error
	return ""
