extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Area = preload("res://src/features/defense/domain/defense_area.gd")

func run(test) -> void:
	_area_formula(test)
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "reference catalog loads")
	_row_spawn_contract(test, catalog)
	test.assert_equal(catalog.available_heroes(), [1, 2, 4, 13, 17], "initial roster contains exactly the five unlocked heroes")
	var world = Session.new(catalog)
	test.assert_equal(world.submit("select_level", {"level": 51}), "无效关卡", "reject out-of-campaign level")
	for id in catalog.level_ids():
		test.assert_equal(world.submit("select_level", {"level": id}), "", "all five levels selectable")
		world.start(17)
		test.assert_equal(world.level.waves.size(), 20, "campaign has twenty waves")
		var slots = 0
		for wave in world.level.waves:
			slots += int(wave.count)
		test.assert_true(slots > 0, "campaign waves contain configured row totals")
		test.assert_equal(world.level.encounters.size(), catalog.record("levels", id).encounters.size(), "encounter definitions follow the source table")
		world.finish(false)
		world.submit("home")
	world.submit("select_level", {"level": 1})
	world.start(3)
	test.assert_equal(world.submit("choose", {"index": -1}), "当前无法选择", "invalid choice cannot mutate")
	var fire_index := -1
	for i in range(world.offers.size()):
		if world.offers[i].id == 1:
			fire_index = i
	test.assert_equal(world.submit("choose", {"index": fire_index}), "", "choosing the fire mage starts battle")
	var first: Dictionary = world.units[world.heroes[0]]
	test.assert_true(first.skills.has(21), "initial fireball chain is learned")
	test.assert_true(world.choices.eligible(catalog.record("options", 201), first), "the retained fireball tree unlocks its legal follow-up")
	world.submit("pause")
	world.step()
	test.assert_equal(world.time_ms, 0, "pause stops all logical time")
	world.submit("pause")
	test.assert_true(not first.skills.has(25), "the removed flame lance is not learned")
	var amount = first.skills[17].data.fireball.blast_bonus
	world.upgrades.apply(first, 201)
	test.assert_true(first.skills[17].data.fireball.blast_bonus > amount, "upgrade changes the actual fireball explosion")
	test.assert_true(not catalog.record("skills", 22).has("bonus_damage"), "definition remains immutable")
	world.upgrades.apply(first, 203)
	test.assert_true(first.skills[17].data.fireball.burn_seconds == 5, "fireball upgrade attaches burn to hits")
	_statuses_and_revival(test, world, first)
	world.dispose()
	_trigger_rules(test, catalog)
	_hero_attacks(test, catalog)
	var first_run = _full_run(catalog, 6)
	print("[FULL RUN] ", JSON.stringify(first_run))
	var second_run = _full_run(catalog, 6)
	test.assert_equal(first_run, second_run, "seed replays choices, spawns and damage deterministically")
	test.assert_equal(first_run.phase, "result", "complete run reaches result")
	test.assert_true(first_run.won, "legal combat build wins first level")
	test.assert_equal(first_run.encounters.size(), catalog.record("levels", 1).encounters.size(), "victory result uses the configured encounter rows")
	test.assert_equal(first_run.wave, 20, "victory reached final wave")

func _area_formula(test) -> void:
	for sample in [[25.0, 1.11803398875], [50.0, 1.22474487139], [100.0, 1.41421356237], [200.0, 1.73205080757], [300.0, 2.0]]:
		test.assert_true(absf(Area.radius(100.0, sample[0]) / 100.0 - sample[1]) < 0.000001,
			"circular area percent %s uses the square-root radius multiplier" % sample[0])
	test.assert_true(absf(Area.radius(100.0, 20.0 + 30.0) - Area.radius(100.0, 50.0)) < 0.000001,
		"stacked area percentages add before the square root")
	test.assert_true(absf(Area.radius(100.0, -100.0)) < 0.000001,
		"area reductions cannot produce a negative radius")

func _row_spawn_contract(test, catalog) -> void:
	test.assert_equal(catalog.level_ids(), [1, 2, 3, 4, 5], "only the five configured levels are exposed")
	for level: Dictionary in catalog.records("levels").values():
		for wave: Dictionary in level.waves:
			test.assert_true(not wave.has("enemy_pool") and not wave.has("weights"), "row spawn waves do not carry monster pools")
			test.assert_true(wave.entries.all(func(entry): return entry.kind in ["normal", "elite", "boss"]), "blank/2/3 rows compile to explicit kinds")
	var w = Session.new(catalog)
	w.level_id = 4
	w.start(123)
	w.phase = "playing"
	w.offers.clear()
	w.time_ms = 163000
	w.spawn.tick()
	var bosses: Array = w.units.values().filter(func(unit): return unit.kind == "boss")
	test.assert_equal(bosses.size(), 1, "a count-one boss row is capped even when its batch size is two")
	if not bosses.is_empty():
		test.assert_equal(bosses[0].template, 114, "boss row uses its configured monster ID")
		test.assert_equal(bosses[0].wave, 14, "boss row uses its configured wave")
		test.assert_equal(bosses[0].health_bars, 1, "health bar coefficient is carried as bar count")
	test.assert_true(w.level.waves[13].entries.any(func(entry): return entry.trigger_time_ms == 163000 and entry.kind == "boss"), "trigger time is compiled from seconds")
	w.dispose()

func _statuses_and_revival(test, world, hero: Dictionary) -> void:
	world.spawn_wave = 1
	var enemy = world.factory.create("enemy", 101, hero.pos + Vector2(0, -200), 2)
	world.statuses.add(enemy, hero, 2, 1000)
	test.assert_true(world.statuses.prevents(enemy, "move"), "frozen prevents movement")
	test.assert_true(world.statuses.prevents(enemy, "attack"), "frozen prevents attacks")
	world.time_ms = 1010
	world.statuses.tick()
	test.assert_true(not world.statuses.has_status(enemy, 2), "status expires on logical time")
	world.statuses.add(hero, hero, 14, 5000)
	test.assert_true(hero.shield > 0, "shield provides actual absorption")
	var hp_before = U.hp(hero)
	world.damage.hit(enemy, hero, 10, true, false)
	test.assert_equal(U.hp(hero), hp_before, "shield absorbs incoming damage")
	world.time_ms += 5001
	world.statuses.tick()
	test.assert_equal(hero.shield, 0.0, "expired shield cannot retain absorption")
	world.damage.defeat(hero, enemy)
	test.assert_true(hero.dead, "defeated hero becomes tombstone")
	world.time_ms = hero.revive_at
	world.factory.lifecycle()
	test.assert_true(not hero.dead and U.hp(hero) > 0, "hero revives from authoritative countdown")
	world.wall_hp = 0
	world.step()
	test.assert_equal(world.phase, "result", "wall destruction ends battle")
	test.assert_true(not world.won, "wall destruction is a loss")

func _hero_attacks(test, catalog) -> void:
	for id in catalog.available_heroes():
		var world = Session.new(catalog)
		world.start(17)
		world.factory.add_hero(id)
		if not world.pending.is_empty():
			world.choices.offer("bonus")
			world.submit("choose", {"index": 0})
		world.phase = "playing"
		world.spawn_wave = 20
		var hero: Dictionary = world.units[world.heroes[0]]
		var enemy = world.factory.create("enemy", 101, hero.pos + Vector2(0, -150), 2)
		enemy.core.attributes.set_value("1", 100000)
		enemy.core.attributes.set_value("hp", 100000)
		enemy.core.attributes.set_value("4", 0)
		world.stage = 19
		for tick in range(1900):
			world.step()
			world.drain_events()
		test.assert_true(hero.stats.damage > 0, "hero %d has functional attacks" % id)
		test.assert_true(hero.skills.size() > 0, "hero %d has learned abilities" % id)
		world.dispose()

func _full_run(catalog, seed: int) -> Dictionary:
	var world = Session.new(catalog)
	world.start(seed)
	for i in range(60000):
		if world.phase == "choice":
			var preferred = [1, 10, 9, 5, 3, 11, 17, 2, 4, 14, 8, 6, 7, 15, 16, 12, 13]
			if world.choice_kind == "hero" and world.refresh_left > 0:
				var wanted = false
				for item in world.offers:
					wanted = wanted or item.id in [1, 10, 9, 5]
				if not wanted:
					world.submit("refresh")
			var pick = 0
			var best = -100000
			for index in range(world.offers.size()):
				var item: Dictionary = world.offers[index]
				var hero_id = int(item.id) if item.kind == "hero" else int(world.units[item.owner].template)
				var score = 1000 - preferred.find(hero_id) * 40 if hero_id > 0 else 0
				if item.kind == "hero":
					score += 2000
				else:
					var option = catalog.record("options", int(item.id))
					score += int(str(option.icon).split(":")[1])
				if score > best:
					best = score
					pick = index
			world.submit("choose", {"index": pick})
		if world.phase == "result":
			break
		# Exercise the real dropped-chest path as part of the current build.
		if world.phase == "reward":
			world.submit("reward_close", {"id": world.loot.current.id})
		world.step()
		world.drain_events()
	var result = {"phase": world.phase, "won": world.won, "wave": world.spawn_wave, "encounters": world.encounters_cleared.duplicate(),
		"time": world.time_ms, "wall": world.wall_hp, "kills": world.kills, "history": world.history.duplicate(true)}
	result["heroes"] = []
	for id in world.heroes:
		var hero: Dictionary = world.units[id]
		result.heroes.append({"template": hero.template, "upgrades": hero.upgrades.duplicate(), "stats": hero.stats.duplicate(),
			"initial_options": catalog.record("heroes", hero.template).initial_options.duplicate()})
	world.dispose()
	return result

func _trigger_rules(test, catalog) -> void:
	var world = Session.new(catalog)
	world.start(17)
	world.factory.add_hero(1)
	var hero: Dictionary = world.units[world.heroes[0]]
	var enemy = world.factory.create("enemy", 101, hero.pos + Vector2(0, -100), 2)
	enemy["hidden_until"] = 1000
	test.assert_true(world.targets.nearest(hero, 500).is_empty(), "hidden enemy cannot be acquired")
	world.time_ms = 1001
	test.assert_equal(world.targets.nearest(hero, 500).id, enemy.id, "expired concealment restores targeting")
	hero.skills.clear()
	hero.skills[999] = {"data": {"__id__": 999, "type": [6], "triggerOpp": ["7:10"], "cd": 0}, "next": 0, "count": 0}
	var threshold = U.stat(hero, 1) * 0.1
	test.assert_true(not world.skills.trigger(hero, "hurt", enemy, threshold * 0.6), "small hit does not trigger HP-loss skill")
	test.assert_true(world.skills.trigger(hero, "hurt", enemy, threshold * 0.6), "cumulative HP loss triggers skill")
	test.assert_true(not world.skills.trigger(hero, "hurt", enemy, 0), "HP-loss remainder does not trigger again")
	hero.skills.clear()
	hero.skills[999] = {"data": {"__id__": 999, "type": [6], "triggerOpp": ["8:20"], "cd": 0}, "next": 0, "count": 0}
	test.assert_true(not world.skills.trigger(hero, "hurt", enemy, 1), "high health blocks threshold skill")
	hero.core.attributes.set_value("hp", U.stat(hero, 1) * 0.1)
	test.assert_true(world.skills.trigger(hero, "hurt", enemy, 1), "low health triggers emergency skill")
	test.assert_true(not world.skills.trigger(hero, "hurt", enemy, 1), "non-cooldown emergency fires once")
	world.dispose()
