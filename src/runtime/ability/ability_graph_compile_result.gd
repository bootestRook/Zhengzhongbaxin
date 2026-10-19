class_name AbilityGraphCompileResult
extends RefCounted

var accepted: bool = false
var error_code: String = ""
var node_id: String = ""
var pin_id: String = ""
var plan: RefCounted = null


func _init(
	is_accepted: bool = false,
	code: String = "",
	source_node_id: String = "",
	source_pin_id: String = "",
	compiled_plan: RefCounted = null
) -> void:
	accepted = is_accepted
	error_code = code
	node_id = source_node_id
	pin_id = source_pin_id
	plan = compiled_plan


static func success(compiled_plan: RefCounted) -> AbilityGraphCompileResult:
	return AbilityGraphCompileResult.new(true, "", "", "", compiled_plan)


static func rejected(
	code: String,
	source_node_id: String = "",
	source_pin_id: String = ""
) -> AbilityGraphCompileResult:
	return AbilityGraphCompileResult.new(false, code, source_node_id, source_pin_id)
