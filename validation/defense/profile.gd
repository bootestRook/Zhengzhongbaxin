extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var rows: Array = []
	for count in [30, 100, 300]:
		var w = Session.new(catalog)
		w.start(71)
		for id in [1, 5, 9, 10]:
			w.factory.add_hero(id)
		w.phase = "playing"
		w.stage = 19
		w.spawn_wave = 20
		w.wall_hp = 1000000
		for i in range(count):
			w.factory.create("enemy", 101, Vector2(350 + i % 20 * 45, 350 + i / 20 * 45), 2)
		var start = Time.get_ticks_usec()
		for i in range(1000):
			w.step()
			w.snapshot()
			w.drain_events()
		var elapsed = Time.get_ticks_usec() - start
		rows.append({"initial_enemies": count, "step_and_snapshot_ms": elapsed / 1000000.0, "final_units": w.units.size(), "phase": w.phase})
		w.dispose()
	var file = FileAccess.open("res://validation/defense/performance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t") + "\n")
	print(JSON.stringify(rows))
	quit()
