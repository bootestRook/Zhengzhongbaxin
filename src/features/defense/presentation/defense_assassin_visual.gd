class_name DefenseAssassinVisual
extends RefCounted

const SMOKE_TINT = Color("ffe45b")
const ELECTRIC_CORE = Color("faeeff")
const ELECTRIC_EDGE = Color("6d259c")

# Presentation only. Timing and flicker use battle time, including pause/speed.
static func draw(canvas: CanvasItem, atlas: DefenseAtlas, effect: Dictionary, pos: Vector2, age: int) -> void:
	var progress = clampf(float(age) / maxf(1, effect.expires - effect.start), 0, 1)
	var fade = 1 - smoothstep(0.35, 1.0, progress)
	var tint = Color(effect.visual_tint)
	var scale_value = float(effect.scale)
	if effect.assassin_visual == "smoke":
		# Retain the original smoke hue/texture; soften expansion and disappearance.
		var expansion = lerpf(0.86, 1.05, 1 - pow(1 - progress, 3))
		atlas.draw(canvas, effect.res, pos, Vector2.ONE * scale_value * expansion, age,
			Vector2(0.5, 0.5), Color(SMOKE_TINT, fade * 0.85), 0, false, [], Color.TRANSPARENT, true)
		return
	atlas.draw(canvas, effect.res, pos, Vector2.ONE * scale_value, age,
		Vector2(0.5, 0.5), Color(tint, fade), 0, false, [], Color.TRANSPARENT, true)
	var phase = floorf(age / 48.0)
	if effect.assassin_visual == "strike":
		var center = pos + Vector2(0, -32)
		canvas.draw_circle(center, 43 + progress * 15, Color(tint, 0.1 * fade), true, -1, true)
		for i in range(3):
			var x = (i - 1) * 34.0
			var bottom = pos + Vector2(x * 0.75, -8)
			var top = pos + Vector2(x + sin(phase + i * 2.1) * 12, -102 - (i % 2) * 28)
			bolt(canvas, bottom, top, phase + i * 1.7, tint, fade)
	elif effect.assassin_visual == "fan":
		var radius = scale_value * 200 * (0.3 + 0.7 * (1 - pow(1 - progress, 3)))
		for i in range(8):
			var angle = i * TAU / 8
			var from = pos + Vector2(cos(angle), sin(angle) * 0.7) * radius
			var end_angle = angle + TAU / 8 * 0.72
			var to = pos + Vector2(cos(end_angle), sin(end_angle) * 0.7) * radius
			bolt(canvas, from, to, phase + i, tint, fade * 0.65)

static func bolt(canvas: CanvasItem, from: Vector2, to: Vector2, phase: float, tint: Color, alpha: float) -> void:
	var side = from.direction_to(to).orthogonal()
	var points = PackedVector2Array([from])
	for i in range(1, 6):
		points.append(from.lerp(to, i / 6.0) + side * sin(i * 2.7 + phase) * 9)
	points.append(to)
	canvas.draw_polyline(points, Color(ELECTRIC_EDGE, alpha * 0.65), 9, true)
	canvas.draw_polyline(points, Color(tint, alpha), 5, true)
	canvas.draw_polyline(points, Color(ELECTRIC_CORE, alpha * 0.9), 1.6, true)
