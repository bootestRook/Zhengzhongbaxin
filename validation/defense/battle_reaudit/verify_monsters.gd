extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	if not catalog.load_default().is_empty():
		quit(1)
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://validation/defense/battle_reaudit/monster_expected.json"))
	var rows: Array = []
	var failures: Array = []
	var worlds: Dictionary = {}
	for sample in expected.samples:
		var key = str(sample.level) + ":" + str(sample.wave)
		if not worlds.has(key):
			var world = Session.new(catalog)
			world.level_id = int(sample.level)
			world.start(83)
			world.spawn_wave = int(sample.wave)
			worlds[key] = world
		var w = worlds[key]
		var unit: Dictionary = w.factory.create(sample.kind, int(sample.monster), Vector2(800, 600), 2)
		var actual: Dictionary = {}
		for attr in sample.expected:
			actual[attr] = U.stat(unit, int(attr))
			if absf(actual[attr] - float(sample.expected[attr])) > maxf(0.0001, absf(float(sample.expected[attr])) * 0.000001):
				failures.append({"sample": sample, "attribute": attr, "actual": actual[attr]})
		rows.append({"monster": sample.monster, "level": sample.level, "wave": sample.wave, "kind": sample.kind, "actual": actual})
		w.units.erase(unit.id)
		w.core.remove_entity(str(unit.id))
		w.space.by_side[2].erase(unit)
	for w in worlds.values():
		w.dispose()
	var file = FileAccess.open("res://validation/defense/battle_reaudit/monster_runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": rows, "failures": failures}, "\t") + "\n")
	print("[OK] monster runtime values: %d spawn conditions, %d attributes, %d mismatches" % [rows.size(), rows.size() * 6, failures.size()])
	quit(0 if failures.is_empty() else 1)
