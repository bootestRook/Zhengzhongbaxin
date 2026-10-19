extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_fireball(test, catalog)
	_target_modes(test, catalog)
	_initial_contracts(test, catalog)
	_druid_aggro(test, catalog)
	_visual_contracts(test, catalog)
	_action_sequences(test, catalog)
	_attack_procs(test, catalog)

func world(catalog, hero_id: int):
	var w = Session.new(catalog)
	w.start(53)
	w.factory.add_hero(hero_id)
	w.phase = "playing"
	w.spawn_wave = 20
	w.stage = 19
	w.units[w.heroes[0]].core.attributes.set_value("7", 0)
	return w

func enemy(w, pos: Vector2) -> Dictionary:
	var u = w.factory.create("enemy", 101, pos, 2)
	u.core.attributes.set_value("1", 100000)
	u.core.attributes.set_value("hp", 100000)
	u.core.attributes.set_value("10", 0)
	u.traits.clear()
	u["busy_until"] = 1000000
	return u

func tick_spells(w, time: int) -> void:
	w.time_ms = time
	w.skills.tick()
	w.projectiles.tick()

func _fireball(test, catalog) -> void:
	var w = world(catalog, 1)
	var hero: Dictionary = w.units[w.heroes[0]]
	var main = enemy(w, hero.pos + Vector2(0, -350))
	var near = enemy(w, main.pos + Vector2(0, -40))
	var far = enemy(w, main.pos + Vector2(220, 0))
	var hp = U.hp(main)
	w.skills.cast(hero, hero.skills[17].data, main)
	var charge: Dictionary = w.missiles[0]
	test.assert_true(charge.pos.distance_to(w.targets.attack_point(hero)) <= 50.01, "fire charge is at the caster wand, not inside the target")
	test.assert_true(charge.pos.distance_to(main.pos) > 200, "fire charge cannot be anchored to the monster")
	test.assert_equal(w.snapshot().missiles[0].render_scale, Vector2.ZERO, "charge starts at zero source logic scale")
	for at in range(0, 1600, 16):
		tick_spells(w, at)
	test.assert_equal(U.hp(main), hp, "charge itself deals no damage")
	test.assert_true(w.missiles.all(func(p): return p.skill.__id__ == 17), "fireball does not launch before charge completion")
	tick_spells(w, 1600)
	test.assert_equal(w.missiles.size(), 1, "charge releases one fireball at its configured 1600 ms duration")
	tick_spells(w, 1616)
	test.assert_equal(w.missiles.size(), 1, "one charge launches exactly one fireball")
	test.assert_equal(w.missiles[0].skill.__id__, 21, "charge-end links to the configured fireball")
	var fireball_id: int = w.missiles[0].id
	var seen_blast = false
	for at in range(1632, 2800, 16):
		tick_spells(w, at)
		for p in w.missiles:
			if p.skill.__id__ == 22:
				seen_blast = true
			if p.skill.__id__ == 21:
				test.assert_equal(p.id, fireball_id, "initial skill cannot duplicate fireballs through aim alternatives")
	test.assert_true(seen_blast, "fireball hit creates the configured area explosion")
	var speed_bonus = 1.0
	var expected = U.stat(hero, 4) * speed_bonus
	test.assert_true(absf(hp - U.hp(main) - expected) < 0.01, "primary receives only one 100 percent explosion without default speed scaling")
	test.assert_true(absf(100000 - U.hp(near) - U.stat(hero, 4) * speed_bonus) < 0.01, "nearby monster receives only the area explosion")
	test.assert_equal(U.hp(far), 100000.0, "explosion cannot damage an out-of-range monster")
	w.dispose()

func _target_modes(test, catalog) -> void:
	for pair in [[1, 21, 1], [4, 755, 1], [12, 749, 1], [14, 71, 1]]:
		var w = world(catalog, pair[0])
		var hero: Dictionary = w.units[w.heroes[0]]
		for i in range(8):
			enemy(w, hero.pos + Vector2(-90 + i * 25, -120))
		var selected = w.targets.select(hero, hero.skills[pair[1]].data)
		test.assert_equal(selected.size(), pair[2], "source aim alternatives cannot multiply initial target count")
		w.dispose()

func _initial_contracts(test, catalog) -> void:
	var w = world(catalog, 2)
	var hero: Dictionary = w.units[w.heroes[0]]
	var target = enemy(w, hero.pos + Vector2(0, -350))
	w.factory.add_hero(4)
	w.upgrades.apply(hero, 200307)
	w.skills.cast(hero, hero.skills[20301].data, target)
	test.assert_equal(w.skills.thorns.flowers.size(), 1, "thorn summon branch produces one timed flower entity")
	test.assert_equal(w.passives.value(hero, 21), 0.0, "removed plant branch grants no legacy attack inheritance")
	w.dispose()
	w = world(catalog, 6)
	test.assert_equal(w.pending.size(), 1, "alchemist gets one required initial potion choice")
	w.dispose()
	w = world(catalog, 15)
	hero = w.units[w.heroes[0]]
	var before = U.stat(hero, 4)
	w.skills.trigger(hero, "kill", {})
	w.time_ms = 10000
	w.statuses.tick()
	test.assert_true(U.stat(hero, 4) > before and w.statuses.has_status(hero, 165), "ghost kill attack bonus persists until death")
	w.damage.defeat(hero, {})
	test.assert_true(not w.statuses.has_status(hero, 165), "ghost persistent attack bonus clears on death")
	w.dispose()
	w = world(catalog, 16)
	hero = w.units[w.heroes[0]]
	var hp = U.hp(hero)
	w.skills.trigger(hero, "attack_emit", {})
	test.assert_true(absf(U.hp(hero) - hp * 0.99) < 0.01, "hell hunter pays one percent max health per attack")
	w.skills.trigger(hero, "kill", {})
	test.assert_equal(U.hp(hero), hp, "hell hunter kill heals three percent max health, capped at max")
	w.dispose()
	w = world(catalog, 12)
	hero = w.units[w.heroes[0]]
	target = enemy(w, hero.pos + Vector2(0, -350))
	w.skills.cast(hero, hero.skills[749].data, target)
	for at in range(0, 1000, 16):
		tick_spells(w, at)
	test.assert_true(w.statuses.has_status(target, 106), "bishop primary missile applies its five-second attack debuff")
	w.dispose()

func _druid_aggro(test, catalog) -> void:
	for pair in [["enemy", 101], ["boss", 105]]:
		var w = world(catalog, 2)
		var hero: Dictionary = w.units[w.heroes[0]]
		w.factory.add_hero(4)
		w.upgrades.apply(hero, 200307)
		w.skills.cast(hero, hero.skills[20301].data, {})
		var flower: Dictionary = w.skills.thorns.flowers[0]
		var target = w.factory.create(pair[0], pair[1], flower.pos, 2)
		target.core.attributes.set_value("hp", 100000)
		var choice = w.ai.choose_enemy(target)
		test.assert_true(not choice.is_empty() and choice.kind == "hero", "monster and boss target heroes, never the flower")
		var hp = U.hp(target)
		w.time_ms = 5000
		w.skills.thorns.tick()
		test.assert_true(U.hp(target) < hp, "flower still causes real natural damage")
		var blocking = w.factory.create("summon", 17, target.pos + Vector2(-5, 0), 1, hero.id)
		blocking.core.attributes.set_value("3", 1)
		w.space.rebuild()
		test.assert_true(not w.ai.choose_enemy(target).is_empty(), "explicit blocking summon remains selectable")
		w.dispose()

func _visual_contracts(test, catalog) -> void:
	for hid in catalog.available_heroes():
		var w = world(catalog, hid)
		var hero: Dictionary = w.units[w.heroes[0]]
		w.statuses.add(hero, hero, 8, 2000)
		var actor: Dictionary = w.snapshot().heroes[0]
		test.assert_equal(actor.tint, "#3399FFFF", "cold uses the source actor tint")
		w.statuses.add(hero, hero, 1, 2000)
		actor = w.snapshot().heroes[0]
		test.assert_equal(actor.status_effects[0].res, "bulletStatus:burn", "status effect uses its configured movie")
		test.assert_true(actor.status_effects[0].scale.x > 0, "status effect uses actor and resource dimensions")
		w.dispose()
	for pair in [[4, "attack"], [9, "attack"], [11, "attack"], [14, "attack"], [15, "skill"], [16, "skill2"]]:
		test.assert_true(catalog.combat().actors["hero:%d" % pair[0]].overlays.has(pair[1]), "hero action has its source overlay resource")

func _action_sequences(test, catalog) -> void:
	for hid in [1, 2, 3, 10, 12]:
		var w = world(catalog, hid)
		var hero: Dictionary = w.units[w.heroes[0]]
		var target = enemy(w, hero.pos + Vector2(0, -350))
		w.ai.attack(hero, target)
		test.assert_equal(hero.action, "attack", "combat-triggered spell starts with the normal attack animation")
		var emit_ms = 0
		for i in range(int(hero.motion.valid[0]) - 1):
			emit_ms += int(hero.motion.frames.attack[i])
		emit_ms = roundi(emit_ms / w.ai.animation_rate(hero))
		tick_spells(w, emit_ms - 1)
		test.assert_true(w.missiles.is_empty(), "combat spell waits for the source valid frame")
		tick_spells(w, emit_ms)
		if hid in [1, 2]:
			w.ai.advance_attack(hero)
		test.assert_true(not w.missiles.is_empty(), "combat spell emits at the attack valid frame")
		if hid in [3, 10]:
			test.assert_equal(hero.action, "skill2", "combat channel enters its loop directly after emission")
			test.assert_equal(hero.action_rate, 1.0, "channel animation uses raw source frame timing")
			w.time_ms += 16
			w.ai.advance_attack(hero)
			test.assert_equal(hero.action, "skill2", "channel remains active while its projectile exists")
			if hid == 3:
				for at in range(w.time_ms + 16, 4000, 16):
					w.time_ms = at
					w.ai.advance_attack(hero)
					w.skills.tick()
					w.projectiles.tick()
				test.assert_true(hero.channel_skills.is_empty(), "arcane channel ends after the whole continued missile chain")
		else:
			test.assert_equal(hero.action, "attack", "ordinary combat spell does not enter a skill animation")
		w.dispose()

func _attack_procs(test, catalog) -> void:
	var w = world(catalog, 16)
	var hero: Dictionary = w.units[w.heroes[0]]
	var target = enemy(w, hero.pos + Vector2(0, -40))
	var hp = U.hp(hero)
	w.ai.attack(hero, target)
	for event in hero.attack_events:
		w.time_ms = event.at
		w.ai.advance_attack(hero)
	test.assert_true(absf(U.hp(hero) - hp * 0.99) < 0.01, "attack cost occurs at emission, before animation ends")
	test.assert_true(w.time_ms < hero.action_until, "health-cost assertion uses a live attack frame")
	w.ai.advance_attack(hero)
	test.assert_true(absf(U.hp(hero) - hp * 0.99) < 0.01, "attack proc cannot repeat on the same emitted frame")
	hero.skills.erase(1326)
	w.skills.learn(hero, 1096)
	hero.skills[1096].data.triggerOpp = ["15:0"]
	w.skills.trigger(hero, "attack_emit", {})
	test.assert_true(not w.missiles.any(func(p): return int(p.skill.get("__id__", 0)) == 1096), "zero-percent attack proc cannot produce its effect")
	hero.skills[1096].data.triggerOpp = ["15:4"]
	for i in range(200):
		w.skills.trigger(hero, "attack_emit", {})
	var procs = w.missiles.filter(func(p): return int(p.skill.get("__id__", 0)) == 1096).size()
	test.assert_true(procs > 0 and procs < 50, "source four-percent proc cannot fire on every attack")
	w.dispose()
