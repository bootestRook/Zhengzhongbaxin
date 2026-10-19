extends Control

@export var idle_style: StyleBox
@export var active_style: StyleBox
@export var won_style: StyleBox
var atlas: DefenseAtlas
var option: Dictionary = {}
var active: bool = false
var won: bool = false

func configure(art: DefenseAtlas, definition: Dictionary) -> void:
	atlas = art
	option = definition
	queue_redraw()

func _draw() -> void:
	draw_style_box(active_style if active else (won_style if won else idle_style), Rect2(Vector2.ZERO, size))
	if atlas != null and not option.is_empty():
		atlas.picture(self, option.icon_res, Rect2(Vector2(6, 6), size - Vector2(12, 12)))
