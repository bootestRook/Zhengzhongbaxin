class_name DefenseProjectileFactory
extends RefCounted

const C = preload("res://src/features/defense/domain/defense_catalog.gd")
const Ballistics = preload("res://src/features/defense/domain/defense_ballistics.gd")
const Geometry = preload("res://src/features/defense/domain/defense_projectile_geometry.gd")
const Area = preload("res://src/features/defense/domain/defense_area.gd")
var w
var serial: int = 0

func _init(world) -> void:
	w = world

func basic(owner: Dictionary, target: Dictionary, amount: float) -> void:
	var parts = str(owner.motion.missile).split(":")
	serial += 1
	var from = w.targets.attack_point(owner)
	var to = w.targets.attack_point(target)
	w.missiles.append({"id": serial, "owner": owner.id, "target": target.id, "kind": 0,
		"pos": from, "from": from, "to": to, "start": w.time_ms, "at": w.time_ms,
		"expires": w.time_ms + 15000, "res": "battleEffect:" + parts[0],
		"scale": float(parts[1]) / 100.0, "speed": float(parts[2]), "amount": amount,
		"direction": from.direction_to(to), "ended": false, "rotation": from.direction_to(to).angle() + PI / 2,
		"radius": 10, "layer": 0, "skill": {}, "fired": false})

func launch(owner: Dictionary, target: Dictionary, definition: Dictionary, origin: Vector2, delay: int) -> void:
	var skill = definition.duplicate(true)
	if skill.has("assassination") and "109" in str(skill.get("damage_type", "")).split(";"):
		skill["visual_tint"] = "#ffe45b"
	var repeat_state: Dictionary = definition.get("repeat_state", {})
	skill.erase("repeat_state")
	var kind = int(C.number(skill.type))
	var pos: Vector2 = w.targets.attack_point(owner) if origin == Vector2.INF else origin
	var destination: Vector2 = Geometry.aim_point(target) if kind == 9 else (w.targets.attack_point(target) if target.has("motion") else target.pos)
	if kind == 6:
		destination = target.pos
	if kind in [2, 3, 6, 10, 12, 14, 15, 20, 31]:
		pos = destination if origin == Vector2.INF else origin
	var interval = maxi(16, roundi(float(skill.get("damage_interval", 0.25)) * 1000))
	var count = maxi(1, int(skill.get("damage_num", 1)))
	var life = maxf(0, C.number(skill.get("movie_effect", []), 2)) * 1000
	var wait = maxi(delay, roundi(float(skill.get("damage_delay", 0)) * 1000))
	serial += 1
	if kind == 17:
		life = 360000.0 * count / maxf(1, float(skill.get("damage_interval", 180)))
		interval = 250
	var range_data: Array = skill.get("damage_range", [])
	var base_radius = C.number(range_data[0]) if not range_data.is_empty() else 0.0
	var radius = Area.radius(base_radius, float(skill.get("radius_bonus", 0)))
	var res = ""
	if not skill.get("movie_effect", []).is_empty():
		res = str(skill.get("res", "bullet")) + ":" + str(skill.movie_effect[0])
	var direction = pos.direction_to(destination)
	if kind in [9, 4, 5, 29, 37] and int(skill.get("salvo_index", 0)) > 0:
		var index = int(skill.salvo_index)
		var angle = C.number(skill.get("parameters", []), 1)
		if angle <= 0:
			angle = 360.0 / (1 + C.number(skill.get("salvo", 0)))
		direction = direction.rotated(ceilf(index / 2.0) * angle * PI / 180.0 * (1 if index % 2 == 0 else -1))
	var shape_name = str(skill.movie_effect[0]) if not skill.get("movie_effect", []).is_empty() else ""
	var shape: Dictionary = w.combat.bullets.get(shape_name, {})
	var layer = int(C.number(skill.get("movie_effect", []), 3))
	if kind == 10:
		pos = destination + Vector2(0, -1000)
		wait += maxi(500, roundi(1000000 / maxf(1, float(skill.get("speed", 600)))))
	var p = {"id": serial, "owner": owner.id, "target": target.id, "skill": skill,
		"kind": kind, "pos": pos, "from": w.targets.attack_point(owner), "to": destination, "direction": direction,
		"start": w.time_ms + delay, "at": w.time_ms + delay + wait, "expires": w.time_ms + delay + wait + maxi(15000, int(life)),
		"remaining": count, "hit_limit": count, "interval": interval, "radius": radius, "speed": float(skill.get("speed", 600)),
		"hits": [], "ignored": [], "res": res, "scale": C.number(skill.get("movie_effect", []), 1, 1), "ended": false,
		"orbit_end": w.time_ms + delay + maxi(16, int(life)), "visual_until": 0, "hit_at": {},
		"rotation": direction.angle() + PI / 2, "shape": shape, "layer": layer,
		"allies": int(C.number(skill.type, 1, 1)) == 2, "wall": target.get("wall", false),
		"owner_offset": owner.pos - pos, "charge_end": 0,
		"forever": kind == 3 and int(skill.get("damage_num", 0)) <= 0,
		"attack_index": 0, "repeat_state": repeat_state,
		"full_radius": radius, "life": maxi(16, interval * count), "fired": false, "applied": false}
	if kind == 9:
		p.from = pos
	if kind == 31:
		if skill.get("fire_phase", "") != "charge":
			var random_angle = w.rng.stream("defense.combat").next_int(360) - int(skill.get("salvo_index", 0)) * 360.0 / (1 + C.number(skill.get("salvo", 0)))
			p.pos += Vector2(cos(random_angle * PI / 180), sin(random_angle * PI / 180)) * float(skill.get("attack_range", 0))
		p.radius = 0.0
	if kind in [29, 30]:
		for entry in skill.get("actionOth", []):
			if str(entry[0]) == "charge" and entry.size() > 1:
				p.charge_end = w.time_ms + delay + roundi(float(entry[1]) / maxf(1, p.speed) * 1000)
		if p.charge_end == 0:
			p.charge_end = p.start + floori(float(skill.get("attack_range", 0)) / maxf(1, p.speed) * 1000)
	if kind in [4, 5]:
		p.to = p.from + direction * float(shape.get("baseSize", {}).get("y", 500)) * 4.0
	if kind == 1:
		Ballistics.start(p)
	if kind == 33:
		p["fly_until"] = p.start + floori(pos.distance_to(destination) / maxf(1, p.speed) * 1000)
		p.at = p.fly_until
	if kind == 30:
		p.direction = Vector2(-owner.facing, 0)
		p.charge_end = p.start + floori(float(skill.get("attack_range", 0)) / maxf(1, p.speed) * 1000)
	p["area_life"] = maxi(16, int(life)) if life > 0 else 500
	p["travelled"] = 0.0
	if kind not in [4, 5] and C.number(skill.get("effect_change", [])) > 0:
		p.scale += maxf(0, float(skill.get("bonus_damage", 0))) * C.number(skill.effect_change, 2) / 100.0
	w.missiles.append(p)
	if kind == 6 and delay <= 0 and wait <= 0:
		if p.wall:
			w.damage.apply_wall(owner, skill)
		elif target.has("core"):
			w.projectiles.impact(p, owner, target)
		p.applied = true

