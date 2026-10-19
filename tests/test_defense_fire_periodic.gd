extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")

func run(test, catalog, flow) -> void:
	for conversion in [false, true]:
		var w = flow.world(catalog)
		var hero: Dictionary = w.units[w.heroes[0]]
		for id in [201, 203, 204]:
			flow.choose(w, id)
		if conversion:
			flow.choose(w, 208)
		var enemy = flow.fixture.enemy(w, hero.pos + Vector2(0, -350))
		w.skills.fireball.impact(hero, enemy, hero.skills[17].data.fireball)
		flow.step(w, 0)
		var before = U.hp(enemy)
		for at in range(16, 6017, 16):
			if conversion and at == 2016:
				hero.core.attributes.set_value("6", 200)
			flow.step(w, at)
		var expected = 920.0 if conversion else 800.0
		test.assert_equal(snappedf(before - U.hp(enemy), 0.01), expected, "burn gets five and ember three ticks, without explosion bonuses, with dynamic conversion")
		test.assert_true(not w.statuses.has_status(enemy, 20201), "burn expires after its fifth actual damage tick")
		test.assert_true(not w.missiles.any(func(p): return p.skill.get("fireball_ember", false)), "ember ends after third actual pulse")
		w.dispose()
	_refresh(test, catalog, flow)
	_pierce(test, catalog, flow)

func _refresh(test, catalog, flow) -> void:
	var w = flow.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	var enemy = flow.fixture.enemy(w, hero.pos + Vector2(0, -350))
	w.statuses.add(enemy, hero, 20201, 5000)
	w.time_ms = 500
	w.statuses.add(enemy, hero, 20201, 5000)
	test.assert_equal(enemy.statuses.size(), 1, "same caster refreshes burn without stacking")
	test.assert_equal(enemy.statuses[0].next, 1000, "frequent explosion cannot postpone burn indefinitely")
	for at in range(512, 6017, 16):
		flow.step(w, at)
	test.assert_equal(U.hp(enemy), 99500.0, "refresh preserves five real periodic damage ticks")
	w.time_ms = 7000
	for id in [201, 204]:
		flow.choose(w, id)
	w.skills.fireball.impact(hero, enemy, hero.skills[17].data.fireball)
	w.skills.fireball.impact(hero, enemy, hero.skills[17].data.fireball)
	flow.step(w, 7000)
	var before = U.hp(enemy)
	for at in range(7016, 11017, 16):
		flow.step(w, at)
	test.assert_equal(before - U.hp(enemy), 300.0, "overlapping same-caster embers never double periodic damage")
	w.dispose()

func _pierce(test, catalog, flow) -> void:
	for dense in [false, true]:
		var w = flow.world(catalog)
		var hero: Dictionary = w.units[w.heroes[0]]
		for id in [201, 202, 210]:
			flow.choose(w, id)
		for i in range(5):
			flow.fixture.enemy(w, hero.pos + Vector2(0, -200 - i * (1 if dense else 180)))
		w.skills.fireball.release(hero, hero.skills[17].data.fireball)
		var projectile: Dictionary = w.missiles[0]
		for i in range(5):
			var enemy: Dictionary = w.units.values().filter(func(u): return u.side == 2)[i]
			enemy.pos = projectile.from + projectile.direction * (220 + i * (1 if dense else 180))
		var blast_ids: Dictionary = {}
		for at in range(0, 1800, 16):
			flow.step(w, at)
			for p in w.missiles:
				if p.skill.get("fire_phase", "") == "blast":
					blast_ids[p.id] = true
		test.assert_equal(projectile.hits.size(), 3, "pyroblast hits at most three distinct enemies even in one dense collision tick")
		test.assert_equal(blast_ids.size(), 3, "each piercing hit produces exactly one explosion")
		test.assert_true(projectile.ended, "pyroblast ends immediately after third hit")
		test.assert_equal(projectile.res, "bullet:fireball2", "pyroblast uses its upgraded projectile animation")
		w.dispose()
