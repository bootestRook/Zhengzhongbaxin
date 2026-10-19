extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
var roots: Dictionary = {}

func world(catalog, hid: int):
	var w = Session.new(catalog)
	w.start(53)
	w.factory.add_hero(hid)
	w.phase = "playing"
	w.spawn_wave = 20
	w.stage = 19
	w.units[w.heroes[0]].core.attributes.set_value("7", 0)
	return w

func enemy(w, pos: Vector2) -> Dictionary:
	var target = w.factory.create("enemy", 101, pos, 2)
	for key in ["1", "hp"]:
		target.core.attributes.set_value(key, 100000)
	target.core.attributes.set_value("10", 0)
	target.traits.clear()
	return target

func spells(w, end: int) -> void:
	for at in range(w.time_ms, end, 16):
		w.time_ms = at
		w.skills.tick()
		w.projectiles.tick()

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	for hid in [1, 2, 4, 13, 17]:
		roots[hid] = catalog.record("heroes", hid).initial_options
	for hid in roots:
		var w = world(catalog, hid)
		var hero: Dictionary = w.units[w.heroes[0]]
		test.assert_equal(hero.upgrades, roots[hid], "each hero learns exactly its new initial skill")
		test.assert_equal(w.snapshot().heroes[0].skills.size(), 1, "one live skill icon per hero")
		var visited: Array = []
		for _pass in range(10):
			for item in w.choices.upgrade_pool():
				var option = catalog.record("options", item.id)
				test.assert_equal(option.root_option, roots[hid][0], "rewards stay in the retained skill tree")
				if not visited.has(item.id) and w.choices.eligible(option, hero):
					w.upgrades.apply(hero, item.id)
					visited.append(item.id)
		var expected: Array = []
		for option in catalog.records("options").values():
			if option.type == [hid] and not roots[hid].has(option.id) and int(option.get("options_num", 0)) > 0 and option.get("numTable", []).is_empty():
				expected.append(option.id)
		visited.sort()
		expected.sort()
		test.assert_equal(visited, expected, "retained weighted branches remain legally reachable")
		test.assert_true(w.diagnostics.is_empty(), "retained branches have valid runtime definitions")
		w.dispose()
	for oid in [2, 1081, 601, 14, 76, 316, 602, 1085]:
		test.assert_true(catalog.record("options", oid).is_empty(), "obsolete independent skill tree removed")
	_attacks(test, catalog)
	_shield(test, catalog)
	_thorns(test, catalog)
	_arrows(test, catalog)
	_assassination(test, catalog)
	_rewards(test, catalog)

func _attacks(test, catalog) -> void:
	for pair in [[4, 1000], [1, 2000], [2, 2000], [13, 2000], [17, 1000]]:
		var w = world(catalog, pair[0])
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.skills.clear()
		var target = enemy(w, hero.pos + Vector2(0, -20))
		w.ai.attack(hero, target)
		var ended: int = hero.action_until
		test.assert_true(ended > w.time_ms, "normal attack plays a real animation")
		test.assert_equal(hero.attack_at, ended + pair[1], "base interval begins after the complete animation")
		w.time_ms = hero.attack_at - 1
		w.ai.attack(hero, target)
		test.assert_equal(hero.attacks, 1, "cannot attack one millisecond before the post-animation interval ends")
		w.time_ms += 1
		w.ai.attack(hero, target)
		test.assert_equal(hero.attacks, 2, "can attack when the post-animation interval ends")
		test.assert_equal(U.stat(hero, 5), 3.0 if pair[0] in [4, 17] else 1.0, "multi-arrow does not change basic attack target count")
		target.core.attributes.set_value("29", 50)
		var dealt = w.damage.basic_hit(hero, target, 100)
		test.assert_true(absf(dealt - (100 if pair[0] == 4 else 50)) < 0.01, "elemental basic attacks use the real magical damage path")
		w.dispose()

func _shield(test, catalog) -> void:
	var w = world(catalog, 4)
	var hero: Dictionary = w.units[w.heroes[0]]
	var near = enemy(w, hero.pos + Vector2(0, -100))
	var far = enemy(w, hero.pos + Vector2(600, 0))
	test.assert_true(w.skills.ready_action(hero), "shield is timed and does not require ten attacks")
	test.assert_equal(hero.skills[755].next, 10000, "shield starts its ten-second cooldown")
	spells(w, 1200)
	test.assert_equal(near.taunt, hero.id, "shield taunts real nearby monsters")
	test.assert_equal(far.taunt, 0, "shield does not taunt outside its range")
	test.assert_equal(w.ai.choose_enemy(near).id, hero.id, "AI obeys the shield taunt")
	hero.core.attributes.set_value("10", 0)
	for context in [{}, {"kind": "periodic"}, {"tags": PackedStringArray(["3"])}]:
		var dealt = w.damage.hit(near, hero, 100, true, false, context)
		test.assert_true(absf(dealt - 50) < 0.01, "shield halves direct, periodic and armor-bypassing incoming damage")
	test.assert_equal(hero.shield_hits, 0, "new shield does not use the removed four-hit immunity")
	w.time_ms = near.taunt_until
	w.statuses.tick()
	test.assert_true(not w.statuses.has_status(hero, 20001), "shield protection expires after four seconds")
	test.assert_equal(w.damage.hit(near, hero, 100, true, false), 100.0, "expired shield no longer reduces damage")
	w.dispose()

func _thorns(test, catalog) -> void:
	var w = world(catalog, 2)
	var druid: Dictionary = w.units[w.heroes[0]]
	w.factory.add_hero(4)
	var ally: Dictionary = w.units[w.heroes[1]]
	ally.pos = druid.pos + Vector2(80, 0)
	ally.core.attributes.set_value("hp", 100)
	test.assert_true(w.skills.ready_action(druid), "thorn armor targets a real friendly hero")
	test.assert_equal(druid.skills[20301].next, 15000, "thorns starts its fifteen-second cooldown")
	spells(w, 1200)
	test.assert_true(U.hp(ally) > 100 and druid.stats.heal > 0, "thorns really heals its ally")
	test.assert_true(w.statuses.has_status(ally, 20301), "thorn armor is applied")
	var attacker = enemy(w, ally.pos + Vector2(0, -20))
	w.ai.emit_attack(attacker, {"target": ally.id, "wall": false})
	spells(w, 1500)
	test.assert_true(U.hp(attacker) < 100000, "thorn armor retaliates against a real basic attack")
	w.time_ms = 12000
	w.statuses.tick()
	test.assert_true(not w.statuses.has_status(ally, 20301), "thorn armor and its retaliation expire together")
	w.statuses.add(ally, druid, 67, 1000)
	w.statuses.add(ally, ally, 67, 2000)
	w.time_ms += 1000
	w.statuses.tick()
	test.assert_true(ally.skills.has(662), "a second active armor source retains its granted retaliation")
	w.skills.learn(ally, 662)
	w.time_ms += 1000
	w.statuses.tick()
	test.assert_true(ally.skills.has(662) and not ally.skills[662].temporary, "status expiry cannot remove a permanently learned skill")
	w.dispose()

func _arrows(test, catalog) -> void:
	for count in [1, 3, 5]:
		var w = world(catalog, 13)
		var hero: Dictionary = w.units[w.heroes[0]]
		var targets: Array = []
		for i in range(count):
			targets.append(enemy(w, hero.pos + Vector2(-60 + i * 40, -250)))
		test.assert_true(w.skills.ready_action(hero), "multi-arrow is an independent timed skill")
		test.assert_equal(hero.skills[20002].next, 4000, "multi-arrow starts its four-second cooldown")
		spells(w, int(w.skills.queue[0].at) + 32)
		test.assert_equal(w.missiles.size(), 3, "multishot emits three lanes regardless of enemy count")
		var primary: int = w.missiles[0].target
		test.assert_true(w.missiles.all(func(p): return p.target == primary), "spread lanes share one primary target")
		spells(w, 2000)
		var total = 0.0
		for target in targets:
			total += 100000 - U.hp(target)
		test.assert_true(total >= U.stat(hero, 4) * 0.5 and total <= U.stat(hero, 4) * 1.5, "three actual collision lanes settle at most three fifty-percent hits")
		w.dispose()

func _assassination(test, catalog) -> void:
	var w = world(catalog, 17)
	var hero: Dictionary = w.units[w.heroes[0]]
	var target = enemy(w, hero.pos + Vector2(100, -150))
	test.assert_true(w.skills.ready_action(hero), "assassination starts through the actual action scheduler")
	test.assert_equal(hero.skills[1435].next, 8000, "assassination starts its eight-second cooldown")
	spells(w, 1200)
	test.assert_equal(hero.pos, target.pos, "assassination teleports to its target")
	test.assert_true(absf(100000 - U.hp(target) - U.stat(hero, 4) * 3) < 0.01, "assassination deals the approved three-hundred-percent damage")
	test.assert_equal(hero.skills[1435].data.damage_type, "0;106;109", "assassination uses lightning damage tags")
	test.assert_true(not hero.skills.has(1429), "removed poison blade cannot execute")
	w.dispose()

func _rewards(test, catalog) -> void:
	var w = world(catalog, 1)
	for hid in [2, 4, 13, 17]:
		w.factory.add_hero(hid)
	for i in range(30):
		w.choices.offer("upgrade")
		var items = w.offers.duplicate()
		items.append(w.loot.roll())
		w.pending = [w.heroes[i % 5]]
		w.choices.offer("bonus")
		items.append_array(w.offers)
		for item in items:
			var owner: Dictionary = w.units[item.owner]
			test.assert_equal(catalog.record("options", item.id).root_option, roots[owner.template][0], "upgrade, chest and bonus rewards use the new roster")
	w.dispose()
