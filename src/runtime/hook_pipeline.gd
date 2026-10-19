class_name HookPipeline
extends RefCounted

var _hooks: Dictionary = {}
var _active_points: Dictionary = {}
var _next_registration_order: int = 0


func register(point: String, hook: RefCounted, priority: int = 0) -> void:
	assert(not point.is_empty(), "hook point must not be empty")
	assert(hook.has_method("apply"), "hook must implement apply(value, context)")
	_next_registration_order += 1
	if not _hooks.has(point):
		_hooks[point] = []
	_hooks[point].append({"hook": hook, "priority": priority, "order": _next_registration_order})
	_hooks[point].sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return left.priority < right.priority if left.priority != right.priority else left.order < right.order
	)


func run(point: String, initial_value: Variant, context: RefCounted) -> Dictionary:
	if _active_points.has(point):
		return {"ok": false, "error": "hook_reentry:%s" % point, "value": initial_value, "trace": []}
	_active_points[point] = true
	var current: Variant = initial_value
	var trace: Array = []
	for registration: Dictionary in _hooks.get(point, []):
		var hook: RefCounted = registration.hook
		current = hook.apply(current, context)
		trace.append(
			{
				"point": point,
				"hook": hook.hook_id() if hook.has_method("hook_id") else hook.get_script().resource_path,
				"value": current,
			}
		)
	_active_points.erase(point)
	return {"ok": true, "error": "", "value": current, "trace": trace}
