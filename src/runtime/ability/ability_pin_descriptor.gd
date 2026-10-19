class_name AbilityPinDescriptor
extends RefCounted

## Stable semantic metadata for an Ability Graph port.
## GraphNode slot indexes are view details; this object is the compiler contract.
const KIND_CONTROL := "control"
const KIND_VALUE := "value"
const KIND_SCOPE := "owned_scope"

var pin_id: String = ""
var kind: String = KIND_CONTROL
var value_type: String = "flow"
var unit: String = ""
var scope: String = "run"
var required: bool = true
var cardinality: String = "one"


func _init(
	semantic_pin_id: String = "",
	semantic_kind: String = KIND_CONTROL,
	semantic_value_type: String = "flow",
	semantic_unit: String = "",
	semantic_scope: String = "run",
	semantic_required: bool = true,
	semantic_cardinality: String = "one"
) -> void:
	pin_id = semantic_pin_id
	kind = semantic_kind
	value_type = semantic_value_type
	unit = semantic_unit
	scope = semantic_scope
	required = semantic_required
	cardinality = semantic_cardinality


func validate() -> String:
	if pin_id.is_empty():
		return "pin_id_empty"
	if not [KIND_CONTROL, KIND_VALUE, KIND_SCOPE].has(kind):
		return "pin_kind_invalid"
	if value_type.is_empty():
		return "pin_value_type_empty"
	if scope.is_empty():
		return "pin_scope_empty"
	if not ["one", "many"].has(cardinality):
		return "pin_cardinality_invalid"
	return ""


func accepts(source: AbilityPinDescriptor) -> String:
	if source == null:
		return "source_pin_missing"
	var source_error := source.validate()
	if not source_error.is_empty():
		return source_error
	var target_error := validate()
	if not target_error.is_empty():
		return target_error
	if kind != source.kind:
		return "pin_kind_mismatch"
	if value_type != source.value_type:
		return "pin_value_type_mismatch"
	if unit != source.unit:
		return "pin_unit_mismatch"
	if scope != source.scope:
		return "pin_scope_mismatch"
	return ""


static func control(pin_id_value: String, required_value: bool = true) -> AbilityPinDescriptor:
	return AbilityPinDescriptor.new(
		pin_id_value,
		KIND_CONTROL,
		"flow",
		"",
		"run",
		required_value,
		"one"
	)


static func value(
	pin_id_value: String,
	value_type_value: String,
	unit_value: String = "",
	scope_value: String = "run",
	required_value: bool = false,
	cardinality_value: String = "one"
) -> AbilityPinDescriptor:
	return AbilityPinDescriptor.new(
		pin_id_value,
		KIND_VALUE,
		value_type_value,
		unit_value,
		scope_value,
		required_value,
		cardinality_value
	)
