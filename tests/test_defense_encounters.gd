extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func world(catalog, level: int = 4):
	var w = Session.new(catalog)
	w.level_id = level
	w.start(53)
	w.factory.add_hero(1)
	w.phase = "playing"
	w.offers.clear()
	w.pending.clear()
	return w

func run(test) -> void:
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "row encounter catalog loads")
	var w = world(catalog)
	for entry in w.level.encounters:
		w.spawn_wave = int(entry.wave) - 1
		w.spawn.begin_wave()
		w.spawn.wave_left = 0
		w.spawn.tick()
		var spawned: Array = w.units.values().filter(func(unit): return unit.encounter_row_id == int(entry.row_id))
		test.assert_equal(spawned.size(), 1, "each configured special row spawns its configured count")
		if spawned.is_empty():
			continue
		var unit: Dictionary = spawned[0]
		test.assert_equal(unit.kind, entry.kind, "special row preserves its type")
		test.assert_equal(unit.template, entry.id, "special row preserves its monster ID")
		test.assert_equal(U.stat(unit, 1), U.stat(w.factory.create("enemy", int(entry.id), unit.pos, 2, 0, entry), 1), "special row applies its HP coefficient")
		w.damage.defeat(unit, {})
		w.step()
		test.assert_true(w.phase == "reward", "special death opens the configured reward")
		w.loot.close(w.loot.current.id)
	test.assert_true(w.encounters_cleared.size() == w.level.encounters.size(), "configured special rows are tracked by row ID")
	w.dispose()
	w = world(catalog, 1)
	w.spawn_wave = 1
	var regular = w.factory.create("elite", 101, Vector2(800, 700), 2)
	w.damage.defeat(regular, {})
	test.assert_true(w.encounters_cleared.is_empty() and w.kills == 1, "manually created elite without a table row is an ordinary kill")
	w.dispose()
