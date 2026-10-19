class_name CoreFormulaPlan
extends RefCounted

const ResultScript = preload("res://src/runtime/core/core_formula_result.gd")

var operation: String = "constant"
var value_type: String = "number"
var unit: String = "unitless"
var constant_value: float = 0.0
var attribute_id: String = ""
var entity_scope: String = "source"
var field_id: String = ""
var children: Array[RefCounted] = []
var parameters: Dictionary = {}


static func constant(value: float, value_unit: String = "unitless") -> CoreFormulaPlan:
	var plan := CoreFormulaPlan.new()
	plan.operation = "constant"
	plan.constant_value = value
	plan.unit = value_unit
	return plan


static func attribute(attribute: String, scope: String = "source", value_unit: String = "unitless") -> CoreFormulaPlan:
	var plan := CoreFormulaPlan.new()
	plan.operation = "attribute_read"
	plan.attribute_id = attribute
	plan.entity_scope = scope
	plan.unit = value_unit
	return plan


static func from_dictionary(data: Dictionary) -> CoreFormulaPlan:
	var plan := CoreFormulaPlan.new()
	plan.operation = String(data.get("operation", "constant"))
	plan.value_type = String(data.get("value_type", "number"))
	plan.unit = String(data.get("unit", "unitless"))
	plan.constant_value = float(data.get("value", 0.0))
	plan.attribute_id = String(data.get("attribute_id", ""))
	plan.entity_scope = String(data.get("entity_scope", "source"))
	plan.field_id = String(data.get("field_id", ""))
	var raw_parameters: Variant = data.get("parameters", {})
	plan.parameters = raw_parameters.duplicate(true) if raw_parameters is Dictionary else {}
	for child_data: Variant in data.get("children", []):
		if typeof(child_data) == TYPE_DICTIONARY:
			plan.children.append(from_dictionary(child_data))
	return plan


func evaluate(context: RefCounted) -> RefCounted:
	if context == null:
		return ResultScript.rejected("formula_context_missing")
	var validation_error: String = validate()
	if not validation_error.is_empty():
		return ResultScript.rejected(validation_error)
	var values: Array[float] = []
	match operation:
		"constant":
			return _finite_result(constant_value)
		"attribute_read":
			var entity_id := _entity_for_scope(context, entity_scope)
			if context.has_method("read_attribute"):
				return _finite_result(float(context.read_attribute(entity_id, attribute_id, 0.0)))
			if context.has_method("attribute_value"):
				return _finite_result(float(context.attribute_value(entity_id, attribute_id, 0.0)))
			return ResultScript.rejected("formula_attribute_reader_missing")
		"field_read":
			return _finite_result(_read_field(context, field_id))
		"add", "subtract", "multiply", "divide", "min", "max":
			var error := _evaluate_children(context, values)
			if not error.is_empty():
				return ResultScript.rejected(error)
			if values.is_empty():
				return ResultScript.rejected("formula_children_empty")
			match operation:
				"add":
					return _finite_result(_sum(values))
				"subtract":
					if values.size() < 2:
						return ResultScript.rejected("formula_subtract_requires_two_children")
					return _finite_result(values[0] - values[1])
				"multiply":
					var product := 1.0
					for value: float in values:
						product *= value
					return _finite_result(product)
				"divide":
					if values.size() < 2 or values[1] == 0.0:
						return ResultScript.rejected("formula_divide_by_zero")
					return _finite_result(values[0] / values[1])
				"min":
					return _finite_result(values.min())
				"max":
					return _finite_result(values.max())
		"clamp":
			var clamp_values: Array[float] = []
			var clamp_error := _evaluate_children(context, clamp_values)
			if not clamp_error.is_empty():
				return ResultScript.rejected(clamp_error)
			if clamp_values.is_empty():
				return ResultScript.rejected("formula_children_empty")
			var minimum := float(parameters.get("minimum", -INF))
			var maximum := float(parameters.get("maximum", INF))
			return _finite_result(clampf(clamp_values[0], minimum, maximum))
		"abs":
			var abs_values: Array[float] = []
			var abs_error := _evaluate_children(context, abs_values)
			if not abs_error.is_empty() or abs_values.is_empty():
				return ResultScript.rejected(abs_error if not abs_error.is_empty() else "formula_children_empty")
			return _finite_result(abs(abs_values[0]))
		_:
			return ResultScript.rejected("unknown_formula_operation")
	return ResultScript.rejected("formula_evaluation_failed")


func to_dictionary() -> Dictionary:
	var child_data: Array[Dictionary] = []
	for child: RefCounted in children:
		if child is CoreFormulaPlan:
			child_data.append(child.to_dictionary())
	return {
		"operation": operation,
		"value_type": value_type,
		"unit": unit,
		"value": constant_value,
		"attribute_id": attribute_id,
		"entity_scope": entity_scope,
		"field_id": field_id,
		"children": child_data,
		"parameters": parameters.duplicate(true),
	}


func validate() -> String:
	if operation.is_empty():
		return "formula_operation_empty"
	if value_type.is_empty() or unit.is_empty():
		return "formula_type_or_unit_empty"
	match operation:
		"constant":
			return ""
		"attribute_read":
			if attribute_id.is_empty():
				return "formula_attribute_id_empty"
			if not ["source", "target", "instigator"].has(entity_scope):
				return "formula_entity_scope_invalid"
		"field_read":
			if field_id.is_empty():
				return "formula_field_id_empty"
		"add", "subtract", "multiply", "divide", "min", "max", "abs", "clamp":
			if children.is_empty():
				return "formula_children_empty"
			for child: RefCounted in children:
				if not (child is CoreFormulaPlan):
					return "formula_child_invalid"
				var child_error: String = child.validate()
				if not child_error.is_empty():
					return child_error
			if operation == "subtract" or operation == "divide":
				if children.size() < 2:
					return "formula_binary_children_required"
			if operation == "clamp":
				var minimum := float(parameters.get("minimum", -INF))
				var maximum := float(parameters.get("maximum", INF))
				if minimum > maximum:
					return "formula_clamp_range_invalid"
		_:
			return "unknown_formula_operation"
	return ""


func _evaluate_children(context: RefCounted, output: Array[float]) -> String:
	for child: RefCounted in children:
		if not (child is CoreFormulaPlan):
			return "formula_child_invalid"
		var result: RefCounted = child.evaluate(context)
		if not result.accepted:
			return result.error_code
		output.append(result.value)
	return ""


func _entity_for_scope(context: RefCounted, scope: String) -> String:
	var targets: Variant = context.get("target_entity_ids")
	if scope == "target" and targets is Array and not targets.is_empty():
		return String(targets[0])
	var source: Variant = context.get("source_entity_id")
	if source != null:
		return String(source)
	return ""


func _read_field(context: RefCounted, field: String) -> float:
	var payload: Variant = context.get("event_payload")
	if payload is Dictionary and payload.has(field):
		return float(payload[field])
	if context.has_method("value"):
		return float(context.value(field, 0.0))
	return 0.0


func _finite_result(value: float) -> RefCounted:
	return ResultScript.rejected("formula_value_not_finite") if value == INF or value == -INF or value != value else ResultScript.success(value)


func _sum(values: Array[float]) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total
