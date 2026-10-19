extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

class UnscaledCatalog extends Catalog:
	func record(table: String, key: int) -> Dictionary:
		var result = super.record(table, key)
		if table == "levels" and not result.is_empty():
			result.enemy_hp_multiplier = 1
		return result

func run(test) -> void:
	var catalog = Catalog.new()
	var original = UnscaledCatalog.new()
	test.assert_equal(catalog.load_default(), "", "balanced catalog loads")
	test.assert_equal(original.load_default(), "", "unscaled control catalog loads")
	for level in [1, 2, 3, 5]:
		var adjusted = _session(test, catalog, level)
		var control = _session(test, original, level)
		var factor: float = catalog.record("levels", level).enemy_hp_multiplier
		test.assert_true(factor > 0 and (factor < 1 if level == 2 else factor == 1), "only level two reduces enemy health")
		for wave in [1, 8, 14, 20]:
			adjusted.spawn_wave = wave
			control.spawn_wave = wave
			for kind in ["enemy", "elite", "boss"]:
				var entry: Dictionary = adjusted.level.waves[wave - 1].entries[0].duplicate(true)
				entry.wave = wave
				var template: int = int(entry.monster_id)
				var enemy = adjusted.factory.create(kind, template, Vector2(800, 200), 2, 0, entry)
				var before = control.factory.create(kind, template, Vector2(800, 200), 2, 0, entry)
				test.assert_true(is_equal_approx(U.stat(enemy, 1), U.stat(before, 1) * factor), "%s level %d wave %d receives the health multiplier" % [kind, level, wave])
				test.assert_equal(U.hp(enemy), U.stat(enemy, 1), "new enemies start at their adjusted maximum health")
				for attribute in [4, 6, 10, 17]:
					test.assert_equal(U.stat(enemy, attribute), U.stat(before, attribute), "balance preserves enemy attack, attack speed, defense and movement")
		adjusted.factory.add_hero(2)
		control.factory.add_hero(2)
		var hero: Dictionary = adjusted.units[adjusted.heroes[0]]
		var original_hero: Dictionary = control.units[control.heroes[0]]
		var summon = adjusted.factory.create("summon", 1, Vector2(800, 800), 1, hero.id)
		var original_summon = control.factory.create("summon", 1, Vector2(800, 800), 1, original_hero.id)
		for attribute in [1, 4, 6, 10, 17]:
			test.assert_equal(U.stat(hero, attribute), U.stat(original_hero, attribute), "level balance preserves hero attributes")
			test.assert_equal(U.stat(summon, attribute), U.stat(original_summon, attribute), "level balance preserves owned summon attributes")
		test.assert_equal(adjusted.wall_hp, control.wall_hp, "level balance preserves wall health")
		adjusted.dispose()
		control.dispose()

func _session(test, catalog, level: int):
	var world = Session.new(catalog)
	test.assert_equal(world.submit("select_level", {"level": level}), "", "balance test selects a valid level")
	test.assert_equal(world.submit("start", {"seed": 53}), "", "balance test starts a legal seeded session")
	return world
