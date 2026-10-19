extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_growth(test, catalog)
	_entry_speed(test, catalog)
	_hero_boundaries(test, catalog)
	_return(test, catalog)
	_ranged_return(test, catalog)
	_melee_contact(test, catalog)
	_finish(test, catalog)

func world(catalog):
	var w = Session.new(catalog)
	w.start(81)
	w.spawn_wave = 1
	w.phase = "playing"
	return w

func _growth(test, catalog) -> void:
	var w = world(catalog)
	w.level_id = 3
	w.level = catalog.record("levels", 3)
	var mouse = w.factory.create("enemy", 101, Vector2(800, 600), 2)
	test.assert_equal(U.stat(mouse, 1), 192.0, "level 3 mouse includes level HP +9 and chapter HP +1")
	test.assert_equal(U.stat(mouse, 4), 23.0, "level 3 mouse includes level attack +2")
	var entry: Dictionary = w.level.waves[0].entries[0].duplicate(true)
	entry.atk_multiplier = 2.0
	var scaled = w.factory.create("enemy", 101, Vector2(900, 600), 2, 0, entry)
	test.assert_equal(U.stat(scaled, 4), 46.0, "row attack coefficient applies after level growth")
	w.dispose()

func _entry_speed(test, catalog) -> void:
	var w = world(catalog)
	var mouse = w.factory.create("enemy", 101, Vector2(800, 549), 2)
	mouse.skills.clear()
	test.assert_equal(w.ai.movement_speed(mouse), 120.0, "first-wave speed 40 plus 200 percent entry bonus")
	w.statuses.definitions["999"] = {"attributeRev": ["17:-20:2"]}
	w.statuses.add(mouse, mouse, 999, 1000)
	test.assert_equal(w.ai.movement_speed(mouse), 112.0, "slow and entry speed percentages add rather than multiply")
	mouse.pos.y = 550
	w.ai.move(mouse, Vector2(800, 800), true, false)
	test.assert_equal(mouse.entry_speed_bonus, 0.0, "entry acceleration ends at Y550")
	test.assert_true(mouse.pos.y > 550 and mouse.pos.y < 551, "post-line displacement uses slowed base speed")
	w.dispose()

func _hero_boundaries(test, catalog) -> void:
	for hid in catalog.available_heroes():
		var w = world(catalog)
		w.factory.add_hero(hid)
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.entering = false
		hero.skills.clear()
		hero.pos = Vector2(800, 1500)
		var enemy = w.factory.create("enemy", 101, Vector2(hero.pos.x, 650), 2)
		if hero.front:
			test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), enemy.id, "front hero %d actively acquires enemies inside the red box" % hid)
		else:
			test.assert_true(w.ai.choose_enemy(hero).is_empty(), "ranged hero %d does not chase an ordinary enemy outside basic range" % hid)
		enemy.pos.y = 900 if hero.front else 1300
		w.targets.score_cache.clear()
		test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), enemy.id, "hero %d acquires within its current defense region" % hid)
		w.targets.score_cache.clear()
		test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), enemy.id, "hero %d keeps valid middle-lower targets while formation returns" % hid)
		w.dispose()

func _return(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(4)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.skills.clear()
	hero.pos = hero.home
	hero.back_lock = true
	var enemy = w.factory.create("enemy", 101, Vector2(800, 900), 2)
	enemy["busy_until"] = 100000
	w.space.rebuild()
	w.ai.tick()
	test.assert_true(not hero.back_lock, "acquiring a target releases home lock")
	w.damage.defeat(enemy, {})
	hero.pos = Vector2(850, 1000)
	var before: Vector2 = hero.pos
	w.ai.return_home(hero)
	test.assert_true(hero.pos != before, "front hero returns after target death")
	var threat = w.factory.create("enemy", 101, Vector2(1200, 900), 2)
	hero.pos = Vector2(950, 650)
	hero.home = Vector2(800, 950)
	hero.back_lock = false
	w.ai.return_home(hero)
	test.assert_true(hero.pos.y > 650, "front hero with rear threats recovers vertically toward the middle-lower guard position")
	hero.core.attributes.set_value("17", 0)
	w.ai.move(hero, Vector2(800, 950))
	test.assert_equal(hero.action, "idle", "stationary units do not show walking")
	w.dispose()

func _finish(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(1)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	var boss = w.factory.create("boss", 105, Vector2(800, 100), 2)
	test.assert_true(w.ai.choose_enemy(hero).is_empty(), "ordinary early boss does not ignore patrol line")
	w.spawn_wave = 20
	w.targets.score_cache.clear()
	test.assert_equal(w.ai.choose_enemy(hero).id, boss.id, "final sparse boss encounter allows chase beyond patrol")
	for i in range(8):
		w.factory.create("enemy", 101, Vector2(800, 100), 2)
	test.assert_true(not w.targets.can_finish_chase(), "nine enemies retain ordinary patrol boundary")
	w.dispose()

func _ranged_return(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(1)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.skills.clear()
	hero.pos = Vector2(800, 850)
	hero.attack_at = 1000
	var enemy = w.factory.create("enemy", 101, Vector2(800, 800), 2)
	w.space.rebuild()
	test.assert_true(w.ai.recover_firing_position(hero, enemy), "ranged hero returns between attacks if home still covers target")
	test.assert_true(hero.pos.y > 850, "ranged return moves toward its rear formation slot")
	enemy.pos = Vector2(800, 600)
	test.assert_true(not w.ai.recover_firing_position(hero, enemy), "ranged hero keeps forward position when home cannot cover target")
	w.dispose()

func _melee_contact(test, catalog) -> void:
	# Level 5 enemies have attack origins far outside their bodies.
	# Reaching that origin must not strand a melee hero outside striking range.
	for template in [106, 112, 103, 107, 113]:
		for facing in [-1.0, 1.0]:
			for x in [600, 1000]:
				var w = world(catalog)
				w.level_id = 5
				w.level = catalog.record("levels", 5)
				w.factory.add_hero(5)
				var hero: Dictionary = w.units[w.heroes[0]]
				hero.entering = false
				hero.skills.clear()
				hero.pos = hero.home
				var enemy = w.factory.create("enemy", template, Vector2(x, 900), 2)
				enemy.facing = facing
				enemy.busy_until = 100000
				enemy.core.attributes.set_value("1", 1000000)
				enemy.core.attributes.set_value("hp", 1000000)
				hero.facing = -1.0 if enemy.pos.x > hero.pos.x else 1.0
				var contact = hero.duplicate()
				contact.pos = Geometry.approach(hero, enemy)
				test.assert_true(Geometry.intersects(contact, enemy), "melee approach overlaps monster %d body facing %d" % [template, facing])
				for tick in range(1000):
					w.time_ms += 16
					w.space.rebuild()
					w.navigation.rebuild()
					w.ai.tick()
					if hero.attacks > 0:
						break
				test.assert_true(hero.attacks > 0, "commander reaches and attacks monster %d facing %d from X%d" % [template, facing, x])
				w.dispose()
