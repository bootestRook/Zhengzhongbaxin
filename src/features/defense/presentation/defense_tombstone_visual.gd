extends Control

const GOLD := Color("ffdc65")
const FINISH_MS := 600
var field: DefenseField
var waiting: Dictionary = {}
var endings: Dictionary = {}
var last_time: int = -1

func render(value: Dictionary) -> void:
	var now: int = value.time
	if value.phase == "home" or now < last_time:
		waiting.clear()
		endings.clear()
	last_time = now
	var present: Dictionary = {}
	if value.phase != "home":
		for actor: Dictionary in value.heroes:
			present[actor.id] = true
			if actor.tombstone and actor.revive > 0:
				waiting[actor.id] = {"actor": actor, "deadline": now + int(actor.revive)}
				endings.erase(actor.id)
			elif waiting.has(actor.id):
				var previous: Dictionary = waiting[actor.id]
				if not actor.dead and now >= int(previous.deadline):
					endings[actor.id] = {"actor": previous.actor, "start": previous.deadline}
				waiting.erase(actor.id)
			if actor.dead and not actor.tombstone:
				endings.erase(actor.id)
	for id in waiting.keys():
		if not present.has(id):
			waiting.erase(id)
	for id in endings.keys():
		if not present.has(id) or now - int(endings[id].start) >= FINISH_MS:
			endings.erase(id)
	queue_redraw()

func descent(actor: Dictionary) -> Dictionary:
	var base = field.world(actor.pos)
	var arrival = base - Vector2(0, 65)
	var top = Vector2(base.x, minf(arrival.y - 75, maxf(220, arrival.y - 260)))
	# Death animation is part of the authoritative revival duration.
	var progress = clampf(float(actor.death_age) / maxf(1, actor.death_age + actor.revive), 0, 1)
	return {"base": base, "top": top, "source": top.lerp(arrival, progress), "progress": progress}

func _draw() -> void:
	if field == null or field.atlas == null or field.snapshot.get("phase", "home") == "home":
		return
	for actor: Dictionary in field.snapshot.heroes:
		if actor.tombstone and actor.revive > 0:
			draw_marker(actor, field.snapshot.time)
	for ending: Dictionary in endings.values():
		draw_marker(ending.actor, field.snapshot.time, clampf((field.snapshot.time - ending.start) / float(FINISH_MS), 0, 1))

func draw_marker(actor: Dictionary, now: int, completion: float = -1) -> void:
	var points = descent(actor)
	var base: Vector2 = points.base
	var top: Vector2 = points.top
	var fading = completion >= 0
	var fade = 1 - smoothstep(0.08, 1.0, completion) if fading else 1.0
	if fading:
		top = top.lerp(base - Vector2(0, 65), smoothstep(0, 0.85, completion))
		points.source = base - Vector2(0, 65)
	var pulse = 0.88 + 0.12 * sin(now * 0.004 + actor.id)
	for width in [44.0, 23.0]:
		var alpha = (0.2 if width == 44 else 0.32) * pulse * fade
		draw_polygon(PackedVector2Array([top + Vector2(-width * 0.35, -32), top + Vector2(width * 0.35, -32),
			base + Vector2(width, -10), base + Vector2(-width, -10)]),
			PackedColorArray([Color(1, 0.86, 0.4, 0), Color(1, 0.86, 0.4, 0),
				Color(1, 0.86, 0.4, alpha), Color(1, 0.86, 0.4, alpha)]))
	draw_line(top, base - Vector2(0, 22), Color(1, 0.94, 0.66, 0.35 * pulse * fade), 3, true)
	draw_set_transform(base, 0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, 45, Color(0.12, 0.14, 0.08, 0.3 * fade), true, -1, true)
	draw_circle(Vector2.ZERO, 42, Color(1, 0.83, 0.3, 0.7 * pulse * fade), false, 4, true)
	if fading:
		draw_circle(Vector2.ZERO, 42 + completion * 65, Color(1, 0.88, 0.48, (1 - completion) * 0.7), false, 4 * (1 - completion), true)
	draw_set_transform(Vector2.ZERO)
	var atlas = field.atlas
	atlas.draw(self, "battle:gravestone", base + Vector2(0, 8 * maxf(0, completion)), Vector2.ONE * (1.05 - 0.08 * maxf(0, completion)), 0, Vector2(0.5, 0.85),
		Color(1, 1, 1, fade), 0, true, [], Color(GOLD, fade))
	var source: Vector2 = points.source
	var absorb = clampf(completion / 0.3, 0, 1) if fading else 0.0
	atlas.draw(self, "battle:smallLight", source, Vector2.ONE * (0.16 + 0.18 * maxf(0, completion)), 0, Vector2(0.5, 0.5), Color(1, 0.88, 0.4, 0.6 * pulse * fade))
	if absorb < 1:
		atlas.draw(self, "hero15:soul", source, Vector2.ONE * 0.44 * (1 - absorb), now, Vector2(0.5, 0.65), Color(Color("fff4cf"), 1 - absorb))
	if fading:
		var flash = sin(clampf(completion * 2.5, 0, 1) * PI)
		atlas.draw(self, "battle:smallLight", source, Vector2.ONE * (0.1 + completion * 0.25), 0, Vector2(0.5, 0.5), Color(1, 0.96, 0.72, flash))
	for i in range(3):
		var t = fmod(now / 3200.0 + i / 3.0 + actor.id * 0.13, 1)
		var sparkle = top.lerp(base - Vector2(0, 30), t) + Vector2(sin(i * 2.2 + now * 0.001) * 20, 0)
		draw_circle(sparkle, 2, Color(1, 0.96, 0.72, sin(t * PI) * 0.75 * fade), true, -1, true)
