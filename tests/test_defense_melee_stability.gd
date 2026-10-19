extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	for seed_value in [6, 17, 81]:
		_battle(test, catalog, seed_value)
	_battle(test, catalog, 1, [5, 4, 17, 1, 2])
	_contact(test, catalog)

func _contact(test, catalog) -> void:
	for template in [106, 112, 103, 107, 113]:
		for x in [600, 1000]:
			var w = Session.new(catalog)
			w.level_id = 5
			w.start(81)
			w.spawn_wave = 1
			w.factory.add_hero(5)
			var hero: Dictionary = w.units[w.heroes[0]]
			hero.pos = hero.home
			hero.entering = false
			hero.skills.clear()
			var enemy = w.factory.create("enemy", template, Vector2(x, 900), 2)
			enemy.skills.clear()
			for u in [hero, enemy]:
				u.core.attributes.set_value("1", 1000000)
				u.core.attributes.set_value("hp", 1000000)
			var previous_change = -1000
			var stutters = 0
			var flips = 0
			var previous_flip = -1000
			for tick in range(1200):
				var action: String = hero.action
				var facing: float = hero.facing
				w.time_ms += 16
				w.space.rebuild()
				w.navigation.rebuild()
				w.ai.tick()
				if hero.action != action:
					if action == "walk" and hero.action == "idle" and w.time_ms - previous_change <= 32:
						stutters += 1
					previous_change = w.time_ms
				if hero.facing != facing:
					if w.time_ms - previous_flip <= 48:
						flips += 1
					previous_flip = w.time_ms
			test.assert_true(hero.attacks > 2, "commander sustains attacks against moving monster %d from X%d" % [template, x])
			test.assert_equal(stutters, 0, "no one-frame chase against moving monster %d from X%d" % [template, x])
			test.assert_equal(flips, 0, "no facing flicker against moving monster %d from X%d" % [template, x])
			print("[MOVING CONTACT] ", JSON.stringify({"template": template, "x": x, "stutters": stutters, "flips": flips, "attacks": hero.attacks}))
			w.dispose()

func _battle(test, catalog, seed_value: int, heroes: Array = [5]) -> void:
	var w = Session.new(catalog)
	w.level_id = 5
	w.start(seed_value)
	for hid in heroes:
		w.factory.add_hero(hid)
	w.phase = "playing"
	var hero: Dictionary = w.units[w.heroes[0]]
	var previous_change = -1000
	var stutters = 0
	for i in range(7500):
		while w.phase in ["choice", "reward"]:
			if w.phase == "choice":
				w.choices.choose(0)
			else:
				w.submit("reward_close", {"id": w.loot.current.id})
		if w.phase != "playing":
			break
		var action: String = hero.action
		var target: int = hero.target
		w.step()
		if hero.action != action:
			if action == "walk" and hero.action == "idle" and hero.target == target and w.time_ms - previous_change <= 32:
				stutters += 1
			previous_change = w.time_ms
	test.assert_true(hero.attacks > 0, "level 5 seed %d actually enters combat" % seed_value)
	test.assert_equal(stutters, 0, "level 5 seed %d has no one-frame chase/idle stutters" % seed_value)
	print("[MELEE STABILITY] ", JSON.stringify({"seed": seed_value, "stutters": stutters, "attacks": hero.attacks, "time": w.time_ms}))
	w.dispose()
