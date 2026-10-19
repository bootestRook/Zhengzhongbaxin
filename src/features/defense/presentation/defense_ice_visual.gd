class_name DefenseIceVisual
extends RefCounted

# Rain geometry and reused arrow sprites consume only the battle clock.
static func draw(canvas: CanvasItem, atlas: DefenseAtlas, pos: Vector2, radius: float, age: int) -> void:
	canvas.draw_circle(pos, radius, Color(0.3, 0.75, 1, 0.09))
	canvas.draw_arc(pos, radius, 0, TAU, 48, Color(0.52, 0.88, 1, 0.5), 2, true)
	for i in range(18):
		var angle = i * 2.399963
		var reach = sqrt((i + 0.5) / 18.0) * radius * 0.9
		var progress = fposmod(age + i * 83, 650) / 650.0
		var landing = pos + Vector2(cos(angle), sin(angle)) * reach
		var point = landing + Vector2(-12, -65) * (1 - progress)
		atlas.draw(canvas, "hero13:arrow3", point, Vector2.ONE * 0.55, age,
			Vector2(0.5, 0.5), Color(0.65, 0.9, 1, sin(progress * PI)), -0.18)
