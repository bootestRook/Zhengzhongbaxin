extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Ice = preload("res://tests/test_defense_ice_terms.gd")
const Fire = preload("res://tests/test_defense_fire_terms.gd")
const Geometry = preload("res://src/features/defense/domain/defense_projectile_geometry.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
var ice = Ice.new()
var fire = Fire.new()

func run(test) -> void:
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "projectile catalog loads")
	_spreads(test, catalog)
	_order_and_sweep(test, catalog)
	_dense_and_dedupe(test, catalog)
	_refraction(test, catalog)
	_pierce_refractions(test, catalog)
	_fire_contact(test, catalog)
	_invalid_target(test, catalog)
	print("[PROJECTILES] fan, sweep, penetration, refraction and termination verified")

func body(w, center: Vector2) -> Dictionary:
	var u = ice.fixture.enemy(w, center)
	u.pos += center - Geometry.aim_point(u)
	return u

func angles(test, missiles: Array, expected: Array, label: String) -> void:
	test.assert_equal(missiles.size(), expected.size(), label + " actual emitted count")
	if missiles.is_empty():
		return
	var first: Dictionary = missiles[0]
	for i in range(missiles.size()):
		var p: Dictionary = missiles[i]
		var actual = rad_to_deg(first.direction.angle_to(p.direction))
		test.assert_true(absf(actual - expected[i]) < 0.001, label + " measured degrees " + str(i))
		test.assert_equal(p.target, first.target, label + " one primary target")
		test.assert_equal(p.start, first.start, label + " simultaneous emission")
	print("[FAN] ", label, " count=", missiles.size(), " degrees=", expected)

func _spreads(test, catalog) -> void:
	for salvo in [false, true]:
		for enemy_count in [1, 5]:
			var w = ice.world(catalog)
			var hero: Dictionary = w.units[w.heroes[0]]
			if salvo:
				ice.choose(w, 403)
			for i in range(enemy_count):
				body(w, Vector2(800 + i * 70, 950))
			test.assert_true(w.skills.cast(hero, hero.skills[20002].data, {}), "real multishot cast succeeds")
			var expected = [0, -7, 7, -14] if salvo else [0, -7, 7]
			angles(test, w.missiles, expected, "ice")
			if w.missiles.is_empty():
				w.dispose()
				continue
			var first: Dictionary = w.missiles[0]
			test.assert_true(first.direction.is_equal_approx(first.from.direction_to(Geometry.aim_point(w.units[first.target]))), "main ice arrow aims at the target body")
			var launched: Array = w.missiles.duplicate()
			w.units[first.target].pos += Vector2(300, 100)
			w.time_ms = 16
			w.projectiles.tick()
			for p in launched:
				test.assert_true((p.pos - p.from - p.direction * p.speed * 0.016).length() < 0.001, "ice moves along its launched ray without tracking")
			var visible: Array = w.snapshot().missiles
			for i in range(visible.size()):
				test.assert_true(visible[i].direction.is_equal_approx(launched[i].direction), "render snapshot preserves actual ray direction")
			w.dispose()
	for count in [1, 2, 3]:
		var w = fire.world(catalog)
		var hero: Dictionary = w.units[w.heroes[0]]
		if count > 1:
			fire.choose(w, 206)
		if count > 2:
			fire.choose(w, 207)
		body(w, Vector2(800, 950))
		w.skills.fireball.release(hero, hero.skills[17].data.fireball)
		angles(test, w.missiles, [0, -5, 5].slice(0, count), "fire")
		if w.missiles.is_empty():
			w.dispose()
			continue
		var first: Dictionary = w.missiles[0]
		test.assert_true(first.direction.is_equal_approx(first.from.direction_to(Geometry.aim_point(w.units[first.target]))), "main fireball aims at the target body")
		w.dispose()
	var empty = ice.world(catalog)
	var owner: Dictionary = empty.units[empty.heroes[0]]
	test.assert_true(not empty.skills.cast(owner, owner.skills[20002].data, {}), "no legal target prevents multishot")
	test.assert_true(empty.missiles.is_empty(), "empty target pool never creates spread rays")
	empty.dispose()

func _order_and_sweep(test, catalog) -> void:
	var w = ice.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	ice.choose(w, 402)
	# Intentionally create the far target first. A single step crosses all three.
	var far = body(w, Vector2(800, 550))
	var middle = body(w, Vector2(800, 700))
	var near = body(w, Vector2(800, 850))
	var hidden = body(w, Vector2(800, 930))
	hidden["hidden_until"] = 10000
	var outside = body(w, Vector2(950, 850))
	var p = w.skills.ice.arrow(hero, hero.skills[20002].data, far, false, {"knocked": []}, Vector2(800, 1000))
	p.speed = 40000
	w.projectiles.tick()
	test.assert_equal(p.hits, [near.id, middle.id], "high-speed hits follow contact order rather than creation order or locked target")
	test.assert_equal(U.hp(near), 99940.0, "first swept enemy takes real damage")
	test.assert_equal(U.hp(middle), 99940.0, "pierce plus one damages the second enemy")
	test.assert_equal(U.hp(far), 100000.0, "third enemy is outside the two-hit budget")
	test.assert_equal(U.hp(hidden), 100000.0, "hidden enemies are excluded from path collision")
	test.assert_equal(U.hp(outside), 100000.0, "bodies outside the swept width are not hit")
	test.assert_true(p.ended and w.missiles.is_empty(), "last allowed hit terminates immediately")
	test.assert_true(p.pos.y > middle.pos.y, "terminal position is the actual first contact, before the target center")
	w.dispose()

func _dense_and_dedupe(test, catalog) -> void:
	var w = ice.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	ice.choose(w, 402)
	var targets: Array = []
	for i in range(5):
		targets.append(body(w, Vector2(800, 800)))
	var p = w.skills.ice.arrow(hero, hero.skills[20002].data, targets[0], false, {"knocked": []}, Vector2(800, 1000))
	p.speed = 30000
	w.projectiles.tick()
	var damaged = targets.filter(func(u): return U.hp(u) < 100000).size()
	test.assert_equal(damaged, 2, "dense overlap cannot exceed one primary plus one piercing hit")
	test.assert_equal(p.hits, [targets[0].id, targets[1].id], "equal contact times use stable unit IDs")
	w.dispose()
	w = ice.world(catalog)
	hero = w.units[w.heroes[0]]
	ice.choose(w, 402)
	var target = body(w, Vector2(800, 800))
	p = w.skills.ice.arrow(hero, hero.skills[20002].data, target, false, {"knocked": []}, Vector2(800, 1000))
	ice.step(w, 500)
	test.assert_equal(p.hits, [target.id], "one physical body never consumes two piercing hits")
	test.assert_equal(U.hp(target), 99940.0, "multi-frame overlap damages the same enemy only once")
	test.assert_equal(w.missiles.size(), 1, "piercing retains the same missile instead of creating a continuation")
	test.assert_equal(w.missiles[0].id, p.id, "piercing missile identity and trajectory stay continuous")
	w.dispose()

func _refraction(test, catalog) -> void:
	var w = ice.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	for term in [401, 402, 405, 409]:
		ice.choose(w, term)
	var main = body(w, Vector2(800, 800))
	var next = body(w, Vector2(1000, 800))
	var primary = w.skills.ice.arrow(hero, hero.skills[20002].data, main, false, {"knocked": []}, Vector2(800, 1000))
	var child: Dictionary = {}
	for at in range(0, 500, 16):
		w.time_ms = at
		w.projectiles.tick()
		for p in w.missiles:
			if p.skill.ice_shot.bounced:
				child = p
		if not child.is_empty():
			break
	test.assert_true(not child.is_empty(), "real direct hit creates a real refraction missile")
	if not child.is_empty():
		var contact_y = Geometry.aim_point(main).y + float(main.motion.body_size[1]) / 2 + float(primary.shape.collisionSize.y) / 2
		test.assert_true(absf(child.from.y - contact_y) < 0.001, "refraction starts at first body contact rather than the end of the step")
		test.assert_equal(child.hit_limit, 1, "refraction never inherits the primary piercing budget")
		test.assert_equal(child.ignored, [main.id], "child ignores the body that generated it")
		test.assert_true(child.ice_group == primary.ice_group, "refraction shares the original knockback budget")
	ice.step(w, 2000)
	test.assert_equal(U.hp(main), 99910.0, "direct star arrow deals its actual inherited ninety-percent damage")
	test.assert_equal(U.hp(next), 99910.0, "refraction deals equal inherited damage to another enemy")
	test.assert_equal(next.statuses[0].stacks, 1, "refraction applies chill once")
	test.assert_true(w.missiles.is_empty() and w.skills.queue.is_empty(), "refraction and piercing finish without recursion")
	w.dispose()

func _invalid_target(test, catalog) -> void:
	var w = ice.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	var target = body(w, Vector2(800, 500))
	var blocker = body(w, Vector2(800, 800))
	var p = w.skills.ice.arrow(hero, hero.skills[20002].data, target, false, {"knocked": []}, Vector2(800, 1000))
	target.dead = true
	ice.step(w, 500)
	test.assert_equal(p.hits, [blocker.id], "target death leaves the emitted ray able to hit another body")
	test.assert_equal(U.hp(blocker), 99950.0, "unlocked path interception applies real damage")
	w.dispose()

func _pierce_refractions(test, catalog) -> void:
	var w = ice.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	for term in [401, 402, 405, 409]:
		ice.choose(w, term)
	var first = body(w, Vector2(800, 800))
	var second = body(w, Vector2(800, 600))
	body(w, Vector2(1000, 780))
	var main = w.skills.ice.arrow(hero, hero.skills[20002].data, first, false, {"knocked": []}, Vector2(800, 1000))
	var children: Dictionary = {}
	for at in range(0, 2000, 16):
		w.time_ms = at
		w.projectiles.tick()
		for p in w.missiles:
			if p.skill.ice_shot.bounced:
				children[p.id] = p
	test.assert_equal(main.hits, [first.id, second.id], "star primary pierces two different bodies")
	test.assert_equal(children.size(), 2, "each direct piercing contact creates exactly one refraction")
	for child in children.values():
		test.assert_true(child.hits.size() <= 1, "each refraction has its own one-hit cap")
	test.assert_true(w.missiles.is_empty(), "all primary and derived paths terminate")
	w.dispose()

func _fire_contact(test, catalog) -> void:
	var w = fire.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	var enemy = body(w, Vector2(800, 950))
	w.skills.fireball.release(hero, hero.skills[17].data.fireball)
	var main: Dictionary = w.missiles[0]
	var target_at_impact: Vector2 = enemy.pos
	main.speed = 40000
	w.projectiles.tick()
	var blasts = w.missiles.filter(func(p): return p.skill.get("fire_phase", "") == "blast")
	test.assert_equal(blasts.size(), 1, "one fireball collision produces one explosion")
	if not blasts.is_empty():
		test.assert_equal(blasts[0].pos, target_at_impact, "explosion freezes the hit target position at impact")
		test.assert_true(blasts[0].pos != main.pos, "explosion does not use the projectile contact point")
	w.dispose()
