class_name DefenseTauntVisual
extends RefCounted

# The anger mark follows its actor; only the battle clock drives its pulse.
static func draw(canvas: CanvasItem, pos: Vector2, age: int) -> void:
	var size = 16.0 * (1 + 0.1 * sin(age * TAU / 600.0))
	for x in [-1, 1]:
		for y in [-1, 1]:
			var points = PackedVector2Array([
				pos + Vector2(x * size, y * 3),
				pos + Vector2(x * 6, y * 6),
				pos + Vector2(x * 3, y * size)])
			canvas.draw_polyline(points, Color("202319"), 8, true)
			canvas.draw_polyline(points, Color("ff7055"), 4, true)
