extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const TERMS = [302, 302, 303, 306, 307, 308, 310, 311, 312]

func world(catalog):
	var w = Session.new(catalog)
	w.start(53)
	w.factory.add_hero(2)
	w.phase = "playing"
	w.stage = 19
	w.spawn_wave = 20
	normalize(w.units[w.heroes[0]])
	return w

func normalize(unit: Dictionary) -> void:
	for pair in [["1", 1000], ["hp", 100], ["4", 100], ["7", 0], ["10", 0], ["11", 0], ["12", 0], ["16", 0], ["21", 0], ["22", 0], ["27", 0], ["28", 0], ["29", 0], ["31", 0]]:
		unit.core.attributes.set_value(pair[0], pair[1])

func ally(w, hid: int = 4) -> Dictionary:
	w.factory.add_hero(hid)
	var unit: Dictionary = w.units[w.heroes.back()]
	normalize(unit)
	unit.pos = w.units[w.heroes[0]].pos + Vector2(100 * w.heroes.size(), 0)
	return unit

func enemy(w, pos: Vector2) -> Dictionary:
	var unit = w.factory.create("enemy", 101, pos, 2)
	normalize(unit)
	unit.core.attributes.set_value("1", 100000)
	unit.core.attributes.set_value("hp", 100000)
	unit.traits.clear()
	return unit

func choose(w, term: int) -> void:
	w.offers = [w.choices.card(w.catalog.record("options", 200000 + term), w.heroes[0])]
	w.phase = "choice"
	assert(w.choices.choose(0).is_empty(), "druid term must be legally selectable")

func cast(w) -> bool:
	var owner: Dictionary = w.units[w.heroes[0]]
	return w.skills.cast(owner, owner.skills[20301].data, {})

func run(test) -> void:
	var c = Catalog.new()
	c.load_default()
	_library(test, c)
	_armor(test, c)
	_control(test, c)
	_flowers(test, c)
	_follow(test, c)
	_weights(test, c)
	preload("res://tests/test_defense_druid_edges.gd").new().run(test, c)

func _library(test, c) -> void:
	var w = world(c)
	var owner: Dictionary = w.units[w.heroes[0]]
	test.assert_equal(owner.upgrades, [200301], "recruitment grants exactly thorn armor")
	var pool: Array = w.choices.upgrade_pool().map(func(o): return o.id)
	pool.sort()
	test.assert_equal(pool, [200302, 200303, 200306, 200307], "four initial druid choices only")
	test.assert_true(not w.skills.ready_action(owner), "no ally means no cast or cooldown")
	test.assert_equal(owner.skills[20301].next, 0, "failed targeting preserves cooldown")
	for id in [81, 82, 83, 84, 94, 100, 101, 102]:
		test.assert_true(c.record("options", id).is_empty(), "old druid option removed")
	choose(w, 302)
	test.assert_true(not w.choices.eligible(c.record("options", 200308), owner), "wood burst requires both parents")
	choose(w, 303)
	test.assert_true(w.choices.eligible(c.record("options", 200308), owner), "one evergreen rank satisfies parent")
	for term in [302, 306, 307, 308, 310, 311, 312]:
		choose(w, term)
	test.assert_equal(w.selected["200302"], 2, "evergreen is acquired twice")
	test.assert_true(w.choices.upgrade_pool([], owner.id).is_empty(), "all druid upgrades capped")
	test.assert_equal(owner.skills[20301].data.thorn_armor.duration_ms, 15000.0, "two ranks give fifteen second armor")
	test.assert_equal(c.record("skills", 20301).thorn_armor.duration_ms, 10000, "static capability never changes")
	test.assert_true(w.skills.ready_action(owner), "symbiosis permits self protection without ally")
	test.assert_equal(owner.skills[20301].next, 15000, "actual action starts fifteen second cooldown")
	w.dispose()

func _armor(test, c) -> void:
	var w = world(c)
	var target = ally(w)
	var attacker = enemy(w, target.pos + Vector2(0, -20))
	cast(w)
	test.assert_equal(U.hp(target), 220.0, "direct cure is one hundred twenty percent of druid attack")
	test.assert_equal(target.shield, 50.0, "base armor uses protected hero maximum life")
	var dealt = w.damage.hit(attacker, target, 10, true, true, {"kind": "attack"})
	test.assert_equal(dealt, 0.0, "armor absorbs actual direct damage")
	test.assert_equal(U.hp(attacker), 99950.0, "fully absorbed direct hit still retaliates using druid attack")
	w.damage.hit(attacker, target, 100, true, true, {"kind": "periodic"})
	test.assert_equal(U.hp(attacker), 99950.0, "periodic damage cannot retaliate")
	choose(w, 303)
	cast(w)
	test.assert_equal(U.hp(target), 300.0, "enhanced cure is one hundred eighty percent after periodic injury")
	test.assert_equal(target.shield, 65.0, "extra shield adds fifteen alongside base fifty")
	w.damage.hit(attacker, target, 50, true, true, {"kind": "attack"})
	test.assert_true(not w.statuses.has_status(target, 20301), "own base shield break removes armor immediately")
	test.assert_equal(target.shield, 15.0, "extra shield survives base armor break")
	var hp = U.hp(attacker)
	w.damage.hit(attacker, target, 1, true, true)
	test.assert_equal(U.hp(attacker), hp, "broken armor cannot retaliate again")
	w.dispose()

func _control(test, c) -> void:
	var w = world(c)
	var target = ally(w)
	var attacker = enemy(w, target.pos + Vector2(0, -20))
	for term in [302, 303, 306, 308]:
		choose(w, term)
	attacker.core.attributes.set_value("6", 100)
	for i in range(7):
		cast(w)
		w.damage.hit(attacker, target, 1, true, true)
	test.assert_equal(U.stat(attacker, 6), 75.0, "root mark capped at five five-percent stacks")
	w.time_ms = 5000
	w.statuses.tick()
	test.assert_equal(U.stat(attacker, 6), 100.0, "root mark clears after five seconds")
	cast(w)
	var outside = enemy(w, target.pos + Vector2(400, 0))
	w.damage.hit(attacker, target, 50, true, true)
	test.assert_true(w.statuses.has_status(attacker, 4), "breaking armor stuns nearby attacker")
	test.assert_true(not w.statuses.has_status(outside, 4), "wood burst excludes distant enemy")
	w.time_ms = 8000
	w.statuses.tick()
	test.assert_true(not w.statuses.has_status(attacker, 4), "wood stun lasts three seconds")
	cast(w)
	w.time_ms = 20500
	w.statuses.tick()
	test.assert_true(w.statuses.has_status(attacker, 4), "natural armor expiry also bursts")
	w.dispose()

func _flowers(test, c) -> void:
	var w = world(c)
	var target = ally(w)
	choose(w, 307)
	cast(w)
	var flower: Dictionary = w.skills.thorns.flowers[0]
	var near = enemy(w, flower.pos)
	var far = enemy(w, flower.pos + Vector2(300, 0))
	test.assert_true(not w.units.values().any(func(u): return u.kind == "summon"), "timed flowers do not register blocking or aggro units")
	w.time_ms = 4999
	w.skills.thorns.tick()
	test.assert_equal(U.hp(near), 100000.0, "flower waits five seconds")
	w.time_ms = 5000
	w.skills.thorns.tick()
	test.assert_equal(U.hp(near), 99900.0, "flower pulse uses full druid attack")
	test.assert_true(w.statuses.has_status(near, 5), "pulse really roots enemy")
	test.assert_equal(U.hp(far), 100000.0, "flower pulse stays within radius")
	w.time_ms = 10000
	w.skills.thorns.tick()
	test.assert_equal(U.hp(near), 99800.0, "ten second expiry preserves final pulse")
	test.assert_true(w.skills.thorns.flowers.is_empty(), "flower removed after final pulse")
	choose(w, 310)
	cast(w)
	w.time_ms = 11000
	cast(w)
	var oldest: int = w.skills.thorns.flowers[0].id
	w.time_ms = 12000
	cast(w)
	test.assert_equal(w.skills.thorns.flowers.size(), 2, "cultivation limits to two flowers")
	test.assert_true(not w.skills.thorns.flowers.any(func(f): return f.id == oldest), "overflow replaces shortest remaining life")
	w.time_ms = 27000
	w.skills.thorns.tick()
	test.assert_true(w.skills.thorns.flowers.is_empty(), "fifteen second flowers finish including last pulse")
	w.start(54)
	test.assert_true(w.skills.thorns.flowers.is_empty(), "new run clears flowers")
	w.dispose()

func _follow(test, c) -> void:
	var w = world(c)
	var first = ally(w)
	var second = ally(w, 13)
	for term in TERMS:
		choose(w, term)
	cast(w)
	test.assert_equal(w.skills.thorns.flowers.size(), 2, "dual cast creates two flowers within shared cap")
	test.assert_equal(U.hp(first), 380.0, "direct cure plus one follow cure")
	test.assert_equal(U.hp(second), 380.0, "each distinct hero receives one follow cure")
	test.assert_equal(U.stat(first, 11), 30.0, "follow grants actual thirty percent reduction")
	var flower: Dictionary = w.skills.thorns.flowers[0]
	var expiry: int = flower.expires
	var next: int = flower.next
	first.pos += Vector2(80, 0)
	w.time_ms = 1000
	w.skills.thorns.tick()
	test.assert_equal(flower.pos, first.pos + Vector2(65, 0), "migrated flower follows protected hero")
	test.assert_equal(flower.expires, expiry, "movement does not reset life")
	test.assert_equal(flower.next, next, "movement does not reset pulse")
	w.time_ms = 10000
	w.statuses.tick()
	test.assert_equal(U.stat(first, 11), 0.0, "follow reduction expires after ten seconds")
	w.dispose()

func _weights(test, c) -> void:
	for kind in ["ordinary", "bonus", "chest"]:
		var w = world(c)
		var counts = {200302: 0, 200303: 0, 200306: 0, 200307: 0}
		for i in range(1300):
			var item: Dictionary
			if kind == "chest":
				item = w.loot.roll()
			else:
				item = w.choices.roll_upgrade(w.rng.stream("defense.choice"), [], w.heroes[0] if kind == "bonus" else 0)
			counts[item.id] += 1
		for id in counts:
			var expected = 1300.0 * c.record("options", id).draw_weight / 13000.0
			test.assert_true(absf(counts[id] - expected) < 80, "druid weights honored in " + kind)
		print("[DRUID WEIGHTS] ", kind, " ", counts)
		w.dispose()
