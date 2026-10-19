class_name AbilityActionNodeConfiguration
extends AbilityNodeConfiguration

var action_id: String = ""


func _init(configured_action_id: String = "", configured_parameters: Dictionary = {}) -> void:
	super(configured_parameters)
	action_id = configured_action_id
