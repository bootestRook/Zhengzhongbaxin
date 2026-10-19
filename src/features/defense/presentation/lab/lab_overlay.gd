extends Control

signal point_selected(point: Vector2, unit_id: int)
var geometry: Dictionary = {}
var selected: int = 0
var debug_shapes: bool = false
var placing: bool = false
var offset = Vector2(-320, -97)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point: Vector2 = event.position - offset
		var nearest = 0
		var distance = 120.0
		for actor in geometry.get("actors", []):
			var current: float = point.distance_to(actor.pos + Vector2(0, -45))
			if current < distance:
				distance = current
				nearest = int(actor.id)
		point_selected.emit(point, nearest)
		accept_event()

func polygon(points: PackedVector2Array, color: Color) -> void:
	if points.is_empty(): return
	var shifted = PackedVector2Array()
	for point in points: shifted.append(point + offset)
	shifted.append(shifted[0])
	draw_polyline(shifted, color, 3, true)

func _draw() -> void:
	for actor in geometry.get("actors", []):
		if debug_shapes:
			polygon(actor.body, Color(0.2, 1, 0.75, 0.85))
			if actor.id == selected: polygon(actor.attack, Color(1, 0.6, 0.1, 0.9))
		if actor.id == selected:
			draw_arc(actor.pos + offset, 55, 0, TAU, 48, Color("ffe26c"), 5, true)
		if actor.survival != "normal":
			draw_circle(actor.pos + offset + Vector2(0, 12), 10, Color("73e6ff") if actor.survival == "immortal" else Color("fff28a"))
	if not debug_shapes: return
	for circle in geometry.get("circles", []):
		if circle.radius > 0: draw_arc(circle.center + offset, circle.radius, 0, TAU, 96, Color(1, 0.35, 0.3, 0.8) if circle.kind == "cast" else Color(1, 0.8, 0.2, 0.7), 3, true)
	for missile in geometry.get("missiles", []):
		polygon(missile.shape, Color(0.3, 0.85, 1, 0.8))
		draw_line(missile.from + offset, missile.to + offset, Color(0.3, 0.85, 1, 0.4), 2)
		if missile.shape.is_empty() and missile.radius > 0: draw_arc(missile.pos + offset, missile.radius, 0, TAU, 48, Color(0.3, 0.85, 1, 0.7), 2)
	var target: Array = geometry.get("target_line", [])
	if target.size() == 2: draw_line(target[0] + offset, target[1] + offset, Color("ffeb8a"), 3)
