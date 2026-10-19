extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")

func run(test, catalog, suite) -> void:
	_basics(test, catalog, suite)
	_focus_damage(test, catalog, suite)
	_focus_lifetime(test, catalog, suite)

func _basics(test, catalog, suite) -> void:
	var w = suite.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	for term in [401, 401, 402, 403, 404, 405, 406, 407, 408, 409]:
		suite.choose(w, term)
	var skill: Dictionary = hero.skills[20002].data
	for key in ["combo_chance", "knock_chance", "rain_chance"]:
		skill.ice_arrows[key] = 100
	for i in range(45):
		w.skills.ice.gain_focus(hero, skill)
	var focus: Dictionary = hero.skills[20002].ice_focus.duplicate()
	var main = suite.fixture.enemy(w, hero.pos + Vector2(0, -160))
	var behind = suite.fixture.enemy(w, main.pos + Vector2(0, -100))
	var beside = suite.fixture.enemy(w, main.pos + Vector2(100, 0))
	var rng: Dictionary = w.rng.stream("defense.combat").snapshot()
	w.ai.emit_attack(hero, {"target": main.id, "wall": false})
	test.assert_equal(w.missiles.size(), 1, "all ten ice terms leave basic attacks as a single arrow")
	test.assert_equal(w.missiles[0].kind, 0, "basic attacks use the ordinary projectile pipeline")
	test.assert_true(w.missiles[0].skill.is_empty(), "basic arrows carry no ice term payload")
	test.assert_equal(w.rng.stream("defense.combat").snapshot(), rng, "basic emission never rolls ice combo or rain probabilities")
	suite.step(w, 1000)
	test.assert_equal(U.hp(main), 99900.0, "even forty focus stacks cannot increase real basic attack damage")
	test.assert_equal(U.hp(behind), 100000.0, "basic attacks never inherit piercing")
	test.assert_equal(U.hp(beside), 100000.0, "basic attacks never inherit refraction or rain")
	test.assert_true(main.statuses.is_empty(), "basic hit cannot apply chill or freeze")
	test.assert_true(not main.has("forced_motion"), "basic hit cannot knock back")
	test.assert_true(w.missiles.is_empty(), "basic hit cannot create a combo or lingering rain")
	test.assert_equal(hero.skills[20002].ice_focus, focus, "basic attacks cannot add, consume or refresh skill focus")
	test.assert_true(U.stat(hero, 4) == 100 and U.stat(hero, 12) == 0, "skill focus never leaks into global hero attributes")
	w.skills.cast(hero, skill, main)
	test.assert_equal(w.missiles.filter(func(p): return p.skill.has("ice_shot")).size(), 4, "the original four skill trajectories emit immediately")
	test.assert_equal(w.skills.queue.filter(func(e): return e.get("ice_combo", false)).size(), 1, "the additional four trajectories wait for the combo interval")
	test.assert_equal(w.missiles.filter(func(p): return p.skill.has("ice_rain")).size(), 1, "only a real skill cast can generate rain")
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 40, "real skill cast retains the focus cap")
	test.assert_true(hero.skills[20002].ice_focus.until > focus.until, "real skill cast refreshes its own focus duration")
	var until: int = hero.skills[20002].ice_focus.until
	var repeat_at: int = w.time_ms + 304
	suite.step(w, repeat_at)
	test.assert_equal(w.missiles.filter(func(p): return p.start == repeat_at and p.skill.has("ice_shot") and not p.skill.ice_shot.bounced).size(), 4, "delayed combo emits four skill arrows after the interval")
	test.assert_equal(w.missiles.filter(func(p): return p.skill.has("ice_rain")).size(), 1, "delayed combo cannot generate another rain")
	test.assert_equal(hero.skills[20002].ice_focus.until, until, "delayed combo cannot refresh focus")
	w.dispose()

func _focus_damage(test, catalog, suite) -> void:
	var w = suite.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	suite.choose(w, 407)
	var skill: Dictionary = hero.skills[20002].data
	for i in range(40):
		w.skills.ice.gain_focus(hero, skill)
	var target = suite.fixture.enemy(w, hero.pos + Vector2(0, -160))
	w.skills.ice.arrow(hero, skill, target, false, {"knocked": []}, Vector2.INF)
	suite.step(w, 1000)
	test.assert_true(absf(100000 - U.hp(target) - 98) < 0.01, "forty focus stacks give skill-only attack and magic bonuses: 140 times fifty percent times 1.4")
	var plain: Dictionary = skill.duplicate(true)
	plain.erase("ice_arrows")
	w.damage.apply_skill(hero, target, plain)
	test.assert_true(absf(100000 - U.hp(target) - 148) < 0.01, "a different ordinary damage path cannot read private skill focus")
	w.dispose()

func _focus_lifetime(test, catalog, suite) -> void:
	var w = suite.world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	suite.choose(w, 407)
	var skill: Dictionary = hero.skills[20002].data
	w.skills.ice.gain_focus(hero, skill)
	w.time_ms = 3999
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 1, "skill focus remains valid before its exact deadline")
	w.time_ms = 4000
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 0, "skill focus expires at its exact deadline")
	w.skills.ice.gain_focus(hero, skill)
	hero.dead = true
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 0, "death invalidates private focus")
	hero.dead = false
	w.skills.ice.gain_focus(hero, skill)
	hero.death_count += 1
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 0, "revival cannot retain focus from a previous life")
	w.dispose()
