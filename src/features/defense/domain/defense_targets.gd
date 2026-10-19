class_name DefenseTargets
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
const C = preload("res://src/features/defense/domain/defense_catalog.gd")
const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")
const Statue = preload("res://src/features/defense/domain/defense_statue.gd")
var w
var definitions: Dictionary
var score_cache: Dictionary = {}

func _init(world) -> void:
	w = world
	definitions = w.catalog.records("targets")

func nearest(source: Dictionary, distance: float, allies: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var best_distance = distance * distance
	for u: Dictionary in w.units.values():
		if u.dead or (u.side == source.side) != allies or u.id == source.id or hidden_enemy(source, u):
			continue
		var d: float = source.pos.distance_squared_to(u.pos)
		if d < best_distance or (d == best_distance and (best.is_empty() or u.id < best.id)):
			best = u
			best_distance = d
	return best

func select(source: Dictionary, skill: Dictionary, previous: Dictionary = {}, fire_index: int = 0, origin: Vector2 = Vector2.INF) -> Array:
	var aim: Array = skill.get("aim", [])
	if aim.is_empty():
		return []
	var index = 0
	if fire_index > 0 and not has_combat_trigger(skill):
		index = w.rng.stream("defense.combat").next_int(aim.size())
	var point = attack_point(source) if origin == Vector2.INF else origin
	source = source.duplicate()
	source.pos = point
	source["selection_point"] = point
	score_cache.erase(source.id)
	return select_rule(source, skill, definitions[str(int(aim[index]))], previous)

func select_rule(source: Dictionary, skill: Dictionary, rule: Dictionary, previous: Dictionary, exclude: Array = []) -> Array:
	var camp = int(rule.get("targetCamp", 0))
	var type = int(C.number(rule.get("type", [8])))
	if type == 5:
		var owner: Dictionary = w.units[source.id]
		return [owner] if matches(owner, rule) else []
	if type == 6:
		return [Statue.TARGET]
	if type == 12:
		var pos: Vector2 = source.get("selection_point", attack_point(source))
		return [{"id": 0, "pos": pos, "dead": false}]
	if type in [10, 11]:
		var corpse: Dictionary = {}
		var priority = 0
		for id in w.heroes:
			var hero: Dictionary = w.units[id]
			if not hero.dead:
				continue
			var value = int(hero.revive_at - w.time_ms) if type == 10 else int(hero.active_level)
			if value > priority:
				priority = value
				corpse = hero
		return [] if corpse.is_empty() else [corpse]
	var radius = maxf(0, float(skill.get("attack_range", 0)))
	if type == 7:
		var angle = w.rng.stream("defense.combat").next_int(360) * PI / 180.0
		var pos: Vector2 = source.pos + Vector2(cos(angle), sin(angle)) * radius
		return [{"id": 0, "pos": Vector2(clampf(pos.x, w.combat.world.left, w.combat.world.right), clampf(pos.y, 0, w.combat.world.bottom)), "dead": false}]
	var pool: Array = []
	for u: Dictionary in w.units.values():
		if exclude.has(u.id):
			continue
		if u.dead or hidden_enemy(source, u):
			continue
		if (camp == 1 and (u.side != source.side or u.id == source.id)) or (camp == 2 and u.side == source.side):
			continue
		if source.pos.distance_to(u.pos) > radius or not matches(u, rule):
			continue
		pool.append(u)
	if skill.has("assassination") and w.guard.applies(source):
		var rear = pool.filter(func(u): return w.guard.behind(source, u))
		if not rear.is_empty():
			pool = rear
	pool.sort_custom(func(a, b):
		if type in [3, 4]:
			var ah = U.hp(a) if type == 3 else U.stat(a, 1) - U.hp(a)
			var bh = U.hp(b) if type == 3 else U.stat(b, 1) - U.hp(b)
			if not is_equal_approx(ah, bh):
				return ah > bh
		var da: float = score(source, a) if source.kind == "hero" and type in [1, 8] else source.pos.distance_squared_to(a.pos)
		var db: float = score(source, b) if source.kind == "hero" and type in [1, 8] else source.pos.distance_squared_to(b.pos)
		return (da > db if type in [2, 9, 11] else da < db) if da != db else a.id < b.id)
	var extra = int(skill.get("extra_targets", 0))
	var candidates = maxi(1, int(C.number(rule.get("random", "1:1"))) + extra)
	var count = maxi(1, int(C.number(rule.get("random", "1:1"), 1, 1)) + extra)
	if has_combat_trigger(skill):
		candidates += maxi(0, int(U.stat(source, 5)) - 1)
		count += maxi(0, int(U.stat(source, 5)) - 1)
	var ranges: Array = skill.get("damage_range", [])
	var area_radius = C.number(ranges[0]) if not ranges.is_empty() else 0.0
	if candidates > count and area_radius > 0 and pool.size() < 100:
		pool.sort_custom(func(a, b): return area(source, a.pos, area_radius).size() > area(source, b.pos, area_radius).size())
	pool = pool.slice(0, mini(candidates, pool.size()))
	if candidates > 1 or count > 1:
		w.rng.stream("defense.combat").shuffle(pool)
	return pool.slice(0, mini(count, pool.size()))

func hidden_enemy(source: Dictionary, target: Dictionary) -> bool:
	return source.side != target.side and int(target.get("hidden_until", 0)) > w.time_ms

func matches(u: Dictionary, rule: Dictionary) -> bool:
	for id in rule.get("notargetStatus", []):
		if w.statuses.has_status(u, int(id)):
			return false
	for id in rule.get("targetStatus", []):
		if w.statuses.has_status(u, int(id)):
			break
		if id == rule.targetStatus.back():
			return false
	if not rule.get("targetEntity", []).is_empty() and not rule.targetEntity.has(u.template):
		return false
	if rule.get("notargetEntity", []).has(u.template):
		return false
	var hp: Array = rule.get("targetHp", [])
	if hp.size() >= 2:
		var percent = U.hp(u) / maxf(1, U.stat(u, 1)) * 100
		if percent < float(hp[0]) or percent > float(hp[1]):
			return false
	var classes: Array = rule.get("targetClass", [])
	if not classes.is_empty():
		var found = false
		for value in classes:
			found = found or u.class.has(value)
		if not found:
			return false
	return true

static func attack_point(u: Dictionary) -> Vector2:
	var offset: Array = u.motion.get("attack_offset", [0, 0])
	return u.pos + Vector2(offset[0] * u.facing, offset[1])

static func has_combat_trigger(skill: Dictionary) -> bool:
	for entry in skill.get("triggerOpp", []):
		if int(C.number(entry)) == 18:
			return true
	return false

func score(source: Dictionary, target: Dictionary) -> float:
	if not score_cache.has(source.id):
		score_cache[source.id] = {}
	var cached: Dictionary = score_cache[source.id]
	if cached.has(target.id):
		return cached[target.id]
	var weights: Dictionary = w.combat.target_score
	var value: float = source.pos.distance_squared_to(target.pos) * weights.distance1 / 100.0
	value += source.home.distance_squared_to(target.pos) * weights.distance2 / 100.0
	value += Statue.BODY_CENTER.distance_squared_to(target.pos) * weights.distance3 / 100.0
	var row_count = 0
	for id in w.heroes:
		if w.units[id].front == source.front:
			row_count += 1
	var penalty = false
	if row_count == 2:
		penalty = target.pos.x >= 800 if source.row_index == 0 else target.pos.x <= 800
	elif row_count >= 3:
		var index = clampi(source.row_index, 0, row_count - 1)
		var low = 350 + index * 900.0 / row_count
		var high = low + 900.0 / row_count
		penalty = target.pos.x < low or target.pos.x >= high
	value += float(weights.distance4) if penalty else 0.0
	if target.kind == "boss":
		value += weights.distance5
	else:
		var attackers = maxi(0, int(w.space.attackers.get(target.id, 0)) - (1 if source.target == target.id else 0))
		value += attackers * weights.distance7
		if target.blocked_by > 0 and target.blocked_by != source.id:
			value += weights.distance6
	cached[target.id] = value
	return value

func basic_target_allowed(source: Dictionary, target: Dictionary) -> bool:
	if source.kind != "hero" or source.front:
		return true
	return Geometry.reaches(source, target) or (target.kind == "boss" and can_finish_chase())

func patrol(source: Dictionary) -> Dictionary:
	if w.guard.applies(source) and not source.entering:
		return w.guard.choose_enemy(source)
	var boss: Dictionary = w.units.get(source.force_boss, {})
	if not boss.is_empty() and not boss.dead and Geometry.intersects(source, boss):
		return boss
	source.force_boss = 0
	var best: Dictionary = {}
	var best_score = INF
	var direct: Dictionary = {}
	var direct_score = INF
	for u: Dictionary in w.units.values():
		if u.dead or u.side == source.side or hidden_enemy(source, u):
			continue
		if source.get("entering", false) and not Geometry.reaches(source, u):
			continue
		if not basic_target_allowed(source, u):
			continue
		var value = score(source, u)
		if Geometry.reaches(source, u) and value < direct_score:
			direct = u
			direct_score = value
		if value < best_score:
			best_score = value
			best = u
	if not direct.is_empty() and (best.is_empty() or not Geometry.intersects(source, best)):
		return direct
	return best

func can_finish_chase() -> bool:
	var alive = 0
	var boss = false
	var waiting = w.spawn_wave >= w.level.waves.size()
	for u: Dictionary in w.units.values():
		if u.side == 2 and not u.dead:
			alive += 1
			if u.kind == "boss":
				boss = true
				waiting = waiting or w.spawn_wave - u.wave >= 5
	return waiting and boss and alive <= 8

func nearest_blocker(source: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var distance = INF
	for u: Dictionary in w.units.values():
		if u.side == source.side or u.dead or U.stat(u, 3) <= 0 or hidden_enemy(source, u):
			continue
		var value: float = source.pos.distance_squared_to(u.pos)
		if value < distance:
			distance = value
			best = u
	return best

func area(source: Dictionary, pos: Vector2, radius: float, allies: bool = false) -> Array:
	var result: Array = []
	for u: Dictionary in w.units.values():
		if not u.dead and (u.side == source.side) == allies and u.pos.distance_to(pos) <= radius + u.body_radius:
			result.append(u)
	return result
