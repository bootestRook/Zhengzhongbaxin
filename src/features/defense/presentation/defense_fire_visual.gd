class_name DefenseFireVisual
extends RefCounted

# Only presentation: all paths consume the battle clock and read-only snapshots.
static func draw(canvas: CanvasItem, missile: Dictionary, pos: Vector2, age: int) -> void:
	match missile.fire_phase:
		"charge":
			var progress = clampf(float(age) / maxf(1, missile.fire_duration), 0, 1)
			var size = 14 + 16 * progress
			canvas.draw_circle(pos, size + 8, Color(1, 0.26, 0.04, 0.18))
			canvas.draw_circle(pos, size * 0.5, Color(1, 0.91, 0.55, 0.85))
			for i in range(3):
				var angle = age * 0.004 + i * TAU / 3
				canvas.draw_arc(pos, size + 8, angle, angle + 1.2, 12, Color(1, 0.65, 0.16, 0.85), 3, true)
		"flight":
			var direction: Vector2 = missile.from.direction_to(missile.to)
			var side = direction.orthogonal()
			var tail = pos - direction * 112
			canvas.draw_colored_polygon(PackedVector2Array([pos + side * 22, tail + side * 5, tail - direction * 28, tail - side * 5, pos - side * 22]), Color(1, 0.28, 0.03, 0.55))
			canvas.draw_colored_polygon(PackedVector2Array([pos + side * 10, tail, pos - side * 10]), Color(1, 0.77, 0.22, 0.85))
			canvas.draw_circle(pos, 26, Color(1, 0.39, 0.04, 0.22))
			canvas.draw_circle(pos, 13, Color(1, 0.94, 0.65, 0.95))
			var angle = age * 0.008
			canvas.draw_arc(pos, 28, angle, angle + PI * 1.6, 24, Color(1, 0.69, 0.13, 0.95), 4, true)
		"blast":
			var progress = clampf(age / 500.0, 0, 1)
			var fade = 1 - progress
			var radius = maxf(30, float(missile.radius)) * (1 - pow(1 - progress, 3))
			var alpha = 0.55 if missile.fire_secondary else 0.9
			canvas.draw_circle(pos, radius, Color(1, 0.32, 0.03, 0.09 * fade))
			canvas.draw_arc(pos, radius, 0, TAU, 48, Color(1, 0.78, 0.23, alpha * fade), 3 + 5 * fade, true)
			canvas.draw_arc(pos, radius * 0.74, 0, TAU, 40, Color(1, 0.38, 0.05, 0.6 * fade), 3, true)
			for i in range(8):
				var angle = i * TAU / 8 + 0.2
				var point = pos + Vector2.from_angle(angle) * radius
				canvas.draw_circle(point, 2 + 4 * fade, Color(1, 0.88, 0.45, fade * alpha))
