class_name DamageActionResolver
extends RefCounted

const RequestScript = preload("res://src/runtime/core/core_event_request.gd")
const ActionResultScript = preload("res://src/runtime/action_result.gd")

var _damage_module: RefCounted
var attribute_id: String = "health"


func _init(damage_module: RefCounted = null, configured_attribute_id: String = "health") -> void:
	_damage_module = damage_module
	attribute_id = configured_attribute_id


func build_action() -> RefCounted:
	return DamageAction.new(_damage_module, attribute_id)


class DamageAction extends RefCounted:
	var _damage_module: RefCounted
	var _attribute_id: String
	var _parameters: Dictionary = {}

	func _init(damage_module: RefCounted, configured_attribute_id: String) -> void:
		_damage_module = damage_module
		_attribute_id = configured_attribute_id

	func configure(parameters: Dictionary) -> void:
		_parameters = parameters.duplicate(true)

	func action_id() -> String:
		return "module.damage.deal"

	func atomicity() -> String:
		return "atomic"

	func validate(context: RefCounted) -> String:
		if context == null or not context.has_method("dispatch"):
			return "damage_execution_context_missing"
		if _damage_module == null or not _damage_module.has_method("apply_spec"):
			return "damage_module_missing"
		if _amount(context) < 0.0 or _amount(context) == INF or _amount(context) == -INF or _amount(context) != _amount(context):
			return "damage_amount_invalid"
		if _targets(context).is_empty():
			return "damage_targets_empty"
		return ""

	func execute(context: RefCounted):
		var all_events: Array = []
		for target_id: String in _targets(context):
			var result = _damage_module.apply_spec(_build_spec(context, target_id))
			if result == null or not result.accepted:
				return ActionResultScript.rejected(result.error_code if result != null else "damage_dispatch_missing")
			all_events.append_array(result.events)
		return ActionResultScript.success(all_events)

	func _build_spec(context: RefCounted, target_id: String) -> RefCounted:
		var spec := preload("res://src/runtime/modules/damage/damage_spec.gd").new(
			String(context.source_entity_id), target_id, _amount(context), String(_parameters.get("attribute_id", _attribute_id))
		)
		var configured_components: Variant = _parameters.get("components", null)
		if configured_components is Array and not configured_components.is_empty():
			spec.components.clear()
			for component: Variant in configured_components:
				if component is Dictionary:
					spec.add_component(preload("res://src/runtime/modules/damage/damage_component.gd").new(
						String(component.get("damage_type_id", "physical")),
						float(component.get("amount", 0.0)),
						int(component.get("duration_ticks", 0)),
						component.get("tags", [])
					))
		return spec

	func _amount(context: RefCounted) -> float:
		var configured: Variant = _parameters.get("amount", null)
		if configured != null:
			return float(configured)
		return float(context.value("amount", 0.0)) if context.has_method("value") else 0.0

	func _targets(context: RefCounted) -> Array[String]:
		var configured: Variant = _parameters.get("target_entity_ids", null)
		if configured is Array and not configured.is_empty():
			var result: Array[String] = []
			result.assign(configured)
			result.sort()
			return result
		var result: Array[String] = context.target_entity_ids.duplicate()
		result.sort()
		return result
