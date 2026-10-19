extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Field = preload("res://src/features/defense/presentation/defense_field.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_baselines(test, catalog)
	_mage_branches(test, catalog)
	_summon(test, catalog)
	_death(test, catalog)
	_no_replay(test, catalog)

func world(catalog):
	var w = Session.new(catalog)
	w.start(73)
	w.phase = "playing"
	w.spawn_wave = 20
	w.stage = 19
	return w

func _baselines(test, catalog) -> void:
	for hero_id in catalog.available_heroes():
		var w = world(catalog)
		w.factory.add_hero(hero_id)
		var hero: Dictionary = w.units[w.heroes[0]]
		var definition: Dictionary = catalog.record("heroes", hero_id)
		var expected: Array = definition.skills.duplicate()
		for option_id in definition.initial_options:
			for sid in catalog.record("options", option_id).unlock:
				expected.append(int(sid))
		var actual: Array = hero.skills.keys()
		expected.sort()
		actual.sort()
		test.assert_equal(actual, expected, "hero %d learns only base and initial unlocked skills" % hero_id)
		test.assert_equal(hero.upgrades, definition.initial_options, "hero %d receives no extra options at birth" % hero_id)
		var enemy = w.factory.create("enemy", 101, hero.pos + Vector2(0, -350 if not hero.front else -150), 2)
		enemy.core.attributes.set_value("hp", 1000000)
		enemy["busy_until"] = 1000000
		var emitted: Dictionary = {}
		var resources: Dictionary = {}
		var extra_hit = false
		for tick in range(1500):
			w.step()
			for p in w.missiles:
				if p.owner == hero.id and p.kind != 0:
					emitted[int(p.skill.__id__)] = true
					if not p.res.is_empty():
						resources[p.res] = true
			for cue in w.visuals:
				extra_hit = extra_hit or cue.kind == "hit"
		for sid in emitted:
			test.assert_true(expected.has(sid), "baseline projectile belongs to a learned initial skill")
		test.assert_true(not extra_hit, "basic attacks cannot add an unrelated hit movie")
		if hero_id == 3:
			test.assert_equal(resources.keys(), ["hero3:normal_0"], "unupgraded mage emits only arcane missiles")
		print("[BASELINE] hero=%d learned=%s emitted=%s effects=%s" % [hero_id, expected, emitted.keys(), resources.keys()])
		actual = hero.skills.keys()
		actual.sort()
		test.assert_equal(actual, expected, "24 seconds of combat cannot unlock upgrade branches")
		w.dispose()

func _mage_branches(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(3)
	var hero: Dictionary = w.units[w.heroes[0]]
	for pair in [[171, [6, 7]], [175, [4, 5]], [179, [9, 10]]]:
		for sid in pair[1]:
			test.assert_true(not hero.skills.has(sid), "elemental branch is locked before its option")
		w.upgrades.apply(hero, pair[0])
		for sid in pair[1]:
			test.assert_true(hero.skills.has(sid), "elemental branch unlocks only through its option")
		for sid in [8, 11, 12, 13, 14, 15]:
			test.assert_true(not hero.skills.has(sid), "later elemental and talent branches remain locked")
	w.dispose()

func _summon(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(9)
	var hero: Dictionary = w.units[w.heroes[0]]
	test.assert_equal(w.visuals.size(), 2, "hero arrival has the two source summon movies")
	for i in range(2):
		var cue: Dictionary = w.visuals[i]
		test.assert_equal(cue.res, "battleEffect:summon%d" % (i + 2), "arrival uses the hero summon assets")
		test.assert_equal(cue.pos, hero.pos, "both movies share the birth foot anchor")
		test.assert_equal(cue.pivot, Vector2(0.5, 0.8), "summon uses the source pivot")
		test.assert_equal(cue.expires - cue.start, 500, "summon ends after all five source frames")
		test.assert_true(not cue.loop, "summon movie plays once")
	test.assert_true(w.visuals[0].layer < 0 and w.visuals[1].layer > 0, "summon surrounds the actor with back and front layers")
	w.time_ms = 496
	w.step()
	test.assert_equal(w.visuals.size(), 0, "arrival movies leave no residual floor circle")
	w.dispose()

func _death(test, catalog) -> void:
	var w = world(catalog)
	var enemy = w.factory.create("enemy", 101, Vector2(800, 900), 2)
	enemy.action = "walk"
	enemy.action_at = 16
	w.time_ms = 100
	w.damage.defeat(enemy, {})
	var actor: Dictionary = w.snapshot().actors[0]
	test.assert_equal(actor.action, "walk", "missing die clip uses the frozen last pose rather than idle")
	test.assert_equal(actor.frame_elapsed, 84, "death freezes the exact prior animation time")
	test.assert_equal(Field.death_scale(90), 1.0, "death deformation takes over after 90 ms")
	test.assert_equal(Field.death_scale(350), 0.0, "ordinary monster body disappears after 350 ms")
	test.assert_equal(Field.death_scale(8000), 0.0, "logical corpse retention cannot leave a visible body")
	w.time_ms += 400
	w.factory.lifecycle()
	test.assert_true(w.units.has(enemy.id) and not enemy.death_finished, "hiding a body preserves corpse and death-after timing")
	test.assert_equal(w.snapshot().actors[0].frame_elapsed, 84, "logical corpse cannot animate its old idle pose")
	w.dispose()

func _no_replay(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(9)
	var hero: Dictionary = w.units[w.heroes[0]]
	w.visuals.clear()
	var skill: Dictionary = hero.skills[413].data
	w.projectiles.launch(hero, hero, skill, Vector2.INF, 0)
	w.projectiles.tick()
	test.assert_equal(w.missiles.size(), 1, "ground slam owns one visual during its lifetime")
	w.time_ms = 600
	w.projectiles.tick()
	test.assert_equal(w.missiles.size(), 0, "ground slam visual ends with its projectile")
	test.assert_equal(w.visuals.size(), 0, "ended skill cannot restart the same movie as an extra effect")
	w.dispose()
