extends Button

var atlas: DefenseAtlas

func _draw() -> void:
	if atlas == null:
		return
	if get_draw_mode() == BaseButton.DRAW_PRESSED:
		draw_set_transform(Vector2(0, 3))
	atlas.picture(self, "common:btnW2_face", Rect2(Vector2.ZERO, size))
	atlas.picture(self, "map:point", Rect2(17, 28, 53, 53))
	draw_circle(Vector2(43.5, 54.5), 20, Color(0.26, 0.25, 0.22), true, -1, true)
	atlas.picture(self, "map:arrow", Rect2(31, 39, 29, 30), Color(1, 0.82, 0.36))
	draw_set_transform(Vector2.ZERO)
