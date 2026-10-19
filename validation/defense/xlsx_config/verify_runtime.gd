extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func _initialize() -> void:
	var test = preload("res://tests/test_support.gd").new()
	var normal = Catalog.new()
	test.assert_equal(normal.load_default(), "", "normal source loads")
	var edited = Catalog.new()
	edited._data = Catalog.normalize(JSON.parse_string(FileAccess.get_file_as_string("res://validation/defense/xlsx_config/edited_catalog.json")))
	var world = Session.new(edited)
	world.start(53)
	world.factory.add_hero(4)
	var hero: Dictionary = world.units[world.heroes.back()]
	test.assert_equal(U.stat(hero, 4), 65.0, "edited XLSX hero attack is used by a real unit")
	test.assert_equal(hero.skills[755].data.cd, 11000, "edited XLSX cooldown is used by the real skill instance")
	var base_world = Session.new(normal)
	base_world.start(53)
	world.spawn_wave = 1
	base_world.spawn_wave = 1
	var base = base_world.factory.create("enemy", 101, Vector2(800, 200), 2)
	var enemy = world.factory.create("enemy", 101, Vector2(800, 200), 2)
	test.assert_true(is_equal_approx(U.stat(enemy, 1), U.stat(base, 1) * 3), "XLSX level and spawn HP edits affect actual monster health")
	test.assert_true(is_equal_approx(U.stat(enemy, 4), U.stat(base, 4) * 7.5), "XLSX level and spawn attack edits affect actual monster attack")
	preload("res://tests/test_defense_table_multipliers.gd").new().run(test)
	preload("res://tests/test_defense_combat.gd").new().run(test)
	world.dispose()
	base_world.dispose()
	if test.failures.is_empty():
		print("[OK] XLSX edited runtime and independent multipliers: %d assertions" % test.assertions)
		quit(0)
	else:
		for failure in test.failures:
			push_error(failure)
		quit(1)
