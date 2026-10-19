extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Fixture = preload("res://tests/test_defense_hero_roster.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
var fixture = Fixture.new()

func run(test) -> void:
	var catalog = Catalog.new()
	var error = catalog.load_default()
	test.assert_equal(error, "", "ranged range fixtures load current data")
	if not error.is_empty():
		return
	for hid in [1, 2, 13]:
		_basic(test, catalog, hid)
	for params in [[1, 17, 1000], [13, 20002, 750]]:
		_skill(test, catalog, params)
	_outside(test, catalog, 1, 17, Vector2(350, 0))
	_outside(test, catalog, 13, 20002, Vector2(800, 100))
	_cached_exit(test, catalog)
	_cooldown(test, catalog)

func world(catalog, hid: int):
	var w = fixture.world(catalog, hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.pos = hero.home
	for state in hero.skills.values():
		state.next = 1000000
	return w

func enemy(w, point: Vector2) -> Dictionary:
	var target = fixture.enemy(w, point)
	target["busy_until"] = 1000000
	return target

func _basic(test, catalog, hid: int) -> void:
	var w = world(catalog, hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	var target = enemy(w, hero.pos - Vector2(0, U.stat(hero, 26) - 100))
	test.assert_true(target.pos.y < 850, "basic attack fixture is beyond the obsolete horizontal targeting line")
	test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), target.id, "in-range ordinary enemies can be acquired at any map Y")
	for tick in range(400):
		w.step()
	test.assert_true(hero.attacks > 0 and hero.stats.damage > 0, "ranged hero %d really fires and hits inside basic range" % hid)
	test.assert_equal(hero.pos, hero.home, "ordinary ranged attacks preserve the rear formation")
	w.dispose()

func _skill(test, catalog, params: Array) -> void:
	var w = world(catalog, params[0])
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.attack_at = 1000000
	hero.skills[params[1]].next = 0
	var target = enemy(w, hero.pos - Vector2(0, params[2]))
	test.assert_true(w.ai.choose_enemy(hero).is_empty(), "a skill-only target does not become an out-of-range basic chase target")
	for tick in range(500):
		w.step()
	test.assert_true(hero.skills[params[1]].next > 0 and hero.stats.damage > 0, "ready ranged skill %d hits a target inside its independent range above the old line" % params[1])
	test.assert_equal(hero.attacks, 0, "independent skill range does not extend the ordinary basic attack")
	test.assert_equal(hero.pos, hero.home, "ranged skill fires from formation without chasing its target")
	test.assert_true(not target.dead, "ranged skill fixture observes real damage rather than a forced kill")
	w.dispose()

func _outside(test, catalog, hid: int, sid: int, point: Vector2) -> void:
	var w = world(catalog, hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.skills[sid].next = 0
	enemy(w, point)
	for tick in range(160):
		w.step()
	test.assert_equal(hero.stats.damage, 0.0, "an ordinary target outside both actual ranges is not hit")
	test.assert_equal(hero.skills[sid].next, 0, "out-of-range target does not consume the ready skill")
	test.assert_equal(hero.pos, hero.home, "ranged hero does not chase an ordinary out-of-range target")
	w.dispose()

func _cached_exit(test, catalog) -> void:
	var w = world(catalog, 13)
	var hero: Dictionary = w.units[w.heroes[0]]
	var target = enemy(w, Vector2(hero.home.x, 100))
	hero.target = target.id
	hero.ai_at = 10000
	w.ai.tick()
	test.assert_equal(hero.target, 0, "cached basic target is released as soon as it leaves range")
	test.assert_equal(hero.pos, hero.home, "cached target cannot drag a ranged hero forward between retarget ticks")
	w.dispose()

func _cooldown(test, catalog) -> void:
	var w = world(catalog, 13)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.attack_at = 10000
	hero.skills[20002].next = 10000
	enemy(w, hero.pos + Vector2(0, -400))
	for tick in range(120):
		w.step()
	test.assert_true(hero.attacks == 0 and hero.stats.damage == 0, "being in range still respects basic and skill cooldowns")
	test.assert_equal(hero.skills[20002].next, 10000, "targeting repair does not reset or shorten cooldown")
	w.dispose()
