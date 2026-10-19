class_name ChangeValueCommand
extends RefCounted

const ActionResultScript = preload("res://src/runtime/action_result.gd")


func execute(context: RefCounted, requested_delta: int):
	var hook_result: Dictionary = context.hooks.run("sample.before_value_change", requested_delta, context)
	if not hook_result.ok:
		return ActionResultScript.rejected(String(hook_result.error))
	var applied_delta := int(hook_result.value)
	if applied_delta <= 0:
		return ActionResultScript.rejected("no_value_change")
	var previous: int = context.state.value
	context.state.value += applied_delta
	context.state.completed = context.state.value >= context.state.maximum
	var events: Array = [
		{
			"type": "sample.value_changed",
			"definition_id": context.state.definition_id,
			"instance_id": context.state.instance_id,
			"previous": previous,
			"current": context.state.value,
			"delta": applied_delta,
			"hook_trace": hook_result.trace,
			"presentation_cue_id": "sample.value_changed",
		}
	]
	if context.state.completed:
		events.append(
			{
				"type": "sample.limit_reached",
				"definition_id": context.state.definition_id,
				"instance_id": context.state.instance_id,
				"presentation_cue_id": "sample.limit_reached",
			}
		)
	return ActionResultScript.success(events)
