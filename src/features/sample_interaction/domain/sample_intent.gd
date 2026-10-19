class_name SampleIntent
extends RefCounted

const INCREMENT := "sample.increment"

var kind: String
var target_instance_id: String


func _init(intent_kind: String = INCREMENT, target_id: String = "sample_000001") -> void:
	kind = intent_kind
	target_instance_id = target_id
