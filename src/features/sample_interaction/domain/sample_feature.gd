class_name SampleFeature
extends RefCounted

const ActionExecutorScript = preload("res://src/runtime/action_executor.gd")
const ClampDeltaHookScript = preload("res://src/features/sample_interaction/domain/clamp_delta_hook.gd")
const HookPipelineScript = preload("res://src/runtime/hook_pipeline.gd")
const IncrementActionScript = preload("res://src/features/sample_interaction/domain/increment_action.gd")
const SampleContextScript = preload("res://src/features/sample_interaction/domain/sample_context.gd")
const SampleIntentScript = preload("res://src/features/sample_interaction/domain/sample_intent.gd")
const SampleStateScript = preload("res://src/features/sample_interaction/domain/sample_state.gd")

var state
var _context
var _executor


func _init(data_registry, rng_set) -> void:
	state = SampleStateScript.new()
	state.maximum = maxi(1, int(round(data_registry.tuning_value(state.definition_id, "max_value", 10.0))))
	var hooks = HookPipelineScript.new()
	hooks.register("sample.before_value_change", ClampDeltaHookScript.new(), 100)
	_context = SampleContextScript.new(state, data_registry, rng_set, hooks)
	_executor = ActionExecutorScript.new(int(data_registry.setting("debug.trace_limit", 200)))


func submit_increment_intent():
	var intent = SampleIntentScript.new(SampleIntentScript.INCREMENT, state.instance_id)
	return _executor.execute(IncrementActionScript.new(intent), _context)


func reset() -> void:
	state.value = 0
	state.completed = false


func snapshot() -> Dictionary:
	return state.snapshot()


func restore(snapshot_data: Dictionary) -> String:
	return state.restore(snapshot_data)


func action_trace() -> Array:
	return _executor.trace()
