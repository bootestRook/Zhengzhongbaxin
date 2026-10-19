extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Fixture = preload("res://tests/test_defense_hero_roster.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Displacement = preload("res://src/features/defense/domain/defense_displacement.gd")
var fixture = Fixture.new()

func choose(w, term: int) -> void:
	var owner: Dictionary = w.units[w.heroes[0]]
	w.offers = [w.choices.card(w.catalog.record("options", 200000 + term), owner.id)]
	w.phase = "choice"
	assert(w.choices.choose(0).is_empty())

func cast(w) -> Dictionary:
	var hero: Dictionary = w.units[w.heroes[0]]
	assert(w.skills.ready_action(hero))
	fixture.spells(w, w.time_ms + 1200)
	return w.damage.protection.active(hero)

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_prerequisites(test, catalog)
	_stacks(test, catalog)
	_taunt(test, catalog)
	_control(test, catalog)
	_lethal(test, catalog)
	_weights(test, catalog)

func _prerequisites(test, catalog) -> void:
	var w = fixture.world(catalog, 4)
	var hero: Dictionary = w.units[w.heroes[0]]
	var pool: Array = w.choices.upgrade_pool().map(func(o): return o.id)
	pool.sort()
	test.assert_equal(pool, [200101, 200102, 200103, 200104], "recruitment unlocks exactly four initial branches")
	test.assert_equal(hero.upgrades, [200100], "recruitment grants only the shield once")
	for oid in [325, 326, 327, 328, 335, 343, 344, 345]:
		test.assert_true(catalog.record("options", oid).is_empty(), "old warrior option is absent")
	choose(w, 103)
	choose(w, 105)
	test.assert_true(not w.choices.eligible(catalog.record("options", 200106), hero), "steel needs both prerequisite branches")
	choose(w, 104)
	test.assert_true(w.choices.eligible(catalog.record("options", 200106), hero), "steel unlocks after both branches are owned")
	choose(w, 106)
	test.assert_true(not w.choices.eligible(catalog.record("options", 200107), hero), "oath also needs hold the line")
	choose(w, 101)
	choose(w, 107)
	choose(w, 102)
	test.assert_true(w.choices.upgrade_pool().is_empty(), "each of the eight terms can be acquired only once")
	test.assert_equal(hero.skills[755].data.cd, 9000.0, "mastery changes the actual cooldown to nine seconds")
	test.assert_equal(float(hero.skills[755].data.statusChange[0][1]), 6.0, "lasting shield changes the actual duration to six seconds")
	test.assert_equal(hero.skills[20001].data.radius_bonus, 30.0, "taunt expansion changes the actual area")
	test.assert_equal(hero.upgrades.size(), 8, "prerequisites are retained rather than consumed")
	w.dispose()

func _stacks(test, catalog) -> void:
	var w = fixture.world(catalog, 4)
	var hero: Dictionary = w.units[w.heroes[0]]
	var enemy = fixture.enemy(w, hero.pos + Vector2(0, -100))
	hero.core.attributes.set_value("10", 0)
	choose(w, 101)
	choose(w, 104)
	var shield = cast(w)
	var start: int = w.time_ms
	test.assert_equal(shield.expires - shield.started, 6000, "extended shield lasts six seconds")
	test.assert_equal(w.damage.hit(enemy, hero, 100, true, false), 50.0, "first hit uses the reduction before its new stack")
	test.assert_equal(U.stat(hero, 11), 51.0, "first positive hit adds one percentage point")
	w.time_ms = start + 499
	test.assert_equal(w.damage.hit(enemy, hero, 100, true, false), 49.0, "subsequent damage uses the first stack")
	test.assert_equal(U.stat(hero, 11), 51.0, "499 milliseconds cannot add a stack")
	w.time_ms = start + 500
	w.damage.hit(enemy, hero, 10, true, false)
	test.assert_equal(U.stat(hero, 11), 52.0, "500 milliseconds permits the next stack")
	for i in range(2, 12):
		w.time_ms = start + i * 500
		w.damage.hit(enemy, hero, 10, true, false)
	test.assert_equal(U.stat(hero, 11), 60.0, "extra reduction is capped at ten percentage points")
	w.time_ms = shield.expires
	w.statuses.tick()
	test.assert_equal(U.stat(hero, 11), 0.0, "shield expiry removes both base and stacked reduction")
	w.time_ms = 10000
	w.statuses.tick()
	shield = cast(w)
	test.assert_equal(U.stat(hero, 11), 50.0, "next shield begins with zero previous stacks")
	hero.shield = 100
	test.assert_equal(w.damage.hit(enemy, hero, 100, true, false), 0.0, "fully absorbed attack inflicts no actual damage")
	test.assert_equal(U.stat(hero, 11), 50.0, "zero damage cannot add a stack")
	hero.shield = 0
	hero.core.attributes.set_value("16", 100)
	w.damage.hit(enemy, hero, 100, true, false)
	test.assert_equal(U.stat(hero, 11), 50.0, "a dodged attack cannot add a stack")
	w.dispose()

func _taunt(test, catalog) -> void:
	for order in [[103, 104, 105], [103, 105, 104]]:
		var w = fixture.world(catalog, 4)
		var hero: Dictionary = w.units[w.heroes[0]]
		var enemy = fixture.enemy(w, hero.pos + Vector2(450, 0))
		var outside = fixture.enemy(w, hero.pos + Vector2(750, 0))
		fixture.enemy(w, hero.pos + Vector2(0, -150))
		var attack = U.stat(enemy, 4)
		for id in order:
			choose(w, id)
		var shield = cast(w)
		test.assert_equal(enemy.taunt, hero.id, "expanded taunt reaches a monster at five hundred units")
		test.assert_equal(outside.taunt, 0, "taunt excludes distant monsters")
		test.assert_equal(enemy.taunt_until, shield.expires, "taunt and shield share the same end time")
		test.assert_true(absf(U.stat(enemy, 4) - attack * 0.85) < 0.001, "taunted enemy really loses fifteen percent attack")
		test.assert_true(not enemy.statuses.is_empty(), "taunted enemy has a real weakening status")
		if not enemy.statuses.is_empty():
			test.assert_equal(enemy.statuses[0].expires, enemy.taunt_until, "weakening duration follows taunt in either selection order")
		w.time_ms = shield.expires
		w.statuses.tick()
		test.assert_equal(U.stat(enemy, 4), attack, "weakening expires with taunt")
		w.dispose()

func _control(test, catalog) -> void:
	var w = fixture.world(catalog, 4)
	var hero: Dictionary = w.units[w.heroes[0]]
	var enemy = fixture.enemy(w, hero.pos + Vector2(0, -100))
	for id in [103, 105, 104, 106]:
		choose(w, id)
	var shield = cast(w)
	w.statuses.add(hero, enemy, 4, 2000)
	var stun: Dictionary = hero.statuses.back()
	test.assert_equal(stun.expires - w.time_ms, 1000, "incoming control duration is halved during the shield")
	w.statuses.add(hero, enemy, 1, 2000)
	test.assert_equal(hero.statuses.back().expires - w.time_ms, 2000, "other negative statuses do not receive blanket duration reduction")
	var hook = {"actionOth": [["hook", "100"]]}
	w.projectiles.effects.apply(enemy, hero, hook, "pre")
	test.assert_true(not hero.has("forced_motion"), "active steel will blocks incoming forced displacement")
	hero["forced_motion"] = {"owner": enemy.id, "speed": 100}
	test.assert_true(not Displacement.tick(w, hero) and not hero.has("forced_motion"), "active steel also interrupts an existing forced displacement")
	w.time_ms = shield.expires
	w.statuses.tick()
	w.projectiles.effects.apply(enemy, hero, hook, "pre")
	test.assert_true(hero.has("forced_motion"), "forced displacement works again after the shield ends")
	w.statuses.add(hero, enemy, 4, 2000)
	test.assert_equal(hero.statuses.back().expires - w.time_ms, 2000, "control reduction also ends with the shield")
	w.dispose()

func _lethal(test, catalog) -> void:
	var w = fixture.world(catalog, 4)
	var hero: Dictionary = w.units[w.heroes[0]]
	var enemy = fixture.enemy(w, hero.pos + Vector2(0, -100))
	for id in [101, 103, 105, 104, 106, 107]:
		choose(w, id)
	hero.core.attributes.set_value("10", 0)
	var shield = cast(w)
	w.time_ms = shield.expires - 500
	hero.core.attributes.set_value("hp", 100)
	var taken: float = hero.stats.taken
	test.assert_equal(w.damage.hit(enemy, hero, 10000, true, false), 99.0, "fatal hit only removes health down to one")
	test.assert_equal(hero.stats.taken - taken, 99.0, "statistics count actual damage after lethal prevention")
	test.assert_true(U.hp(hero) == 1 and not hero.dead, "oath really prevents death")
	var ready: int = hero.protection.lethal_ready
	test.assert_equal(ready, w.time_ms + 60000, "oath cooldown starts at the actual trigger")
	w.time_ms = shield.expires
	w.statuses.tick()
	for context in [{}, {"kind": "skill"}, {"kind": "periodic"}]:
		test.assert_equal(w.damage.hit(enemy, hero, 10000, true, false, context), 0.0, "two-second immunity covers all damage kinds after shield expiry")
	w.time_ms = hero.protection.immune_until - 1
	test.assert_equal(w.damage.hit(enemy, hero, 10000, true, false), 0.0, "immunity remains until its final millisecond")
	w.time_ms += 1
	w.damage.hit(enemy, hero, 10000, true, false)
	test.assert_true(hero.dead, "immunity ends exactly at its deadline")
	w.time_ms = hero.revive_at
	w.factory.lifecycle()
	test.assert_true(not hero.dead and hero.protection.lethal_ready == ready, "revival preserves the remaining sixty-second cooldown")
	cast(w)
	w.damage.hit(enemy, hero, 100000, true, false)
	test.assert_true(hero.dead, "another active shield cannot bypass the oath cooldown after revival")
	w.time_ms = ready
	w.factory.lifecycle()
	cast(w)
	w.damage.hit(enemy, hero, 100000, true, false)
	test.assert_true(not hero.dead and U.hp(hero) == 1, "oath becomes available again after sixty combat seconds")
	w.start(53)
	w.factory.add_hero(4)
	hero = w.units[w.heroes[0]]
	test.assert_equal(hero.protection.lethal_ready, 0, "a fresh run resets oath state")
	w.dispose()

func _weights(test, catalog) -> void:
	var w = fixture.world(catalog, 4)
	var owner: int = w.heroes[0]
	w.choices.quality_weights = [0, 0, 0, 0, 10000]
	for kind in ["ordinary", "bonus", "chest"]:
		var counts = {200101: 0, 200102: 0, 200103: 0, 200104: 0}
		for i in range(2000):
			var item: Dictionary
			if kind == "chest":
				item = w.loot.roll()
			else:
				item = w.choices.roll_upgrade(w.rng.stream("defense.choice"), [], owner if kind == "bonus" else 0)
			counts[item.id] += 1
		for id in counts:
			var expected: float = 4.0 / 13 if id == 200103 else 3.0 / 13
			test.assert_true(absf(counts[id] / 2000.0 - expected) < 0.04, "%s uses explicit term weights independently of quality" % kind)
		print("[WARRIOR WEIGHTS] ", kind, " ", counts)
	w.pending = [owner]
	w.choices.offer("bonus")
	var ids: Array = w.offers.map(func(item): return item.id)
	test.assert_equal(ids.size(), 3, "three legal warrior upgrades are offered")
	test.assert_true(ids[0] != ids[1] and ids[0] != ids[2] and ids[1] != ids[2], "one offer cannot contain duplicate terms")
	w.dispose()
