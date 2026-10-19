class_name DamageCommitHandler
extends RefCounted

const EventResultScript = preload("res://src/runtime/core/core_event_handler_result.gd")
const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const OutcomeScript = preload("res://src/runtime/modules/damage/damage_outcome.gd")

var _state: RefCounted


func _init(state: RefCounted) -> void:
	_state = state


func handler_id() -> String:
	return "module.damage.commit"


func phase() -> String:
	return "commit"


func priority() -> int:
	return 0


func scope_rank() -> int:
	return 0


func owner_sequence() -> int:
	return 0


func handle(context: RefCounted):
	if context.request.target_entity_ids.size() != 1:
		return EventResultScript.reject_result("damage_single_target_required")
	var amount: float = float(context.relay.get("amount", 0.0))
	var attribute_id := String(context.relay.get("attribute_id", "health"))
	var components: Array = context.relay.get("components", [])
	if components.is_empty():
		components = [{"damage_type_id": "physical", "amount": amount, "duration_ticks": 0, "tags": []}]
	else:
		amount = 0.0
		for component: Variant in components:
			if typeof(component) != TYPE_DICTIONARY:
				return EventResultScript.reject_result("damage_component_invalid")
			var component_amount := float(component.get("amount", 0.0))
			if component_amount < 0.0 or component_amount == INF or component_amount == -INF or component_amount != component_amount:
				return EventResultScript.reject_result("damage_component_amount_invalid")
			amount += component_amount
	if amount < 0.0 or amount == INF or amount == -INF or amount != amount:
		return EventResultScript.reject_result("damage_amount_invalid")
	var target_id: String = context.request.target_entity_ids[0]
	var target: RefCounted = _state.entity(target_id)
	if target == null:
		return EventResultScript.reject_result("damage_target_missing")
	if not target.attributes.has(attribute_id):
		return EventResultScript.reject_result("damage_attribute_missing")
	var before: float = target.attributes.value(attribute_id)
	var set_error: String = target.attributes.set_value(attribute_id, before - amount)
	if not set_error.is_empty():
		return EventResultScript.reject_result(set_error)
	var after: float = target.attributes.value(attribute_id)
	var outcome := OutcomeScript.new()
	outcome.source_entity_id = context.request.source_entity_id
	outcome.target_entity_id = target_id
	outcome.attribute_id = attribute_id
	outcome.requested = amount
	outcome.mitigated = amount
	outcome.applied = before - after
	outcome.absorbed = maxf(0.0, amount - outcome.applied)
	outcome.remaining = after
	if outcome.applied <= 0.0:
		outcome.flags.append("absorbed")
	if after <= 0.0:
		outcome.flags.append("defeated")
	for component: Variant in components:
		outcome.component_results.append({
			"damage_type_id": String(component.get("damage_type_id", "physical")),
			"requested": float(component.get("amount", 0.0)),
			"applied": outcome.applied * float(component.get("amount", 0.0)) / amount if amount > 0.0 else 0.0,
			"duration_ticks": int(component.get("duration_ticks", 0)),
		})
	var facts: Array[RefCounted] = [
		DomainEventScript.new(
			"damage.applied",
			{
				"source_entity_id": context.request.source_entity_id,
				"target_entity_id": target_id,
				"attribute_id": attribute_id,
				"requested": outcome.requested,
				"mitigated": outcome.mitigated,
				"absorbed": outcome.absorbed,
				"actual": outcome.applied,
				"remaining": outcome.remaining,
				"flags": outcome.flags.duplicate(),
				"components": outcome.component_results.duplicate(true),
				"outcome": outcome.snapshot(),
			},
			"",
			context.logical_tick,
			0,
			context.request.source_entity_id,
			[target_id],
			context.request.cause_chain
		)
	]
	if after <= 0.0:
		facts.append(
			DomainEventScript.new(
				"entity.defeated",
				{"target_entity_id": target_id, "cause_event_type": "damage.applied"},
				"",
				context.logical_tick,
				0,
				context.request.source_entity_id,
				[target_id],
				context.request.cause_chain
			)
		)
	return EventResultScript.commit_result(facts)
