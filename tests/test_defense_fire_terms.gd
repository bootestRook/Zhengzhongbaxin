extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Fixture = preload("res://tests/test_defense_hero_skill_contracts.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Area = preload("res://src/features/defense/domain/defense_area.gd")
var fixture = Fixture.new()

func world(catalog):
	var w = fixture.world(catalog, 1)
	var hero: Dictionary = w.units[w.heroes[0]]
	for pair in [["4", 100], ["7", 0], ["10", 0], ["12", 0], ["1", 1000], ["hp", 1000]]:
		hero.core.attributes.set_value(pair[0], pair[1])
	return w

func choose(w, id: int) -> void:
	w.pending.clear()
	w.offers = [w.choices.card(w.catalog.record("options", id), w.heroes[0])]
	w.phase = "choice"
	assert(w.choices.choose(0).is_empty())

func step(w, at: int) -> void:
	w.time_ms = at
	w.skills.tick()
	w.projectiles.tick()
	w.statuses.tick()

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_library(test, catalog)
	_targets(test, catalog)
	_damage(test, catalog)
	_secondary(test, catalog)
	_shield(test, catalog)
	_weights(test, catalog)
	preload("res://tests/test_defense_fire_periodic.gd").new().run(test, catalog, self)

func _library(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	test.assert_equal(hero.upgrades, [200], "fire recruitment grants only term 200")
	var pool: Array = w.choices.upgrade_pool().map(func(o): return o.id)
	pool.sort()
	test.assert_equal(pool, [201, 202, 206, 208, 209], "exact five initial legal fire upgrades")
	for id in [1, 6, 7, 8, 9, 10, 11, 12, 13]:
		test.assert_true(catalog.record("options", id).is_empty(), "obsolete fire option removed")
	choose(w, 201)
	test.assert_true(not w.choices.eligible(catalog.record("options", 210), hero), "pyroblast needs both prerequisites")
	choose(w, 202)
	for id in [203, 204, 205, 206, 207, 208, 209, 210]:
		choose(w, id)
	test.assert_equal(hero.upgrades.size(), 11, "all eleven terms remain owned")
	test.assert_true(w.choices.upgrade_pool().is_empty(), "every fire term is once per run")
	var config: Dictionary = hero.skills[17].data.fireball
	test.assert_equal(config.blast_bonus, 190.0, "explosion bonuses add to 290 percent total")
	test.assert_equal(config.copies, 3.0, "two count terms give three simultaneous fireballs")
	test.assert_equal(config.charge_ms, 2400.0, "only term 206 extends charge by fifty percent")
	test.assert_equal(catalog.record("skills", 17).fireball.copies, 1, "definitions remain immutable")
	var final: Dictionary = config.duplicate(true)
	w.dispose()
	w = world(catalog)
	for id in [202, 205, 206, 207, 208, 209, 201, 210, 204, 203]:
		choose(w, id)
	test.assert_equal(w.units[w.heroes[0]].skills[17].data.fireball, final, "legal learning order does not change final capability")
	w.dispose()

func _targets(test, catalog) -> void:
	for count in [1, 2, 4]:
		var w = world(catalog)
		var hero: Dictionary = w.units[w.heroes[0]]
		choose(w, 206)
		choose(w, 207)
		for i in range(count):
			fixture.enemy(w, hero.pos + Vector2(-90 + i * 60, -350))
		var targets: Array = w.skills.fireball.targets(hero, hero.skills[17].data.fireball)
		var ids: Dictionary = {}
		for target in targets:
			ids[target.id] = true
		test.assert_equal(targets.size(), 1, "fireball group selects exactly one primary target")
		test.assert_equal(ids.size(), 1, "all fireballs share their primary aim direction")
		var combat_rng: Dictionary = w.rng.stream("defense.combat").snapshot()
		test.assert_true(w.skills.ready_action(hero), "real timed skill starts a charge")
		test.assert_equal(hero.skills[17].next, 6000, "base cooldown remains six seconds")
		step(w, int(w.skills.queue[0].at))
		test.assert_equal(w.rng.stream("defense.combat").snapshot(), combat_rng, "cosmetic charge positions do not consume gameplay randomness")
		var start: int = w.time_ms
		step(w, start + 2399)
		test.assert_equal(w.missiles.filter(func(p): return p.kind == 9).size(), 0, "no flight before 2400 milliseconds")
		step(w, start + 2400)
		var flights: Array = w.missiles.filter(func(p): return p.kind == 9)
		test.assert_equal(flights.size(), 3, "group releases all three in the same tick")
		test.assert_equal(w.events.filter(func(event): return event.type == "sound" and event.name == "huoqiu").size(), 1, "simultaneous fireball group plays one launch sound")
		test.assert_true(flights.all(func(p): return p.start == start + 2400), "simultaneous release shares start time")
		w.dispose()

func _damage(test, catalog) -> void:
	for conversion in [false, true]:
		var w = world(catalog)
		var hero: Dictionary = w.units[w.heroes[0]]
		if conversion:
			choose(w, 208)
		for id in [201, 203, 204, 209]:
			choose(w, id)
		var enemy = fixture.enemy(w, hero.pos + Vector2(0, -350))
		w.skills.fireball.impact(hero, enemy, hero.skills[17].data.fireball)
		step(w, 0)
		test.assert_true(w.events.any(func(event): return event.type == "sound" and event.name == "huoqiu_att"), "new blast preserves its configured impact sound")
		var expected = 290.0 * (1.1 if conversion else 1)
		test.assert_true(absf(100000 - U.hp(enemy) - expected) < 0.01, "real explosion uses additive bonuses and opt-in multiplicative conversion")
		test.assert_true(w.statuses.has_status(enemy, 4), "fire impact applies real stun")
		w.time_ms = 1999
		w.statuses.tick()
		test.assert_true(w.statuses.has_status(enemy, 4), "stun lasts through 1999 milliseconds")
		w.time_ms = 2000
		w.statuses.tick()
		test.assert_true(not w.statuses.has_status(enemy, 4), "stun ends at two seconds")
		w.dispose()

func _secondary(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	for id in [201, 202, 203, 204, 205, 209]:
		choose(w, id)
	var main = fixture.enemy(w, hero.pos + Vector2(0, -350))
	var rim = fixture.enemy(w, main.pos + Vector2(230, 0))
	var outside = fixture.enemy(w, main.pos + Vector2(270, 0))
	w.skills.fireball.impact(hero, main, hero.skills[17].data.fireball)
	step(w, 0)
	test.assert_equal(U.hp(main), 99710.0, "main blast applies all four explosion bonuses")
	test.assert_equal(U.hp(rim), 100000.0, "main radius uses the square-root area formula")
	step(w, 320)
	test.assert_equal(U.hp(main), 99565.0, "secondary explosion deals fifty percent of main blast")
	test.assert_equal(U.hp(rim), 99855.0, "secondary area bonus is added before the square-root conversion")
	test.assert_equal(U.hp(outside), 100000.0, "secondary excludes targets outside its area-converted radius")
	test.assert_true(w.statuses.has_status(rim, 20201) and w.statuses.has_status(rim, 4), "secondary inherits burn and stun")
	test.assert_equal(w.missiles.filter(func(p): return p.skill.get("fireball_ember", false)).size(), 1, "only main blast creates one ember area")
	for at in range(336, 900, 16):
		step(w, at)
	test.assert_equal(U.hp(main), 99565.0, "secondary cannot recursively generate more explosions")
	w.dispose()

func _shield(test, catalog) -> void:
	for interruption in ["release", "control", "death"]:
		var w = world(catalog)
		var hero: Dictionary = w.units[w.heroes[0]]
		choose(w, 206)
		choose(w, 207)
		var enemy = fixture.enemy(w, hero.pos + Vector2(0, -350))
		w.skills.ready_action(hero)
		step(w, int(w.skills.queue[0].at))
		var start: int = w.time_ms
		test.assert_equal(hero.shield, 250.0, "whole three-ball charge grants one quarter max HP shield")
		test.assert_true(not w.skills.fireball.cast(hero, hero.skills[17].data), "charge cannot start twice")
		test.assert_equal(hero.shield, 250.0, "duplicate cast cannot stack shields")
		w.damage.hit(enemy, hero, 100, true, false, {"kind": "attack"})
		test.assert_equal(U.hp(hero), 1000.0, "real incoming damage consumes the charge shield first")
		test.assert_equal(hero.shield, 150.0, "shield tracks remaining capacity")
		if interruption == "control":
			w.statuses.add(hero, enemy, 4, 1000)
		elif interruption == "death":
			w.damage.defeat(hero, enemy)
		step(w, start + (2400 if interruption == "release" else 16))
		test.assert_equal(hero.shield, 0.0, "release, control and death clear remaining temporary shield")
		test.assert_equal(w.skills.fireball.charges.size(), 0, "completed or interrupted charge is removed")
		test.assert_equal(w.missiles.filter(func(p): return p.kind == 9).size(), 3 if interruption == "release" else 0, "only uninterrupted group launches fireballs")
		w.dispose()

func _weights(test, catalog) -> void:
	var w = world(catalog)
	w.choices.quality_weights = [0, 0, 0, 0, 10000]
	var expected = {201: 3.0 / 9, 202: 3.0 / 9, 206: 1.0 / 9, 208: 1.0 / 9, 209: 1.0 / 9}
	for mode in ["ordinary", "bonus", "chest"]:
		var counts = {201: 0, 202: 0, 206: 0, 208: 0, 209: 0}
		for i in range(2000):
			var item: Dictionary = w.loot.roll() if mode == "chest" else w.choices.roll_upgrade(w.rng.stream("defense.choice"), [], w.heroes[0] if mode == "bonus" else 0)
			counts[item.id] += 1
		for id in counts:
			test.assert_true(absf(counts[id] / 2000.0 - expected[id]) < 0.04, "fire weights apply independently of icon quality in " + mode)
		print("[FIRE WEIGHTS] ", mode, " ", counts)
	w.dispose()
