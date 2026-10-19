@tool
class_name AbilityEditorPlaceholderResolver
extends RefCounted

const ActionScript = preload(
	"res://addons/combat_framework_editor/editor/ability_editor_placeholder_action.gd"
)


func build_action() -> RefCounted:
	return ActionScript.new()
