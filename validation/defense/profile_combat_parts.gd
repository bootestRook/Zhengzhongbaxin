extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var w = Session.new(catalog)
	w.start(71)
	for id in [1, 5, 9, 10]:
		w.factory.add_hero(id)
	w.phase = "playing"
	w.stage = 19
	w.spawn_wave = 20
	for i in range(300):
		w.factory.create("enemy", 101, Vector2(350 + i % 20 * 45, 350 + i / 20 * 45), 2)
	var totals = {"lifecycle": 0, "status": 0, "space": 0, "ai": 0, "skills": 0, "missiles": 0, "snapshot": 0}
	for i in range(1000):
		w.time_ms += 16
		w.visuals = w.visuals.filter(func(v): return w.time_ms < v.expires)
		var start = Time.get_ticks_usec()
		w.factory.lifecycle()
		totals.lifecycle += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		w.statuses.tick()
		totals.status += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		w.space.rebuild()
		totals.space += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		w.ai.tick()
		totals.ai += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		w.skills.tick()
		totals.skills += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		w.projectiles.tick()
		totals.missiles += Time.get_ticks_usec() - start
		start = Time.get_ticks_usec()
		w.snapshot()
		totals.snapshot += Time.get_ticks_usec() - start
		w.drain_events()
	for key in totals:
		totals[key] /= 1000000.0
	print(JSON.stringify(totals))
	w.dispose()
	quit()
