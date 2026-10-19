class_name SampleContext
extends RefCounted

var state
var data
var rng
var hooks


func _init(feature_state, data_registry, rng_set, hook_pipeline) -> void:
	state = feature_state
	data = data_registry
	rng = rng_set
	hooks = hook_pipeline


func snapshot_state() -> Dictionary:
	return state.snapshot()


func restore_state(snapshot: Dictionary) -> String:
	return state.restore(snapshot)
