extends RefCounted

const AttributeDefinitionScript = preload("res://src/runtime/core/core_attribute_definition.gd")
const StateScript = preload("res://src/runtime/core/core_state.gd")
const EffectDefinitionScript = preload("res://src/runtime/core/core_effect_definition.gd")
const EventRequestScript = preload("res://src/runtime/core/core_event_request.gd")
const DomainEventScript = preload("res://src/runtime/core/core_domain_event.gd")
const EventResultScript = preload("res://src/runtime/core/core_event_handler_result.gd")
const PipelineScript = preload("res://src/runtime/core/core_event_pipeline.gd")
const ConditionRegistryScript = preload("res://src/runtime/core/core_condition_registry.gd")
const ConditionResultScript = preload("res://src/runtime/core/core_condition_result.gd")
const FormulaRegistryScript = preload("res://src/runtime/core/core_formula_registry.gd")
const FormulaResultScript = preload("res://src/runtime/core/core_formula_result.gd")
const TriggerDefinitionScript = preload("res://src/runtime/core/core_trigger_definition.gd")
const TriggerRegistryScript = preload("res://src/runtime/core/core_trigger_registry.gd")
const CueRouterScript = preload("res://src/runtime/presentation/core_cue_router.gd")
const DamageModuleScript = preload("res://src/runtime/modules/damage/damage_module.gd")
const BuffModuleScript = preload("res://src/runtime/modules/buff/buff_module.gd")
const TargetRegistryScript = preload("res://src/runtime/core/core_target_resolver_registry.gd")
const TargetQueryDefinitionScript = preload("res://src/runtime/core/core_target_query_definition.gd")
const ExecutionContextScript = preload("res://src/runtime/core/core_execution_context.gd")
const ProjectileModuleScript = preload("res://src/runtime/modules/projectile/projectile_module.gd")
const MovementModuleScript = preload("res://src/runtime/modules/movement/movement_module.gd")
const SummonModuleScript = preload("res://src/runtime/modules/summon/summon_module.gd")
const AreaModuleScript = preload("res://src/runtime/modules/area/area_module.gd")
const ActionRegistryScript = preload("res://src/runtime/ability/ability_action_registry.gd")
const ModuleCatalogScript = preload("res://src/runtime/modules/gameplay_module_catalog.gd")
const TraceComparisonScript = preload("res://src/runtime/core/core_event_trace_comparison.gd")
const FormulaPlanScript = preload("res://src/runtime/core/core_formula_plan.gd")
const DamageSpecScript = preload("res://src/runtime/modules/damage/damage_spec.gd")
const DamageComponentScript = preload("res://src/runtime/modules/damage/damage_component.gd")
const ProjectileDefinitionScript = preload("res://src/runtime/modules/projectile/projectile_definition.gd")


class GreaterThanCondition extends RefCounted:
	func evaluate(context: RefCounted, parameters: Dictionary):
		return ConditionResultScript.pass_result() if context.value > int(parameters.get("threshold", 0)) else ConditionResultScript.fail_result("below_threshold")


class AddFormula extends RefCounted:
	func evaluate(context: RefCounted, parameters: Dictionary):
		return FormulaResultScript.success(float(context.value) + float(parameters.get("amount", 0.0)))


class FormulaContext extends RefCounted:
	var value: int = 7


class CueResolver extends RefCounted:
	func resolve(event: RefCounted) -> Dictionary:
		return {"cue_key": event.payload.cue_key, "event_type": event.event_type}


class PipelineHandler extends RefCounted:
	var id: String
	var phase_name: String
	var order: Array[String]
	var handler_priority: int
	var behavior: String

	func _init(
		handler_id_value: String,
		handler_phase: String,
		shared_order: Array[String],
		priority_value: int = 0,
		behavior_value: String = "continue"
	) -> void:
		id = handler_id_value
		phase_name = handler_phase
		order = shared_order
		handler_priority = priority_value
		behavior = behavior_value

	func handler_id() -> String:
		return id

	func phase() -> String:
		return phase_name

	func priority() -> int:
		return handler_priority

	func scope_rank() -> int:
		return 0

	func owner_sequence() -> int:
		return 0

	func handle(context: RefCounted):
		order.append(id)
		match behavior:
			"double":
				var relay: Dictionary = {}
				relay = context.relay.duplicate(true)
				relay["magnitude"] = int(relay.get("magnitude", 0)) * 2
				return EventResultScript.replace_result(relay)
			"commit":
				var fact := DomainEventScript.new(
					"test.committed",
					{"magnitude": context.relay.get("magnitude", 0)},
					"",
					0,
					1,
					context.request.source_entity_id,
					context.request.target_entity_ids
				)
				return EventResultScript.commit_result([fact])
			"reject":
				return EventResultScript.reject_result("handler_rejected")
		return EventResultScript.continue_result()


class CommittedObserver extends RefCounted:
	var events_seen: int = 0
	var ticks: Array[int] = []

	func on_committed(events: Array[RefCounted], logical_tick: int) -> String:
		events_seen += events.size()
		ticks.append(logical_tick)
		return ""


func run(test: TestSupport) -> void:
	_test_state_and_effect_lifecycle(test)
	_test_condition_formula_and_trigger_registries(test)
	_test_event_pipeline_order_relay_commit_and_rejection(test)
	_test_event_trace_comparison(test)
	_test_damage_and_buff_modules(test)
	_test_state_restore_and_target_resolvers(test)
	_test_world_port_modules(test)
	_test_advanced_combat_contracts(test)


func _test_state_and_effect_lifecycle(test: TestSupport) -> void:
	var state := StateScript.new()
	var entity = state.create_entity("entity_a")
	test.assert_true(entity != null, "core state must create an entity")
	var health_definition := AttributeDefinitionScript.new("health", 100.0, 0.0, 100.0)
	test.assert_equal(entity.attributes.register_definition(health_definition), "", "attribute definition must register")
	test.assert_equal(entity.attributes.set_value("health", 140.0), "", "attribute set must clamp valid values")
	test.assert_equal(entity.attributes.value("health"), 100.0, "attribute store must clamp to definition range")
	var first_tag_handle: String = entity.tags.grant("status.poisoned", "effect_a")
	var second_tag_handle: String = entity.tags.grant("status.poisoned", "effect_b")
	test.assert_true(entity.tags.has_tag("status.poisoned"), "tag presence must be derived from grants")
	test.assert_equal(entity.tags.revoke(first_tag_handle), "", "tag grant must revoke by stable handle")
	test.assert_true(entity.tags.has_tag("status.poisoned"), "one grant must not remove another source")
	test.assert_equal(entity.tags.revoke(second_tag_handle), "", "second tag grant must revoke independently")
	test.assert_true(not entity.tags.has_tag("status.poisoned"), "tag must disappear after all grants revoke")
	var effect_definition := EffectDefinitionScript.new("effect.poison", 3, 0, ["status.poisoned"])
	test.assert_equal(entity.effects.register_definition(effect_definition), "", "effect definition must register")
	var effect = entity.effects.apply("effect.poison", "entity_source", 0)
	test.assert_true(effect != null, "effect store must create an instance")
	test.assert_equal(entity.effects.expire_at(2).size(), 0, "effect must remain active before expiry tick")
	test.assert_equal(entity.effects.expire_at(3).size(), 1, "effect must expire at declared tick")
	test.assert_equal(state.advance_tick(), 1, "core state must advance explicit logical time")


func _test_condition_formula_and_trigger_registries(test: TestSupport) -> void:
	var context := FormulaContext.new()
	var conditions := ConditionRegistryScript.new()
	test.assert_equal(conditions.register("test.greater_than", GreaterThanCondition.new()), "", "condition evaluator must register explicitly")
	var passed = conditions.evaluate("test.greater_than", context, {"threshold": 5})
	test.assert_true(passed.passed, "condition evaluator must return a typed pass result")
	var failed = conditions.evaluate("test.greater_than", context, {"threshold": 9})
	test.assert_equal(failed.reason_code, "below_threshold", "condition failure must expose stable reason")
	var formulas := FormulaRegistryScript.new()
	test.assert_equal(formulas.register("test.add", AddFormula.new()), "", "formula evaluator must register explicitly")
	var formula = formulas.evaluate("test.add", context, {"amount": 5.5})
	test.assert_true(formula.accepted, "formula evaluator must return a typed result")
	test.assert_equal(formula.value, 12.5, "formula must evaluate deterministic inputs")
	var triggers := TriggerRegistryScript.new()
	var trigger := TriggerDefinitionScript.new("trigger.poison", "damage.applied", "", "apply.poison")
	test.assert_equal(triggers.register(trigger), "", "trigger definition must register explicitly")
	test.assert_equal(triggers.definition("trigger.poison").action_id, "apply.poison", "trigger lookup must preserve binding")
	var cue_router := CueRouterScript.new()
	test.assert_equal(cue_router.register("cue.damage", CueResolver.new()), "", "cue resolver must register explicitly")
	var cue_event := DomainEventScript.new("damage.applied", {"cue_key": "cue.damage"})
	test.assert_equal(cue_router.route([cue_event]).size(), 1, "cue router must consume committed facts only")


func _test_event_pipeline_order_relay_commit_and_rejection(test: TestSupport) -> void:
	var order: Array[String] = []
	var pipeline := PipelineScript.new(8, 4)
	test.assert_not_empty(
		pipeline.register("damage.request", PipelineHandler.new("modify.low", "modify", order, 0)),
		"pipeline must return a stable registration handle"
	)
	pipeline.register("damage.request", PipelineHandler.new("modify.high", "modify", order, 100, "double"))
	pipeline.register("damage.request", PipelineHandler.new("commit", "commit", order, 0, "commit"))
	var request := EventRequestScript.new("damage.request", {"magnitude": 10}, "source", ["target"])
	var result = pipeline.dispatch(request, 12)
	test.assert_true(result.accepted, "event pipeline must accept a valid request")
	test.assert_equal(order, ["modify.high", "modify.low", "commit"], "handlers must use phase and priority order")
	test.assert_equal(result.events.size(), 1, "commit handler must produce a domain fact")
	test.assert_equal(result.events[0].payload.magnitude, 20, "modify relay must reach commit handler")
	test.assert_equal(pipeline.trace().size(), 1, "event pipeline must retain bounded event trace entries")
	test.assert_equal(pipeline.trace()[0].handler_trace.size(), 3, "event trace must retain ordered handler decisions")
	var observer := CommittedObserver.new()
	var observer_handle := pipeline.register_committed_observer(observer)
	test.assert_not_empty(observer_handle, "pipeline must register committed observers explicitly")
	var observed = pipeline.dispatch(EventRequestScript.new("damage.request", {"magnitude": 1}, "source", ["target"]), 13)
	test.assert_true(observed.accepted, "observer dispatch must preserve pipeline result")
	test.assert_equal(observer.events_seen, 1, "committed observer must receive domain facts")
	test.assert_equal(observer.ticks, [13], "committed observer must receive logical tick")
	test.assert_equal(pipeline.unregister_committed_observer(observer_handle), "", "observer must unregister by handle")
	var rejection_pipeline := PipelineScript.new()
	rejection_pipeline.register("blocked.request", PipelineHandler.new("gate", "gate", [], 0, "reject"))
	var rejected = rejection_pipeline.dispatch(EventRequestScript.new("blocked.request"))
	test.assert_true(not rejected.accepted, "gate rejection must reject the request")
	test.assert_equal(rejected.error_code, "handler_rejected", "event rejection must preserve stable error code")
	test.assert_equal(rejection_pipeline.trace()[0].error_code, "handler_rejected", "rejected requests must remain visible in the event trace")
	var trigger_registry := TriggerRegistryScript.new()
	var trigger := TriggerDefinitionScript.new("trigger.chain", "source.fact", "", "next.action")
	trigger_registry.register(trigger)
	var trigger_pipeline := PipelineScript.new()
	trigger_pipeline.register("source.fact", trigger_registry.create_handler("trigger.chain"))
	trigger_pipeline.register("trigger.action", PipelineHandler.new("action_sink", "commit", [], 0, "commit"))
	var trigger_result = trigger_pipeline.dispatch(EventRequestScript.new("source.fact"))
	test.assert_true(trigger_result.accepted, "trigger handler must enqueue a bounded child request")
	test.assert_equal(trigger_result.processed_requests, 2, "trigger child must re-enter the event pipeline")


func _test_event_trace_comparison(test: TestSupport) -> void:
	var pipeline := PipelineScript.new()
	pipeline.register("trace.request", PipelineHandler.new("commit", "commit", [], 0, "commit"))
	var request := EventRequestScript.new("trace.request", {"magnitude": 4}, "source", ["target"])
	test.assert_true(pipeline.dispatch(request, 2).accepted, "trace fixture must dispatch")
	var same := TraceComparisonScript.compare(pipeline.trace(), pipeline.trace())
	test.assert_true(same.accepted, "identical traces must compare equal")
	var changed: Array[Dictionary] = pipeline.trace()
	changed[0].request_payload.magnitude = 9
	var mismatch := TraceComparisonScript.compare(pipeline.trace(), changed)
	test.assert_true(not mismatch.accepted, "trace comparison must report semantic divergence")
	test.assert_equal(mismatch.field, "request_payload", "trace mismatch must identify the changed field")


func _test_damage_and_buff_modules(test: TestSupport) -> void:
	var state := StateScript.new()
	var source = state.create_entity("source")
	var target = state.create_entity("target")
	target.attributes.register_definition(AttributeDefinitionScript.new("health", 100.0, 0.0, 100.0))
	var pipeline := PipelineScript.new()
	var damage := DamageModuleScript.new(state, pipeline)
	test.assert_equal(damage.register(), "", "damage module must register its commit handler")
	var damage_result = damage.apply_damage("source", "target", 30.0)
	test.assert_true(damage_result.accepted, "damage module must dispatch a valid damage request")
	test.assert_equal(target.attributes.value("health"), 70.0, "damage module must mutate the owning attribute store")
	test.assert_equal(damage_result.events[0].event_type, "damage.applied", "damage must publish a committed fact")
	var buff := BuffModuleScript.new(state)
	target.effects.register_definition(EffectDefinitionScript.new("buff.guard", 5, 0, ["status.guarded"]))
	var buff_result: Dictionary = buff.apply_effect("target", "buff.guard", "source")
	test.assert_true(bool(buff_result.accepted), "buff module must create an Effect instance")
	test.assert_not_empty(buff_result.get("instance_id", ""), "buff instance must expose a stable handle")
	var remove_result: Dictionary = buff.remove_effect("target", buff_result.instance_id)
	test.assert_true(bool(remove_result.accepted), "buff module must remove by stable instance handle")


func _test_state_restore_and_target_resolvers(test: TestSupport) -> void:
	var state := StateScript.new()
	var source = state.create_entity("source")
	var target = state.create_entity("target")
	source.attributes.register_definition(AttributeDefinitionScript.new("mana", 10.0, 0.0, 10.0))
	var handle: String = source.tags.grant("status.ready", "test")
	var snapshot: Dictionary = state.snapshot()
	source.attributes.set_value("mana", 2.0)
	source.tags.revoke(handle)
	test.assert_equal(state.restore(snapshot), "", "core state must restore owner stores atomically")
	test.assert_equal(source.attributes.value("mana"), 10.0, "state restore must restore attribute values")
	test.assert_true(source.tags.has_tag("status.ready"), "state restore must restore tag grants")
	var targets := TargetRegistryScript.new()
	test.assert_equal(targets.register_builtins(), "", "target resolver registry must register builtins")
	var context := ExecutionContextScript.new(state, null, "source", ["target"], targets)
	var explicit = targets.resolve("explicit", context, {"entity_ids": ["target", "source", "target"]})
	test.assert_true(explicit.accepted, "explicit target resolver must accept stable ids")
	test.assert_equal(explicit.entity_ids, ["source", "target"], "target resolver must sort and deduplicate ids")
	var current = targets.resolve("targets", context)
	test.assert_equal(current.entity_ids, ["target"], "targets resolver must preserve context target ids")


func _test_world_port_modules(test: TestSupport) -> void:
	var state := StateScript.new()
	state.create_entity("source")
	state.create_entity("target")
	var projectile := ProjectileModuleScript.new()
	var projectile_definition := ProjectileDefinitionScript.new("arrow", 3)
	test.assert_equal(projectile.register_definition(projectile_definition), "", "projectile module must register its definition before spawning")
	var projectile_instance = projectile.spawn("source", "target", "arrow", 0)
	test.assert_true(projectile_instance != null, "projectile module must create domain instance")
	var hit = projectile.impact(projectile_instance.projectile_id, "target", 1, 2)
	test.assert_equal(hit.event_type, "projectile.impact", "projectile impact must publish a committed fact")
	test.assert_equal(hit.logical_tick, 2, "projectile impact must use the observation tick")
	var movement := MovementModuleScript.new()
	test.assert_equal(movement.set_position("source", Vector3.ZERO), "", "movement module must initialize a position")
	var moved = movement.move("source", Vector3(1, 2, 0), "add", 1)
	test.assert_equal(moved.event_type, "movement.committed", "movement must publish a committed fact")
	test.assert_equal(movement.position("source"), Vector3(1, 2, 0), "movement state must be owned by module")
	var summon := SummonModuleScript.new(state)
	var summon_event = summon.summon("source", "minion", 1, 2)
	test.assert_equal(summon_event.event_type, "summon.created", "summon module must create entity through state owner")
	test.assert_true(state.entity(summon_event.payload.entity_id) != null, "summoned entity must enter CoreState")
	var area := AreaModuleScript.new()
	var area_id: String = area.create_area("aura", 1)
	var area_events = area.observe(area_id, 1, ["source", "target"], 1)
	test.assert_equal(area_events.size(), 2, "area observation must emit deterministic enter facts")
	test.assert_equal(area.members(area_id), ["source", "target"], "area must retain sorted observation membership")
	var catalog_registry := ActionRegistryScript.new()
	var catalog := ModuleCatalogScript.register_default_actions(state, PipelineScript.new(), catalog_registry)
	test.assert_equal(catalog.error_code, "", "gameplay module catalog must compose all default modules explicitly")
	test.assert_true(catalog_registry.has_action("module.projectile.spawn"), "module catalog must register projectile action")


func _test_advanced_combat_contracts(test: TestSupport) -> void:
	var state := StateScript.new()
	var source = state.create_entity("advanced_source")
	var target = state.create_entity("advanced_target")
	target.attributes.register_definition(AttributeDefinitionScript.new("health", 100.0, 0.0, 100.0))
	target.attributes.register_definition(AttributeDefinitionScript.new("power", 10.0, 0.0, 100.0))
	var modifier_handle: String = target.attributes.add_modifier("power", "multiply", 0.5, "equipment.sword", 10)
	test.assert_not_empty(modifier_handle, "attribute modifier must return a stable handle")
	test.assert_equal(target.attributes.value("power"), 15.0, "attribute aggregation must apply deterministic multiplier")
	test.assert_true(target.attributes.aggregation_trace("power").size() >= 3, "attribute aggregation must expose provenance trace")
	test.assert_equal(target.attributes.remove_modifier(modifier_handle), "", "attribute modifier must revoke by handle")

	target.attributes.register_definition(AttributeDefinitionScript.new("shield", 0.0, 0.0, 100.0))
	var effect_definition := EffectDefinitionScript.new("effect.guard", 5, 2, ["status.guard"])
	effect_definition.stacking_policy = "refresh"
	effect_definition.modifiers = [{"attribute_id": "shield", "operation": "final_add", "magnitude": 20.0, "priority": 1}]
	test.assert_equal(target.effects.register_definition(effect_definition), "", "effect definition must accept modifiers and stacking policy")
	var effect = target.effects.apply("effect.guard", source.entity_id, 0, target.entity_id)
	test.assert_true(effect != null, "effect instance must be created")
	test.assert_true(target.tags.matches("status"), "effect tag grant must support hierarchical queries")
	test.assert_equal(target.attributes.value("shield"), 20.0, "effect modifier must attach to target attributes")
	var effect_snapshot: Dictionary = state.snapshot()
	test.assert_equal(target.effects.remove(effect.instance_id), "", "effect removal must revoke owned grants")
	test.assert_equal(state.restore(effect_snapshot), "", "effect restore must preserve existing grant ownership")
	effect = target.effects.instance(effect.instance_id)
	test.assert_true(effect != null, "effect restore must recreate the active instance")
	test.assert_true(target.tags.has_tag("status.guard"), "effect restore must preserve the tag grant")
	test.assert_equal(target.attributes.value("shield"), 20.0, "effect restore must preserve the modifier")
	test.assert_equal(target.effects.period_due_at(1).size(), 0, "periodic effect must not execute before period")
	test.assert_equal(target.effects.period_due_at(2).size(), 1, "periodic effect must expose due instances")
	test.assert_equal(target.effects.remove(effect.instance_id), "", "effect removal must revoke owned grants")
	test.assert_true(not target.tags.has_tag("status.guard"), "effect removal must revoke its tag grant")
	test.assert_equal(target.attributes.value("shield"), 0.0, "effect removal must revoke its modifier")

	var pipeline := PipelineScript.new()
	var damage := DamageModuleScript.new(state, pipeline)
	test.assert_equal(damage.register(), "", "advanced damage module must register")
	var spec := DamageSpecScript.new(source.entity_id, target.entity_id, 0.0, "health")
	test.assert_equal(spec.add_component(DamageComponentScript.new("fire", 20.0)), "", "damage spec must accept typed components")
	test.assert_equal(spec.add_component(DamageComponentScript.new("poison", 5.0, 3)), "", "damage spec must accept timed components")
	var damage_result = damage.apply_spec(spec)
	test.assert_true(damage_result.accepted, "typed damage spec must dispatch")
	test.assert_equal(target.attributes.value("health"), 75.0, "typed damage components must commit total amount")
	test.assert_equal(damage_result.events[0].payload.components.size(), 2, "damage fact must retain component outcome data")
	var hit_event = damage.resolve_hit_event(source.entity_id, target.entity_id, "blocked", "shield", 3)
	test.assert_equal(hit_event.event_type, "hit.rejected", "hit resolution must remain separate from damage commit")
	var multi_target_request := EventRequestScript.new("damage.request", {"amount": 1.0}, source.entity_id, [target.entity_id, source.entity_id])
	test.assert_true(not pipeline.dispatch(multi_target_request, 1).accepted, "damage pipeline must reject multi-target requests")

	var formula_context := ExecutionContextScript.new(state, pipeline, source.entity_id, [target.entity_id])
	var formula := FormulaPlanScript.from_dictionary({
		"operation": "add",
		"children": [
			{"operation": "attribute_read", "attribute_id": "power", "entity_scope": "target"},
			{"operation": "constant", "value": 5.0},
		],
	})
	var formula_result = formula.evaluate(formula_context)
	test.assert_true(formula_result.accepted, "typed formula plan must evaluate")
	test.assert_equal(formula_result.value, 15.0, "typed formula plan must read target attributes deterministically")

	var targets := TargetRegistryScript.new()
	test.assert_equal(targets.register_builtins(), "", "advanced target registry must register query builtin")
	target.tags.grant("team.enemy", "fixture")
	var query_definition := TargetQueryDefinitionScript.new("enemy_targets")
	query_definition.relationship = "other"
	query_definition.include_tag_query = {"all": ["team"]}
	query_definition.order = "entity_id"
	var query = targets.resolve("query", formula_context, {"definition": query_definition})
	test.assert_true(query.accepted, "target query must resolve from state snapshot")
	test.assert_equal(query.entity_ids, [target.entity_id], "target query must filter by hierarchical tag and relationship")

	var projectile := ProjectileModuleScript.new()
	var projectile_definition := ProjectileDefinitionScript.new("typed.arrow", 4)
	projectile_definition.max_hits = 1
	test.assert_equal(projectile.register_definition(projectile_definition), "", "projectile definition must register explicitly")
	var projectile_instance = projectile.spawn(source.entity_id, target.entity_id, "typed.arrow", 4)
	var impact = projectile.impact(projectile_instance.projectile_id, target.entity_id, 1, 7)
	test.assert_equal(impact.event_type, "projectile.impact", "projectile must publish explicit impact facts")
	test.assert_equal(impact.logical_tick, 7, "projectile impact must preserve current logical tick")
