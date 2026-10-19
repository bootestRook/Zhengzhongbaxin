extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Fixture = preload("res://tests/test_defense_hero_skill_contracts.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
var fixture = Fixture.new()

func world(catalog):
	var w = fixture.world(catalog, 13)
	var hero: Dictionary = w.units[w.heroes[0]]
	for pair in [["4", 100], ["7", 0], ["12", 0], ["10", 0]]:
		hero.core.attributes.set_value(pair[0], pair[1])
	return w

func choose(w, term: int) -> void:
	w.pending.clear()
	w.offers = [w.choices.card(w.catalog.record("options", 200000 + term), w.heroes[0])]
	w.phase = "choice"
	assert(w.choices.choose(0).is_empty())

func step(w, end: int) -> void:
	for at in range(w.time_ms, end + 1, 16):
		w.time_ms = at
		w.skills.tick()
		w.projectiles.tick()
		w.statuses.tick()

func run(test) -> void:
	var catalog = Catalog.new()
	assert(catalog.load_default().is_empty())
	_library(test, catalog)
	_damage(test, catalog)
	_control(test, catalog)
	_rain(test, catalog)
	_derivation(test, catalog)
	_projectile_edges(test, catalog)
	preload("res://tests/test_defense_ice_scope.gd").new().run(test, catalog, self)
	_draws(test, catalog)

func _library(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	test.assert_equal(hero.upgrades, [200400], "recruitment automatically grants only multishot")
	test.assert_true(not w.choices.eligible(catalog.record("options", 200400), hero), "recruitment term never reappears as an upgrade")
	var pool: Array = w.choices.upgrade_pool().map(func(item): return item.id)
	pool.sort()
	test.assert_equal(pool, [200401, 200402, 200403, 200405, 200407], "exact initial upgrade pool")
	for id in [1076, 1077, 1078, 1079, 1080, 1093, 1097, 1098, 1099]:
		test.assert_true(catalog.record("options", id).is_empty(), "obsolete ice branches removed")
	choose(w, 401)
	test.assert_true(w.choices.eligible(catalog.record("options", 200401), hero), "damage can be selected twice")
	choose(w, 401)
	test.assert_true(not w.choices.eligible(catalog.record("options", 200401), hero), "third damage selection prohibited")
	choose(w, 402)
	test.assert_true(not w.choices.eligible(catalog.record("options", 200409), hero), "star arrow requires all three prerequisites")
	for term in [403, 404, 405, 406, 407, 408, 409]:
		choose(w, term)
	test.assert_true(w.choices.upgrade_pool().is_empty(), "all terms exhausted at their caps")
	test.assert_equal(hero.skills[20002].data.ice_arrows.bonus, 210.0, "all damage bonuses add to 155 percent attack coefficient")
	test.assert_equal(catalog.record("skills", 20002).ice_arrows.bonus, 0, "definition stays immutable")
	test.assert_equal(w.snapshot().heroes[0].skills[0].title, "星辰之箭", "upgraded live name is synchronized")
	w.dispose()

func _damage(test, catalog) -> void:
	for count in [0, 1, 2]:
		var w = world(catalog)
		var hero: Dictionary = w.units[w.heroes[0]]
		for i in range(count):
			choose(w, 401)
		var enemy = fixture.enemy(w, hero.pos + Vector2(0, -200))
		w.skills.ice.arrow(hero, hero.skills[20002].data, enemy, false, {"knocked": []}, Vector2.INF)
		step(w, 1000)
		test.assert_true(absf(100000 - U.hp(enemy) - (50 + count * 30)) < 0.01, "actual arrow damage is 50, 80, 110 percent")
		w.missiles.clear()
		w.ai.emit_attack(hero, {"target": enemy.id, "wall": false})
		step(w, 2000)
		test.assert_true(absf(100000 - U.hp(enemy) - (150 + count * 30)) < 0.01, "skill bonuses never increase basic attack damage")
		w.dispose()

func _control(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	for term in [402, 403, 405, 406, 407]:
		choose(w, term)
	var config: Dictionary = hero.skills[20002].data.ice_arrows
	var target = fixture.enemy(w, hero.pos + Vector2(0, -150))
	var speed = U.stat(target, 17)
	for i in range(4):
		w.skills.ice.chill(hero, target, config)
	test.assert_true(absf(U.stat(target, 17) - speed * 0.6) < 0.01, "four chills reduce actual movement speed by forty percent")
	w.skills.ice.chill(hero, target, config)
	test.assert_true(w.statuses.prevents(target, "move") and w.statuses.prevents(target, "attack"), "fifth chill really freezes movement and attacks")
	test.assert_true(not w.statuses.has_status(target, 20401), "freezing consumes chill stacks")
	w.time_ms = 3000
	w.statuses.tick()
	test.assert_true(not w.statuses.prevents(target, "move"), "freeze expires after three seconds")
	for i in range(45):
		w.skills.ice.gain_focus(hero, hero.skills[20002].data)
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 40, "focus caps at forty skill-owned stacks")
	test.assert_true(U.stat(hero, 4) == 100 and U.stat(hero, 12) == 0, "focus cannot modify hero attributes")
	w.time_ms = 6999
	w.statuses.tick()
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 40, "focus retains its full group until expiry")
	w.time_ms = 7000
	w.statuses.tick()
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 0, "focus expires at exactly four seconds")
	config.knock_chance = 100
	var from: Vector2 = target.pos
	w.skills.cast(hero, hero.skills[20002].data, target)
	step(w, 7500)
	test.assert_true(target.has("forced_motion"), "actual arrow hit starts displacement")
	w.time_ms += 200
	w.ai.forced_move(target)
	test.assert_true(absf(target.pos.distance_to(from) - 80) < 0.01, "salvo shares one exact eighty-unit knockback budget")
	w.dispose()

func _rain(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	var point = hero.pos + Vector2(0, -200)
	var target = fixture.enemy(w, point)
	var outside = fixture.enemy(w, point + Vector2(300, 0))
	w.skills.ice.rain(hero, hero.skills[20002].data, point)
	var p: Dictionary = w.missiles[-1]
	test.assert_equal(100000 - U.hp(target), 100.0, "rain damages immediately")
	test.assert_equal(U.hp(outside), 100000.0, "rain respects its circular radius")
	step(w, 1100)
	test.assert_true(not w.statuses.prevents(target, "move"), "later rain ticks do not refresh first-hit freeze")
	var late = fixture.enemy(w, point)
	step(w, 4100)
	test.assert_equal(100000 - U.hp(target), 500.0, "rain deals exactly five real hundred-percent ticks")
	test.assert_equal(100000 - U.hp(late), 300.0, "late entrants only receive remaining ticks")
	test.assert_equal(p.pos, point, "rain stays at its original world position")
	step(w, 5200)
	test.assert_true(w.missiles.is_empty(), "rain ends after five seconds without a sixth tick")
	test.assert_true(w.skills.queue.is_empty(), "rain cannot create recursive skill triggers")
	w.dispose()

func _derivation(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	for term in [401, 402, 403, 404, 405, 407, 409]:
		choose(w, term)
	var target = fixture.enemy(w, hero.pos + Vector2(0, -180))
	var other = fixture.enemy(w, target.pos + Vector2(180, 0))
	hero.skills[20002].data.ice_arrows.combo_chance = 100
	w.skills.cast(hero, hero.skills[20002].data, target)
	test.assert_equal(w.missiles.size(), 4, "original cast emits only its four lanes immediately")
	test.assert_equal(w.skills.queue.size(), 1, "combo waits in the actual skill queue")
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 1, "one whole cast stacks focus once")
	step(w, 288)
	test.assert_true(w.events.filter(func(e): return e.type == "skill_combo").is_empty(), "combo cannot emit before three hundred milliseconds")
	step(w, 304)
	test.assert_equal(w.missiles.filter(func(p): return p.start == 304 and p.skill.has("ice_shot") and not p.skill.ice_shot.bounced).size(), 4, "next fixed step emits four additional arrows after three hundred milliseconds")
	test.assert_equal(w.events.filter(func(e): return e.type == "skill_combo").size(), 1, "one extra volley never recursively schedules another combo")
	step(w, 2500)
	test.assert_true(U.hp(other) < 100000, "real star arrows hit secondary enemies")
	test.assert_true(w.missiles.is_empty() and w.skills.queue.is_empty(), "folded combo and refraction chains terminate")
	test.assert_equal(w.skills.ice.focus_stacks(hero, 20002), 1, "pierce and refraction never multiply focus stacks")
	w.dispose()

func _draws(test, catalog) -> void:
	var w = world(catalog)
	for mode in ["upgrade", "bonus", "chest"]:
		var ids: Dictionary = {}
		for i in range(300):
			var item: Dictionary = w.loot.roll() if mode == "chest" else w.choices.roll_upgrade(w.rng.stream("defense.choice"), [], w.heroes[0] if mode == "bonus" else 0)
			ids[item.id] = true
			test.assert_true(item.id != 200400 and w.choices.eligible(w.choices.options[str(item.id)], w.units[item.owner]), "all reward paths exclude recruitment term and illegal upgrades")
		test.assert_equal(ids.size(), 5, "all three reward paths reach all initial legal terms")
	w.dispose()

func _projectile_edges(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	choose(w, 402)
	var main = fixture.enemy(w, hero.pos + Vector2(0, -150))
	var behind = fixture.enemy(w, hero.pos + Vector2(0, -270))
	var skill: Dictionary = hero.skills[20002].data
	w.skills.ice.arrow(hero, skill, main, false, {"knocked": []}, Vector2.INF)
	step(w, 1500)
	test.assert_equal(100000 - U.hp(main), 60.0, "main arrow hits its intended primary target exactly once")
	test.assert_equal(100000 - U.hp(behind), 60.0, "penetration actually damages one additional enemy")
	w.dispose()
	w = world(catalog)
	hero = w.units[w.heroes[0]]
	for term in [401, 402, 405, 409]:
		choose(w, term)
	main = fixture.enemy(w, hero.pos + Vector2(0, -150))
	behind = fixture.enemy(w, main.pos + Vector2(200, 0))
	skill = hero.skills[20002].data
	w.skills.ice.arrow(hero, skill, main, false, {"knocked": []}, Vector2.INF)
	step(w, 1800)
	test.assert_equal(100000 - U.hp(main), 90.0, "star direct damage inherits eighty-percent combined bonus")
	test.assert_equal(100000 - U.hp(behind), 90.0, "refraction deals equal inherited damage once")
	test.assert_equal(behind.statuses[0].stacks, 1, "refraction inherits exactly one chill application")
	test.assert_true(w.missiles.is_empty(), "refraction cannot bounce back indefinitely")
	w.dispose()
