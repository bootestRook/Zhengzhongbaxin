extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_commander(test, catalog)
	_summons(test, catalog)
	_counted_damage(test, catalog)
	_archer_and_shadow(test, catalog)

func world(catalog, hid: int):
	var w = Session.new(catalog)
	w.start(53)
	w.factory.add_hero(hid)
	w.phase = "playing"
	w.units[w.heroes[0]].core.attributes.set_value("7", 0)
	return w

func enemy(w, pos: Vector2) -> Dictionary:
	var u = w.factory.create("enemy", 101, pos, 2)
	u.core.attributes.set_value("1", 100000)
	u.core.attributes.set_value("hp", 100000)
	u.core.attributes.set_value("10", 0)
	u.traits.clear()
	return u

func spells(w, at: int) -> void:
	w.time_ms = at
	w.skills.tick()
	w.projectiles.tick()

func release_pending(w, hero: Dictionary) -> void:
	w.skills.pending_action(hero)
	for at in range(w.time_ms, w.time_ms + 1500, 16):
		spells(w, at)

func _commander(test, catalog) -> void:
	var w = world(catalog, 5)
	var hero: Dictionary = w.units[w.heroes[0]]
	w.factory.add_hero(4)
	var ally: Dictionary = w.units[w.heroes[1]]
	ally.core.attributes.set_value("hp", 100)
	test.assert_equal(w.passives.attack_bonus(hero), U.stat(hero, 10) * 0.5, "commander adds half its defense to physical attacks")
	for i in range(5):
		w.skills.trigger(hero, "attack_begin", {})
	test.assert_true(hero.pending_actions.is_empty(), "commander cannot inspire before six attack emissions")
	w.skills.trigger(hero, "attack_begin", {})
	release_pending(w, hero)
	var healed = U.hp(ally) - 100
	test.assert_true(absf(healed - U.stat(hero, 4) * 0.8 - U.stat(hero, 10) * 2) < 0.01, "inspire heals one ally with attack and defense scaling")
	test.assert_true(w.statuses.has_status(ally, 24), "inspire marks the target for five seconds")
	test.assert_true(w.targets.select(hero, hero.skills[429].data).is_empty(), "marked ally cannot be selected for another inspire")
	w.dispose()

func _summons(test, catalog) -> void:
	for pair in [[7, 5, 11], [11, 4, 13]]:
		var w = world(catalog, pair[0])
		var hero: Dictionary = w.units[w.heroes[0]]
		var target = enemy(w, hero.pos + Vector2(0, -100))
		for i in range(pair[1] - 1):
			w.skills.trigger(hero, "attack_begin", target)
		test.assert_true(w.units.values().all(func(u): return u.kind != "summon"), "summon waits for its configured attack count")
		w.skills.trigger(hero, "attack_begin", target)
		spells(w, 16)
		var summons = w.units.values().filter(func(u): return u.kind == "summon")
		test.assert_equal(summons.size(), 1, "counted initial skill creates exactly one summon")
		test.assert_equal(summons[0].template, pair[2], "counted summon uses its source template")
		if pair[0] == 7:
			test.assert_equal(w.passives.value(hero, 21), 10.0, "ghoul inherits ten percent attack")
			for i in range(25):
				w.skills.trigger(hero, "attack_begin", target)
				spells(w, w.time_ms + 16)
			test.assert_equal(w.units.values().filter(func(u): return u.kind == "summon" and not u.dead).size(), 4, "ghoul population stays within the initial cap of four")
		else:
			test.assert_equal(summons[0].pos, target.pos, "clone appears at the selected monster")
			test.assert_equal(summons[0].expires - w.time_ms, 5000, "clone lasts five seconds")
			w.time_ms = summons[0].expires
			w.factory.lifecycle()
			test.assert_true(summons[0].dead, "clone expires through the real death path")
		w.dispose()

func _counted_damage(test, catalog) -> void:
	for hid in [8, 9]:
		var w = world(catalog, hid)
		var hero: Dictionary = w.units[w.heroes[0]]
		var target = enemy(w, hero.pos + Vector2(0, -100))
		hero.core.attributes.set_value("hp", U.stat(hero, 1) * 0.5)
		var count = 5
		for i in range(count - 1):
			w.skills.trigger(hero, "attack_begin", target)
		test.assert_equal(U.hp(target), 100000.0, "counted skill causes no early damage")
		test.assert_true(hero.pending_actions.is_empty(), "counted animation cannot start early")
		w.skills.trigger(hero, "attack_begin", target)
		if not hero.pending_actions.is_empty():
			release_pending(w, hero)
		else:
			for at in range(0, 500, 16):
				spells(w, at)
		var damage = 100000 - U.hp(target)
		test.assert_true(damage > 0, "counted initial skill actually damages its target")
		if hid == 8:
			test.assert_true(absf(U.hp(hero) - U.stat(hero, 1) * 0.5 - damage * 0.1) < 0.01, "crimson nova returns ten percent of actual damage as health")
		w.dispose()

func _archer_and_shadow(test, catalog) -> void:
	var w = world(catalog, 13)
	var hero: Dictionary = w.units[w.heroes[0]]
	var target = enemy(w, hero.pos + Vector2(0, -100))
	for x in [-20, 20]:
		enemy(w, target.pos + Vector2(x, 0))
	w.ai.attack(hero, target)
	w.time_ms = hero.attack_events[0].at
	w.ai.advance_attack(hero)
	test.assert_equal(w.missiles.size(), 1, "ice archer basic attack launches one arrow")
	test.assert_equal(w.missiles.filter(func(p): return p.skill.get("__id__", 0) == 866).size(), 0, "removed focus cannot emit an extra arrow")
	test.assert_equal(U.stat(hero, 25), 0.0, "multi-arrow no longer halves ordinary attack strength")
	w.dispose()
	w = world(catalog, 17)
	hero = w.units[w.heroes[0]]
	target = enemy(w, hero.pos + Vector2(0, -100))
	w.skills.trigger(hero, "attack", target)
	test.assert_equal(U.hp(target), 100000.0, "lightning assassin does not execute the removed poison blade")
	w.dispose()
