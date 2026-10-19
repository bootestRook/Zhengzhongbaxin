extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Fire = preload("res://tests/test_defense_fire_terms.gd")
const Geometry = preload("res://src/features/defense/domain/defense_projectile_geometry.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Area = preload("res://src/features/defense/domain/defense_area.gd")
var fire = Fire.new()

func run(test) -> void:
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "fire center catalog loads")
	for expanded in [false, true]:
		for invalidate in ["move", "death"]:
			_ordinary(test, catalog, expanded, invalidate)
	_pyro(test, catalog)
	print("[FIRE CENTERS] target snapshots, delayed effects and real circular damage checked")

func kind(p: Dictionary) -> String:
	if p.skill.get("fireball_ember", false):
		return "ember"
	if p.skill.get("fire_phase", "") == "blast":
		return "secondary" if p.skill.get("fire_secondary", false) else "main"
	return ""

func body(w, center: Vector2) -> Dictionary:
	var u = fire.fixture.enemy(w, center)
	u.pos += center - Geometry.aim_point(u)
	return u

func probes(w, center: Vector2, radius: float, secondary_radius: float, secondary: bool, old_point: Vector2) -> Dictionary:
	var result: Dictionary = {}
	for spec in [["in", radius, -0.25], ["out", radius, 0.25]]:
		var u = fire.fixture.enemy(w, center)
		u.pos = center + Vector2(float(spec[1]) + u.body_radius + float(spec[2]), 0)
		result[spec[0]] = u
	if secondary:
		for spec in [["secondary_in", -0.25], ["secondary_out", 0.25]]:
			var u = fire.fixture.enemy(w, center)
			u.pos = center + Vector2(secondary_radius + u.body_radius + float(spec[1]), 0)
			result[spec[0]] = u
	var axis = center.direction_to(old_point)
	for spec in [["target_only", center, -axis], ["contact_only", old_point, axis]]:
		var u = fire.fixture.enemy(w, center)
		u.pos = spec[1] + spec[2] * (radius + u.body_radius - 0.25)
		result[spec[0]] = u
	return result

func centers(test, w, expected: Dictionary, radius: float, secondary_radius: float, secondary: bool, label: String) -> Dictionary:
	var result: Dictionary = {}
	for id in expected:
		result[id] = {}
	for p in w.missiles:
		var phase = kind(p)
		if phase.is_empty() or not expected.has(p.target):
			continue
		result[p.target][phase] = p
	for id in expected:
		var effects: Dictionary = result[id]
		test.assert_equal(effects.size(), 3 if secondary else 2, label + " exactly one effect of each selected kind")
		for phase in effects:
			var p: Dictionary = effects[phase]
			test.assert_equal(p.pos, expected[id], label + " " + phase + " uses target position at impact")
			var expected_radius = secondary_radius if phase == "secondary" else radius
			test.assert_true(absf(p.radius - expected_radius) < 0.000001, label + " " + phase + " actual radius")
			var visible = w.snapshot().missiles.filter(func(item): return item.id == p.id)
			test.assert_true(visible.size() == 1 and visible[0].pos == expected[id], label + " " + phase + " rendering center matches damage center")
	return result

func damage(test, ring: Dictionary, main: float, secondary: float, ember: float, label: String) -> void:
	test.assert_equal(100000 - U.hp(ring["in"]), main + secondary + ember, label + " inside main and ember boundary")
	test.assert_equal(100000 - U.hp(ring["out"]), secondary, label + " outside main and ember boundary")
	if ring.has("secondary_in"):
		test.assert_equal(100000 - U.hp(ring.secondary_in), secondary, label + " inside expanded secondary boundary")
		test.assert_equal(U.hp(ring.secondary_out), 100000.0, label + " outside expanded secondary boundary")

func stable(test, effects: Dictionary, expected: Vector2, label: String) -> void:
	for phase in effects:
		test.assert_equal(effects[phase].pos, expected, label + " " + phase + " never follows the target after impact")

func _ordinary(test, catalog, expanded: bool, invalidate: String) -> void:
	var w = fire.world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	for term in ([201, 202, 204, 205] if expanded else [201, 204]):
		fire.choose(w, term)
	var aimed = fire.fixture.enemy(w, Vector2(800, 950))
	w.skills.fireball.release(owner, owner.skills[17].data.fireball)
	var projectile: Dictionary = w.missiles[0]
	var blocker = body(w, projectile.from + projectile.direction * 120)
	var captured: Vector2 = blocker.pos
	projectile.speed = 40000
	w.projectiles.tick()
	test.assert_equal(projectile.hits, [blocker.id], "ordinary fireball explodes on the first actual body, before its original target")
	test.assert_true(captured != aimed.pos and captured.distance_to(projectile.pos) > 1, "fixture separates target, aim and projectile contact coordinates")
	var radius = Area.radius(150.0, 80.0 if expanded else 0.0)
	var secondary_radius = Area.radius(150.0, 110.0) if expanded else 0.0
	var all_effects = centers(test, w, {blocker.id: captured}, radius, secondary_radius, expanded, "ordinary")
	var effects: Dictionary = all_effects[blocker.id]
	var ring = probes(w, captured, radius, secondary_radius, expanded, projectile.pos)
	if invalidate == "move":
		blocker.pos += Vector2(-300, -400)
	else:
		w.damage.defeat(blocker, owner)
	fire.step(w, 0)
	damage(test, ring, 200, 0, 0, "ordinary main")
	test.assert_equal(100000 - U.hp(ring.target_only), 200.0, "main blast reaches the target-centered edge beyond the old contact circle")
	test.assert_equal(U.hp(ring.contact_only), 100000.0, "main blast does not use the obsolete projectile-centered circle")
	stable(test, effects, captured, "after target " + invalidate)
	if expanded:
		fire.step(w, int(effects.secondary.at))
		damage(test, ring, 200, 100, 0, "ordinary delayed secondary")
		stable(test, effects, captured, "delayed secondary")
	for i in range(1, 4):
		fire.step(w, i * 1000)
		damage(test, ring, 200, 100 if expanded else 0, i * 100, "ordinary ember tick " + str(i))
		stable(test, effects, captured, "ember")
	print("[FIRE CENTER CASE] radius=", radius, " target=", captured, " old_contact=", projectile.pos, " after=", invalidate)
	w.dispose()

func _pyro(test, catalog) -> void:
	var w = fire.world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	for term in [201, 202, 204, 205, 210]:
		fire.choose(w, term)
	var aimed = fire.fixture.enemy(w, Vector2(800, 950))
	w.skills.fireball.release(owner, owner.skills[17].data.fireball)
	var projectile: Dictionary = w.missiles[0]
	aimed.pos += projectile.from + projectile.direction * 1000 - Geometry.aim_point(aimed)
	var targets: Array = []
	var captured: Dictionary = {}
	for distance in [140, 450, 760]:
		var u = body(w, projectile.from + projectile.direction * distance)
		targets.append(u)
		captured[u.id] = u.pos
	projectile.speed = 70000
	w.projectiles.tick()
	test.assert_equal(projectile.hits, targets.map(func(u): return u.id), "pyroblast contacts three bodies in actual flight order")
	test.assert_true(projectile.ended and not projectile.hits.has(aimed.id), "pyroblast ends at its third actual hit before the original target")
	var radius = Area.radius(150.0, 80.0)
	var secondary_radius = Area.radius(150.0, 110.0)
	var all_effects = centers(test, w, captured, radius, secondary_radius, true, "pyroblast")
	var rings: Array = []
	for u in targets:
		rings.append(probes(w, captured[u.id], radius, secondary_radius, true, captured[u.id] + Vector2(0, 60)))
		u.pos += Vector2(-300, 40)
	w.damage.defeat(targets[1], owner)
	fire.step(w, 0)
	for ring in rings:
		damage(test, ring, 200, 0, 0, "pyro main")
	fire.step(w, 320)
	for ring in rings:
		damage(test, ring, 200, 100, 0, "pyro secondary")
	for i in range(1, 4):
		fire.step(w, i * 1000)
		for ring in rings:
			damage(test, ring, 200, 100, i * 100, "pyro ember " + str(i))
		for id in captured:
			stable(test, all_effects[id], captured[id], "pyro independent anchor " + str(id))
	print("[PYRO CENTERS] hits=", projectile.hits, " target_snapshots=", captured)
	w.dispose()
