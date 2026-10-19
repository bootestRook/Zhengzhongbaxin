@tool
extends EditorPlugin

const GraphResourceScript = preload("res://src/runtime/ability/ability_graph_resource.gd")
const EditorSceneScript = preload(
	"res://addons/combat_framework_editor/editor/ability_graph_editor.tscn"
)
const DebuggerScript = preload(
	"res://addons/combat_framework_editor/debugger/ability_debugger_plugin.gd"
)

var _editor: Control
var _debugger: EditorDebuggerPlugin


func _enter_tree() -> void:
	_editor = EditorSceneScript.instantiate()
	add_control_to_dock(EditorPlugin.DOCK_SLOT_BOTTOM, _editor)
	_editor.initialize(get_undo_redo())
	_debugger = DebuggerScript.new()
	_debugger.snapshot_received.connect(_on_debug_snapshot)
	add_debugger_plugin(_debugger)
	_editor.hide()


func _exit_tree() -> void:
	if _editor != null:
		remove_control_from_docks(_editor)
		_editor.queue_free()
		_editor = null
	if _debugger != null:
		remove_debugger_plugin(_debugger)
		_debugger = null


func _get_plugin_name() -> String:
	return "Combat Framework Ability Editor"


func _handles(object: Object) -> bool:
	return object is GraphResourceScript


func _edit(object: Object) -> void:
	if _editor == null:
		return
	if object == null:
		_editor.clear_graph_resource()
		return
	_editor.set_graph_resource(object)
	_make_visible(true)


func _make_visible(visible: bool) -> void:
	if _editor != null:
		_editor.visible = visible


func _on_debug_snapshot(snapshot: Dictionary) -> void:
	if _editor != null and _editor.has_method("apply_debug_snapshot"):
		_editor.apply_debug_snapshot(snapshot)
