extends Control

@export var panel: String

func _draw() -> void:
	get_parent().get_parent().draw_panel(self, panel)
