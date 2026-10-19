class_name AbilityNodeDescriptor
extends RefCounted

const ActionNodeConfigurationScript = preload(
	"res://src/runtime/ability/ability_action_node_configuration.gd"
)
const PlanOperationScript = preload(
	"res://src/runtime/ability/ability_plan_operation.gd"
)
const PinDescriptorScript = preload(
	"res://src/runtime/ability/ability_pin_descriptor.gd"
)
const NodeConfigurationScript = preload(
	"res://src/runtime/ability/ability_node_configuration.gd"
)

var type_id: String
var operation_kind: String
var input_pins: Array[String]
var output_pins: Array[String]
var is_entry: bool
var is_terminal: bool
var category: String
var display_name: String
var keywords: Array[String]
var description: String
var entry_event_type_id: String = ""
var input_pin_descriptors: Dictionary = {}
var output_pin_descriptors: Dictionary = {}


func _init(
	descriptor_type_id: String = "",
	descriptor_operation_kind: String = "",
	descriptor_input_pins: Array[String] = [],
	descriptor_output_pins: Array[String] = [],
	descriptor_is_entry: bool = false,
	descriptor_is_terminal: bool = false,
	descriptor_category: String = "Logic",
	descriptor_display_name: String = "",
	descriptor_keywords: Array[String] = [],
	descriptor_description: String = "",
	descriptor_input_schema: Array[RefCounted] = [],
	descriptor_output_schema: Array[RefCounted] = [],
	descriptor_entry_event_type: String = ""
) -> void:
	type_id = descriptor_type_id
	operation_kind = descriptor_operation_kind
	input_pins = descriptor_input_pins.duplicate()
	output_pins = descriptor_output_pins.duplicate()
	is_entry = descriptor_is_entry
	is_terminal = descriptor_is_terminal
	category = descriptor_category
	display_name = descriptor_display_name if not descriptor_display_name.is_empty() else descriptor_type_id
	keywords = descriptor_keywords.duplicate()
	description = descriptor_description
	entry_event_type_id = descriptor_entry_event_type
	for pin: RefCounted in descriptor_input_schema:
		if pin is PinDescriptorScript:
			input_pin_descriptors[pin.pin_id] = pin
	for pin: RefCounted in descriptor_output_schema:
		if pin is PinDescriptorScript:
			output_pin_descriptors[pin.pin_id] = pin
	for pin_id: String in input_pins:
		if not input_pin_descriptors.has(pin_id):
			input_pin_descriptors[pin_id] = PinDescriptorScript.control(pin_id)
	for pin_id: String in output_pins:
		if not output_pin_descriptors.has(pin_id):
			output_pin_descriptors[pin_id] = PinDescriptorScript.control(pin_id)


func has_input_pin(pin_id: String) -> bool:
	return input_pins.has(pin_id)


func has_output_pin(pin_id: String) -> bool:
	return output_pins.has(pin_id)


func input_pin(pin_id: String) -> RefCounted:
	return input_pin_descriptors.get(pin_id)


func output_pin(pin_id: String) -> RefCounted:
	return output_pin_descriptors.get(pin_id)


func validate_node(node: RefCounted, action_registry: RefCounted) -> String:
	if operation_kind == "action":
		if not (node.configuration is ActionNodeConfigurationScript):
			return "invalid_action_node_configuration"
		if node.configuration.action_id.is_empty():
			return "action_id_empty"
		if not action_registry.has_action(node.configuration.action_id):
			return "unknown_action"
		return ""
	if node.configuration != null and not (node.configuration is NodeConfigurationScript):
		return "unexpected_node_configuration"
	return ""


func build_operation(node: RefCounted) -> RefCounted:
	var configured_action_id := ""
	if operation_kind == "action":
		configured_action_id = node.configuration.action_id
	var output_pin := output_pins[0] if not output_pins.is_empty() else ""
	var operation_parameters: Dictionary = node.configuration.parameters.duplicate(true) if node.configuration != null else {}
	if is_entry:
		operation_parameters["event_type"] = entry_event_type(node)
	return PlanOperationScript.new(
		node.node_id,
		operation_kind,
		configured_action_id,
		output_pin,
		operation_parameters
	)


func entry_event_type(node: RefCounted) -> String:
	if not is_entry:
		return ""
	if node.configuration != null and not String(node.configuration.parameters.get("event_type", "")).is_empty():
		return String(node.configuration.parameters.event_type)
	return entry_event_type_id


func parameter_fields() -> Array[Dictionary]:
	if type_id.begins_with("combat.ability.event."):
		return [{"field_id": "event_type", "label": "Event Type", "type": "string"}, {"field_id": "scope", "label": "Scope", "type": "enum", "enum_values": ["source", "target", "any"]}]
	match type_id:
		"combat.ability.action.execute":
			return [{"field_id": "action_id", "label": "Action ID", "type": "string"}]
		"combat.ability.action.deal_damage":
			return [
				{"field_id": "amount", "label": "Amount", "type": "number", "min": 0.0, "max": 100000.0, "step": 0.1},
				{"field_id": "damage_type_id", "label": "Damage Type", "type": "definition_ref", "definition_kind": "damage_type"},
				{"field_id": "attribute_id", "label": "Attribute", "type": "definition_ref", "definition_kind": "attribute"},
			]
		"combat.ability.action.apply_effect":
			return [{"field_id": "effect_id", "label": "Effect ID", "type": "definition_ref", "definition_kind": "effect"}]
		"combat.ability.action.spawn_projectile":
			return [{"field_id": "definition_id", "label": "Projectile Definition", "type": "definition_ref", "definition_kind": "projectile"}]
		"combat.ability.target.select":
			return [
				{"field_id": "target_type", "label": "Target Query", "type": "enum", "enum_values": ["self", "explicit", "source", "targets", "query"]},
				{"field_id": "relationship", "label": "Relationship", "type": "enum", "enum_values": ["any", "self", "other"]},
				{"field_id": "limit", "label": "Limit", "type": "number", "min": -1.0, "max": 1000.0, "step": 1.0},
			]
		"combat.ability.logic.delay":
			return [{"field_id": "duration_ticks", "label": "Duration Ticks", "type": "number", "min": 0.0, "max": 100000.0, "step": 1.0}]
		"combat.ability.logic.wait_event":
			return [{"field_id": "event_type", "label": "Event Type", "type": "string"}]
		"combat.ability.logic.subgraph_call":
			return [{"field_id": "graph_id", "label": "Subgraph ID", "type": "string"}, {"field_id": "mode", "label": "Lifetime", "type": "enum", "enum_values": ["owned"]}]
		"combat.ability.logic.repeat":
			return [{"field_id": "count", "label": "Count", "type": "number", "min": 1.0, "max": 64.0, "step": 1.0}]
		"combat.ability.logic.branch":
			return [{"field_id": "condition", "label": "Condition", "type": "bool"}]
		"combat.ability.data.read_attribute":
			return [{"field_id": "attribute_id", "label": "Attribute", "type": "string"}, {"field_id": "entity_id", "label": "Entity (optional)", "type": "string"}]
		"combat.ability.data.read_variable", "combat.ability.data.write_variable":
			return [{"field_id": "variable_id", "label": "Variable ID", "type": "string"}]
		_:
			return []
