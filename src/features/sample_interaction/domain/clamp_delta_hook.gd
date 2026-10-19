class_name ClampDeltaHook
extends RefCounted


func hook_id() -> String:
	return "sample.clamp_delta"


func apply(value: Variant, context: RefCounted) -> Variant:
	return mini(int(value), context.state.maximum - context.state.value)
