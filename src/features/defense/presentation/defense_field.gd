class_name DefenseField
extends Control

const FRIENDLY_OUTLINE := Color("ffd45a")
const HealthBar = preload("res://src/features/defense/presentation/defense_health_bar.gd")

var atlas: DefenseAtlas
var snapshot: Dictionary = {}
var damage_numbers: bool = true
var range_hero_id: int = 0
var range_flow: float = 0
var health_bars: Dictionary = {}

func _process(delta: float) -> void:
	if range_hero_id != 0:
		range_flow = fmod(range_flow + delta * 1.3, 1)
	queue_redraw()

func world(pos: Vector2) -> Vector2:
	return pos + Vector2(-320, -97)

func _draw() -> void:
	if atlas == null or snapshot.is_empty():
		return
	var s = snapshot
	if s.phase == "home":
		health_bars.clear()
		return
	atlas.stretch(self, "map:bg3", Rect2(0, -446, 960, 2368))
	atlas.stretch(self, "map:in_game_mask", Rect2(0, -10, 960, 1940))
	draw_skill_range()
	for p in s.missiles:
		if not p.special_res.is_empty():
			draw_missile(p, s.time, true)
		if p.layer < 0:
			draw_missile(p, s.time)
	for effect in s.visuals:
		if int(effect.get("layer", 0)) < 0:
			draw_visual(effect, s.time)
	var live_bars: Dictionary = {}
	for actor in s.actors:
		draw_actor(actor, s.time)
		if not actor.dead and (actor.side == 1 or actor.kind in ["elite", "boss"]):
			live_bars[actor.id] = true
	for id in health_bars.keys():
		if not live_bars.has(id):
			health_bars.erase(id)
	for flower in s.get("flowers", []):
		var pulsing: bool = s.time - flower.pulse_at < 900
		var action = "attack" if pulsing else "idle"
		atlas.actor(self, flower.res, action, world(flower.pos), s.time - (flower.pulse_at if pulsing else flower.started), 1.0, 1.0,
			Color.WHITE, flower.pivot, flower.frames.get(action, []))
	atlas.draw(self, "statue:statue1_4", world(s.statue_pos), Vector2(1.6, 1.6), 0, Vector2(0.5, 1))
	for p in s.missiles:
		if p.layer >= 0:
			draw_missile(p, s.time)
	for effect in s.visuals:
		if int(effect.get("layer", 0)) >= 0:
			draw_visual(effect, s.time)

func skill_range() -> Dictionary:
	if range_hero_id == 0 or snapshot.get("phase", "") != "playing" or snapshot.get("paused", false):
		return {}
	for hero: Dictionary in snapshot.heroes:
		if int(hero.id) == range_hero_id and not hero.dead and not hero.skills.is_empty():
			var radius = float(hero.skills[0].cast_range)
			if radius > 0:
				return {"center": world(hero.pos), "radius": radius}
	return {}

func draw_skill_range() -> void:
	var area = skill_range()
	if area.is_empty():
		return
	var center: Vector2 = area.center
	var radius: float = area.radius
	draw_circle(center, radius, Color(1, 0.15, 0.18, 0.13), true, -1, true)
	# Equal arc lengths keep the dash size and flow speed stable across heroes.
	var circumference = TAU * radius
	var count = maxi(1, roundi(circumference / 32))
	var step = TAU / count
	for i in range(count):
		var start = (i + range_flow) * step
		draw_arc(center, radius, start, start + step * 0.58, 5, Color(0.95, 0.12, 0.16, 0.95), 4, true)

func draw_visual(effect: Dictionary, now: int) -> void:
	if effect.kind == "revive":
		return
	var pos = world(effect.pos)
	var age: int = now - effect.start
	if effect.has("assassin_visual"):
		DefenseAssassinVisual.draw(self, atlas, effect, pos, age)
	elif effect.kind == "skill_text":
		var alpha = clampf(1 - float(age) / (effect.expires - effect.start), 0, 1)
		draw_text(pos + Vector2(-70, -115 - age * 0.04), effect.text, 34, Color(1, 0.84, 0.35, alpha), 140)
	elif effect.kind in ["number", "wall_hit"]:
		if not damage_numbers:
			return
		var color = Color("ffe356") if effect.get("color", "white") == "yellow" else Color.WHITE
		if effect.get("color", "") == "green":
			color = Color("74f590")
		draw_text(pos + Vector2(-60, -65 - age * 0.07), effect.text, 36 if effect.get("critical", false) else 27, color, 120)
	elif effect.kind == "encounter":
		draw_text(Vector2(100, 420), effect.text, 52, Color("ffe356"), 760)
	elif effect.kind == "thorn_link":
		var from = world(effect.from_pos)
		var to = world(effect.to_pos)
		var sprite: Dictionary = atlas.sprites[atlas.frame(effect.res, age)]
		atlas.draw(self, effect.res, from, Vector2(0.3, from.distance_to(to) / maxf(1, sprite.size[1])), age,
			Vector2(0.5, 0), Color("8bd47a"), (to - from).angle() - PI / 2, false)
	else:
		atlas.draw(self, effect.res, pos, Vector2.ONE * float(effect.get("scale", 0.7)), age,
			effect.get("pivot", Vector2(0.5, 0.5)), Color(effect.get("visual_tint", "#ffffff")), 0, effect.get("loop", true), [], Color.TRANSPARENT, effect.has("visual_tint"))

func draw_missile(p: Dictionary, now: int, special: bool = false) -> void:
	if now < p.start:
		return
	var pos = world(p.pos)
	var scale_value: Vector2 = p.render_scale
	if p.get("ice_rain", false):
		DefenseIceVisual.draw(self, atlas, pos, p.radius, now - p.start)
		return
	if special:
		atlas.draw(self, p.special_res, pos, p.logic_scale, now - p.start, Vector2(p.pivot.x, p.pivot.y))
		return
	if p.kind in [4, 5, 7, 35]:
		pos = world(p.from)
	if p.kind in [7, 35]:
		var key = atlas.frame(p.res, now - p.start)
		var sprite: Dictionary = atlas.sprites.get(key, {})
		if not sprite.is_empty():
			scale_value.y = p.from.distance_to(p.to) / maxf(1, float(sprite.size[1]))
	if p.get("fire_visual", false):
		DefenseFireVisual.draw(self, p, pos, now - p.start)
	var pivot = Vector2(p.pivot.x, p.pivot.y)
	var rotation: float = p.rotation if p.kind in [0, 1, 4, 5, 7, 9, 17, 21, 29, 30, 35, 37] else 0.0
	atlas.draw(self, p.res, pos, scale_value, now - p.start, pivot, Color(p.tint), rotation, true, [], Color.TRANSPARENT, true)

func draw_actor(actor: Dictionary, now: int) -> void:
	var pos = world(actor.pos)
	if actor.tombstone:
		return
	var scale_value = 1.0
	var tint = Color(actor.tint)
	if actor.hidden:
		tint.a = 0.25
	if actor.dead and actor.kind == "hero":
		tint = Color(1, 1, 1, 0.5)
	if actor.dead and actor.kind != "hero":
		var age: int = actor.death_age
		if actor.kind == "boss":
			if age >= 400:
				return
			var progress = clampf(age / 300.0, 0, 1)
			scale_value = 1 + 0.4 * progress * progress
			tint = Color(1 - progress * progress, 0, 0)
			if age >= 300:
				var burst = 1 - pow(1 - (age - 300) / 100.0, 2)
				scale_value = 1.4 + 1.4 * burst
				tint = Color(0, 0, 0, 1 - burst)
		else:
			scale_value = death_scale(age)
			if scale_value <= 0:
				return
	draw_set_transform(pos, 0, Vector2(1, 0.35))
	var radius = 29 if actor.kind != "boss" else 50
	if not actor.dead or (actor.kind != "hero" and actor.death_age < (300 if actor.kind == "boss" else 350)):
		draw_circle(Vector2.ZERO, radius, Color(0.04, 0.11, 0.04, 0.2))
	if not actor.dead and actor.side == 1:
		draw_circle(Vector2.ZERO, radius, Color("55c635"), false, 4, true)
	draw_set_transform(Vector2.ZERO)
	var elapsed: int = actor.get("frame_elapsed", roundi((now - actor.action_at) * actor.action_rate))
	if not actor.dead:
		draw_statuses(actor, pos, now, true)
	var outline := Color.TRANSPARENT
	if actor.side == 1 and actor.kind in ["hero", "summon"]:
		outline = Color(FRIENDLY_OUTLINE, tint.a)
	atlas.actor(self, actor.res, actor.action, pos, elapsed, scale_value, actor.facing, tint, Vector2(actor.pivot[0], actor.pivot[1]), actor.frames, outline)
	if actor.dead:
		return
	if actor.overlays.has(actor.action):
		var key: String = actor.overlays[actor.action]
		var duration = 0
		for frame in atlas.animations[key].frames:
			duration += int(frame.duration_ms)
		if actor.action == "skill2" or elapsed < duration:
			atlas.draw(self, key, pos, Vector2(actor.facing, 1), elapsed, Vector2(actor.pivot[0], actor.pivot[1]), tint, 0, actor.action == "skill2")
	draw_statuses(actor, pos, now, false)
	if actor.side == 1 or actor.kind in ["elite", "boss"]:
		var width = 72 if actor.side == 1 else 95
		var bar = Rect2(pos + Vector2(-width / 2.0 + actor.hp_offset[0], actor.hp_offset[1] * scale_value), Vector2(width, 10))
		draw_rect(bar.grow(1.5), Color("42683a"))
		draw_rect(bar, Color("693a31"))
		if not health_bars.has(actor.id):
			health_bars[actor.id] = HealthBar.new()
		health_bars[actor.id].draw(self, bar, actor, now, Color("4cd559") if actor.side == 1 else Color("ed6a4a"))
	if actor.shield > 0:
		draw_arc(pos + Vector2(0, -40), 52, 0, TAU, 24, Color(0.5, 0.9, 1, 0.6), 4, true)
	if actor.get("taunted", false) and not actor.hidden:
		DefenseTauntVisual.draw(self, pos + Vector2(actor.hp_offset[0], actor.hp_offset[1] - 28), now - actor.taunt_started)

func draw_statuses(actor: Dictionary, pos: Vector2, now: int, down: bool) -> void:
	for effect in actor.status_effects:
		if effect.down == down:
			atlas.draw(self, effect.res, pos + effect.offset, effect.scale, now - effect.start, effect.pivot, effect.get("tint", Color.WHITE))

static func death_scale(elapsed: int) -> float:
	var progress = clampf((elapsed - 90) / 260.0, 0, 1)
	var points = [Vector2(0, 1), Vector2(0.2, 0.86), Vector2(0.5, 0.52), Vector2(0.78, 0.18), Vector2(1, 0)]
	for i in range(1, points.size()):
		if progress <= points[i].x:
			var previous: Vector2 = points[i - 1]
			return lerpf(previous.y, points[i].y, (progress - previous.x) / (points[i].x - previous.x))
	return 0.0

func draw_text(pos: Vector2, text: String, font_size: int, color: Color, width: float) -> void:
	draw_string_outline(atlas.font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, 5, Color(Color("202319"), color.a))
	draw_string(atlas.font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)
