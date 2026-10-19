class_name DefenseResultItem
extends Control

var atlas: DefenseAtlas
var item: Dictionary = {}

func configure(resources: DefenseAtlas, value: Dictionary) -> void:
	atlas = resources
	item = value
	$Count.visible = not (item.get("kind", "") == "equipment" and item.get("count", 0) == 1)
	$Experience.visible = item.get("kind", "") == "hero_exp"
	$Count.text = str(item.get("count", 0))
	tooltip_text = item.get("description", item.get("title", ""))
	queue_redraw()

func _draw() -> void:
	if atlas == null:
		return
	if item.get("kind", "") == "equipment":
		atlas.picture(self, item.res, Rect2(Vector2.ZERO, size))
	else:
		atlas.picture(self, "common:iconBg", Rect2(Vector2.ZERO, size))
		atlas.picture(self, item.res, Rect2(Vector2.ONE * 9, size - Vector2.ONE * 18))
