extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Area = preload("res://src/features/defense/domain/defense_area.gd")
const TERMS = [501, 501, 502, 503, 504, 505, 506, 507, 508]

func normalize(unit: Dictionary) -> void:
	for pair in [["1", 100000], ["hp", 100000], ["4", 100], ["7", 0], ["10", 0], ["11", 0], ["12", 0], ["15", 0], ["16", 0], ["19", 0], ["20", 0], ["27", 0], ["28", 0], ["29", 0], ["31", 0]]:
		unit.core.attributes.set_value(pair[0], pair[1])
	unit.traits.clear()

func world(catalog):
	var w = Session.new(catalog)
	w.start(53)
	w.factory.add_hero(17)
	w.phase = "playing"
	w.stage = 19
	w.spawn_wave = 20
	normalize(w.units[w.heroes[0]])
	return w

func enemy(w, pos: Vector2, kind: String = "enemy") -> Dictionary:
	var unit = w.factory.create(kind, 101, pos, 2)
	normalize(unit)
	return unit

func choose(w, term: int) -> void:
	w.offers = [w.choices.card(w.catalog.record("options", 200000 + term), w.heroes[0])]
	w.phase = "choice"
	assert(w.choices.choose(0).is_empty(), "assassin term must be acquired through the legal choice interface")

func cast(w) -> bool:
	var owner: Dictionary = w.units[w.heroes[0]]
	return w.skills.cast(owner, owner.skills[1435].data, {})

func run(test) -> void:
	var c = Catalog.new()
	c.load_default()
	_library(test, c)
	_damage(test, c)
	_control(test, c)
	_area_scaling(test, c)
	_hunt(test, c)
	_execute(test, c)
	_shock(test, c)
	_edges(test, c)
	_weights(test, c)

func _library(test, c) -> void:
	var w = world(c)
	var owner: Dictionary = w.units[w.heroes[0]]
	test.assert_equal(owner.upgrades, [200500], "recruitment grants only assassination")
	var ids: Array = w.choices.upgrade_pool().map(func(o): return o.id)
	ids.sort()
	test.assert_equal(ids, [200501, 200502, 200503, 200504, 200507], "five initial upgrades are eligible")
	for id in [614, 615, 616, 617, 621, 631, 632, 633]:
		test.assert_true(c.record("options", id).is_empty(), "old assassination branch removed")
	test.assert_true(not w.skills.ready_action(owner), "empty battlefield preserves cooldown")
	test.assert_equal(owner.skills[1435].next, 0, "no target does not consume cooldown")
	choose(w, 501)
	test.assert_true(not w.choices.eligible(c.record("options", 200508), owner), "execution needs both prerequisites")
	for term in [502, 506]:
		choose(w, term)
	test.assert_true(w.choices.eligible(c.record("options", 200508), owner), "one damage rank plus hunt unlocks execution")
	for term in [501, 503, 504, 505, 507, 508]:
		choose(w, term)
	test.assert_equal(w.selected["200501"], 2, "damage has two ranks")
	test.assert_true(w.choices.upgrade_pool().is_empty(), "all terms respect their caps")
	test.assert_equal(owner.skills[1435].data.assassination.damage_percent, 460.0, "two ranks give 460 percent")
	test.assert_equal(c.record("skills", 1435).assassination.damage_percent, 300, "static definition stays immutable")
	w.start(54)
	w.factory.add_hero(17)
	test.assert_true(not w.units[w.heroes[0]].skills[1435].get("hunt_ready", false), "new run clears instance hunt state")
	w.dispose()

func _damage(test, c) -> void:
	var w = world(c)
	var owner: Dictionary = w.units[w.heroes[0]]
	var target = enemy(w, owner.pos + Vector2(100, -100))
	for expected in [300.0, 380.0, 460.0]:
		var before = U.hp(target)
		cast(w)
		test.assert_equal(before - U.hp(target), expected, "real hp uses additive damage coefficients")
		if expected < 460:
			choose(w, 501)
	choose(w, 502)
	var before = U.hp(target)
	cast(w)
	test.assert_equal(before - U.hp(target), 920.0, "combo deals two full hits to same target")
	test.assert_equal(owner.pos, target.pos, "cast teleports to chosen target")
	test.assert_true(w.skills.ready_action(owner), "real scheduler starts skill")
	test.assert_equal(owner.skills[1435].next, 8000, "real scheduler starts eight second cooldown")
	for ms in range(16, 1217, 16):
		w.time_ms = ms
		w.skills.tick()
	test.assert_true(U.hp(target) < before - 920, "scheduled action executes real damage")
	w.dispose()

func _control(test, c) -> void:
	var w = world(c)
	var owner: Dictionary = w.units[w.heroes[0]]
	var target = enemy(w, owner.pos)
	var near = enemy(w, owner.pos + Vector2(180, 0))
	var smoke_only = enemy(w, owner.pos + Vector2(240, 0))
	var outside = enemy(w, owner.pos + Vector2(500, 0))
	for term in [503, 504, 505]:
		choose(w, term)
	cast(w)
	test.assert_equal(U.hp(target), 99500.0, "primary, smoke, fan each apply exactly once")
	test.assert_equal(U.hp(near), 99800.0, "nearby target receives smoke and fan only")
	test.assert_equal(U.hp(smoke_only), 99900.0, "outer ring receives smoke only")
	test.assert_equal(U.hp(outside), 100000.0, "outside target is unaffected")
	test.assert_equal(U.stat(target, 15), -50.0, "smoke reduces actual accuracy")
	for action in ["move", "attack", "skill"]:
		test.assert_true(w.statuses.prevents(target, action), "paralysis blocks all three actions")
	test.assert_true(not w.skills.cast(target, c.record("skills", 1435), owner), "paralyzed target cannot cast even through public API")
	w.time_ms = 1000
	w.statuses.tick()
	test.assert_true(not w.statuses.prevents(near, "move"), "fan paralysis ends at one second")
	test.assert_true(w.statuses.prevents(target, "move"), "fan does not shorten primary two-second paralysis")
	w.time_ms = 2000
	w.statuses.tick()
	test.assert_true(not w.statuses.prevents(target, "attack"), "primary paralysis ends at two seconds")
	w.time_ms = 4000
	w.statuses.tick()
	test.assert_equal(U.stat(target, 15), 0.0, "smoke expires at four seconds")
	w.dispose()

func _area_scaling(test, c) -> void:
	var w = world(c)
	var owner: Dictionary = w.units[w.heroes[0]]
	choose(w, 504)
	w.gems.active = [c.record("gems", 282)]
	var primary = enemy(w, owner.pos)
	var smoke_only = enemy(w, owner.pos + Vector2(340, 0))
	var outside = enemy(w, owner.pos + Vector2(390, 0))
	var modified: Dictionary = w.gems.modify_skill(owner, owner.skills[1435].data)
	test.assert_true(absf(float(modified.assassination.smoke_radius) - Area.radius(250.0, 100.0)) < 0.000001,
		"smoke area percentage uses the square-root radius formula")
	cast(w)
	test.assert_equal(U.hp(primary), 99600.0, "primary still receives the assassination and smoke hits")
	test.assert_equal(U.hp(smoke_only), 99900.0, "expanded smoke reaches its circular outer target")
	test.assert_equal(U.hp(outside), 100000.0, "expanded smoke excludes targets outside its circular radius")
	w.dispose()

func _hunt(test, c) -> void:
	var w = world(c)
	var owner: Dictionary = w.units[w.heroes[0]]
	for term in [501, 501, 502, 506]:
		choose(w, term)
	var target = enemy(w, owner.pos)
	target.core.attributes.set_value("hp", 500)
	owner.skills[1435].next = 8000
	cast(w)
	test.assert_true(target.dead, "combo kill is real")
	test.assert_equal(owner.skills[1435].next, 0, "combo kill resets actual cooldown")
	test.assert_true(owner.skills[1435].hunt_ready, "kill arms next cast bonus")
	var second = enemy(w, owner.pos)
	cast(w)
	test.assert_equal(U.hp(second), 98980.0, "next cast gives two 510-percent hits")
	test.assert_true(not owner.skills[1435].hunt_ready, "next cast consumes bonus once")
	cast(w)
	test.assert_equal(U.hp(second), 98060.0, "later cast returns to two 460-percent hits")
	for term in [503, 504, 505, 507]:
		choose(w, term)
	second.core.attributes.set_value("hp", 100000)
	second.pos = owner.pos + Vector2(0, -300)
	var collateral = enemy(w, second.pos + Vector2(0, -240))
	collateral.core.attributes.set_value("hp", 50)
	owner.skills[1435].next = 8000
	cast(w)
	test.assert_true(collateral.dead, "smoke kills outer-ring target")
	test.assert_equal(owner.skills[1435].next, 8000, "smoke kill cannot reset cooldown")
	test.assert_true(not owner.skills[1435].hunt_ready, "collateral kill cannot arm hunt")
	w.damage.basic_hit(owner, second, 100)
	second.core.attributes.set_value("hp", 20)
	w.time_ms = 1000
	w.statuses.tick()
	test.assert_true(second.dead, "shock periodic damage kills target")
	test.assert_equal(owner.skills[1435].next, 8000, "shock kill cannot reset cooldown")
	w.dispose()

func _execute(test, c) -> void:
	for kind in ["enemy", "elite", "boss"]:
		var w = world(c)
		var owner: Dictionary = w.units[w.heroes[0]]
		for term in [501, 502, 506, 508]:
			choose(w, term)
		var target = enemy(w, owner.pos, kind)
		target.core.attributes.set_value("10", 100)
		target.core.attributes.set_value("hp", 20200)
		owner.skills[1435].next = 8000
		cast(w)
		if kind == "enemy":
			test.assert_true(target.dead, "ordinary target crosses threshold after damage and is executed")
			test.assert_equal(owner.stats.damage, 20200.0, "execution credits remaining hp to assassin")
			test.assert_equal(target.stats.taken, 20200.0, "execution taken damage matches hp removed")
			test.assert_equal(w.kills, 1, "execution uses ordinary death accounting")
			test.assert_equal(owner.skills[1435].next, 0, "execution kill resets cooldown")
		else:
			test.assert_true(not target.dead, "elite and boss cannot be executed")
			test.assert_equal(U.hp(target), 17920.0, "elite and boss ignore armor and take three times each final hit")
		w.dispose()
	var w = world(c)
	for term in [501, 502, 506, 508]:
		choose(w, term)
	var target = enemy(w, w.units[w.heroes[0]].pos)
	target.core.attributes.set_value("hp", 20760)
	cast(w)
	test.assert_true(not target.dead, "exactly twenty percent is not below threshold")
	test.assert_equal(U.hp(target), 20000.0, "both hits ignore ordinary armor without premature execution")
	w.dispose()

func _shock(test, c) -> void:
	var w = world(c)
	var owner: Dictionary = w.units[w.heroes[0]]
	choose(w, 507)
	var target = enemy(w, owner.pos)
	cast(w)
	test.assert_true(not w.statuses.has_status(target, 20503), "skill hits do not apply basic-only shock")
	for i in range(7):
		w.damage.basic_hit(owner, target, 1)
	test.assert_equal(target.statuses[0].stacks, 5, "shock caps at five stacks")
	var before = U.hp(target)
	for ms in [1000, 2000, 3000, 4000, 5000]:
		w.time_ms = ms
		w.statuses.tick()
	test.assert_equal(before - U.hp(target), 750.0, "five layers deal 150 per second including final fifth tick")
	w.time_ms = 5016
	w.statuses.tick()
	test.assert_true(not w.statuses.has_status(target, 20503), "shock clears after final tick")
	w.damage.basic_hit(owner, target, 1)
	w.time_ms = 5500
	w.damage.basic_hit(owner, target, 1)
	test.assert_equal(target.statuses[0].next, 6016, "refresh preserves periodic cadence")
	test.assert_equal(target.statuses[0].expires, 10500, "refresh extends duration to five seconds")
	w.dispose()

func _weights(test, c) -> void:
	for mode in ["ordinary", "bonus", "chest"]:
		var w = world(c)
		var counts = {200501: 0, 200502: 0, 200503: 0, 200504: 0, 200507: 0}
		for i in range(1200):
			var item: Dictionary
			if mode == "chest":
				item = w.loot.roll()
			else:
				item = w.choices.roll_upgrade(w.rng.stream("defense.choice"), [], w.heroes[0] if mode == "bonus" else 0)
			counts[item.id] += 1
		test.assert_true(counts[200501] > counts[200507] * 2, "explicit damage weight exceeds shock in each draw mode")
		print("[ASSASSIN WEIGHTS] ", mode, " ", counts)
		w.dispose()

func _edges(test, c) -> void:
	var w = world(c)
	var owner: Dictionary = w.units[w.heroes[0]]
	for term in [501, 502, 503, 505, 506, 507, 508]:
		choose(w, term)
	owner.skills[1435]["hunt_ready"] = true
	test.assert_true(not cast(w), "no legal target rejects cast")
	test.assert_true(owner.skills[1435].hunt_ready, "failed cast does not consume hunt")
	var target = enemy(w, owner.pos + Vector2(0, -300))
	var collateral = enemy(w, target.pos + Vector2(0, -180))
	collateral.core.attributes.set_value("hp", 50)
	owner.skills[1435]["hunt_ready"] = false
	owner.skills[1435].next = 8000
	cast(w)
	test.assert_true(collateral.dead, "fan really kills peripheral target")
	test.assert_equal(owner.skills[1435].next, 8000, "fan kill cannot reset cooldown")
	test.assert_true(not owner.skills[1435].hunt_ready, "fan kill cannot grant next damage bonus")
	test.assert_equal(U.hp(target), 99140.0, "fan remains 100 percent alongside two enhanced 380-percent hits")
	target.core.attributes.set_value("16", 100)
	target.core.attributes.set_value("hp", 1000)
	var before = U.hp(target)
	cast(w)
	test.assert_equal(U.hp(target), before, "dodged assassination cannot execute low-life target")
	w.damage.basic_hit(owner, target, 1)
	test.assert_true(not w.statuses.has_status(target, 20503), "dodged basic attack cannot apply shock")
	target.core.attributes.set_value("16", 0)
	w.damage.basic_hit(owner, target, 1)
	w.damage.defeat(owner, {})
	w.time_ms = 1000
	before = U.hp(target)
	w.statuses.tick()
	test.assert_equal(before - U.hp(target), 30.0, "applied shock continues after assassin death")
	w.dispose()
