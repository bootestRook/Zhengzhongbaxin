class_name AbilityNodeConfiguration
extends RefCounted

var parameters: Dictionary = {}


func _init(configured_parameters: Dictionary = {}) -> void:
	parameters = configured_parameters.duplicate(true)
