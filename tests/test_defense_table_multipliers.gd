extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "spreadsheet catalog loads")
	var before = Session.new(catalog)
	var after = Session.new(catalog)
	before.start(53)
	after.start(53)
	before.spawn_wave = 1
	after.spawn_wave = 1
	after.level.enemy_hp_multiplier *= 2
	after.level.enemy_atk_multiplier *= 3
	var entry: Dictionary = after.level.waves[0].entries[0].duplicate(true)
	var original_hp_factor := float(entry.hp_multiplier)
	var original_atk_factor := float(entry.atk_multiplier)
	entry.hp_multiplier *= 1.5
	entry.atk_multiplier *= 2.5
	var baseline_entry: Dictionary = entry.duplicate(true)
	baseline_entry.hp_multiplier = original_hp_factor
	baseline_entry.atk_multiplier = original_atk_factor
	var normal = before.factory.create("enemy", int(entry.monster_id), Vector2(800, 200), 2, 0, baseline_entry)
	var scaled = after.factory.create("enemy", int(entry.monster_id), Vector2(800, 200), 2, 0, entry)
	test.assert_true(is_equal_approx(U.stat(scaled, 1), U.stat(normal, 1) * 3), "level and row HP factors multiply independently")
	test.assert_true(is_equal_approx(U.stat(scaled, 4), U.stat(normal, 4) * 7.5), "level and row attack factors multiply independently")
	var encounter_source: Dictionary = catalog.record("levels", 4).encounters[0]
	var encounter_entry: Dictionary = encounter_source.duplicate(true)
	encounter_entry.hp_multiplier *= 4
	encounter_entry.atk_multiplier *= 5
	var elite = before.factory.create_encounter(encounter_source, Vector2(800, 200))
	var scaled_elite = after.factory.create_encounter(encounter_entry, Vector2(800, 200))
	test.assert_true(is_equal_approx(U.stat(scaled_elite, 1), U.stat(elite, 1) * 8), "special rows use their own HP factor")
	test.assert_true(is_equal_approx(U.stat(scaled_elite, 4), U.stat(elite, 4) * 15), "special rows use their own attack factor")
	before.factory.add_hero(2)
	after.factory.add_hero(2)
	var hero: Dictionary = before.units[before.heroes[0]]
	var other: Dictionary = after.units[after.heroes[0]]
	var summon = before.factory.create("summon", 1, Vector2(800, 800), 1, hero.id)
	var other_summon = after.factory.create("summon", 1, Vector2(800, 800), 1, other.id)
	for attribute in [1, 4]:
		test.assert_equal(U.stat(other, attribute), U.stat(hero, attribute), "enemy multipliers do not affect heroes")
		test.assert_equal(U.stat(other_summon, attribute), U.stat(summon, attribute), "enemy multipliers do not affect summons")
	before.dispose()
	after.dispose()
