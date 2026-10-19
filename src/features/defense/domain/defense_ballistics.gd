class_name DefenseBallistics
extends RefCounted

const Displacement = preload("res://src/features/defense/domain/defense_displacement.gd")

static func control(from: Vector2, to: Vector2) -> Vector2:
	var half = (to - from) / 2
	return from + Vector2(half.x if absf(half.x) > absf(half.y) else half.x / 2, -maxf(absf(half.x), absf(half.y)))

static func start(p: Dictionary) -> void:
	p["curve_t"] = 0.0
	var mid = control(p.pos, p.to)
	var length = 0.0
	var previous: Vector2 = p.pos
	for i in range(1, 21):
		var point = Displacement.bezier(p.pos, mid, p.to, i / 20.0)
		length += previous.distance_to(point)
		previous = point
	var duration = maxf(1, p.pos.distance_to(p.to) / maxf(1, p.speed) * 1000)
	p["curve_speed"] = maxf(0.02, maxf(1, length) / duration)
	p["curve_from"] = p.pos

static func step(p: Dictionary) -> Vector2:
	if not p.has("curve_t"):
		start(p)
	var mid = control(p.curve_from, p.to)
	var t: float = p.curve_t
	var derivative: Vector2 = (mid - p.curve_from) * 2 * (1 - t) + (p.to - mid) * 2 * t
	p.curve_t = minf(1, t + p.curve_speed * 16 / maxf(0.0001, derivative.length()))
	var before: Vector2 = p.pos
	p.pos = Displacement.bezier(p.curve_from, mid, p.to, p.curve_t)
	p.rotation = before.direction_to(p.pos).angle() + PI / 2
	return before
