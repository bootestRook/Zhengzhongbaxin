extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var rows: Array = []
	for capacity in [2, 15]:
		var w = Session.new(catalog)
		w.start(81)
		w.spawn_wave = 1
		w.phase = "playing"
		w.factory.add_hero(4)
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.pos = Vector2(800, 800)
		hero.home = hero.pos
		hero.entering = false
		hero.skills.clear()
		hero.core.attributes.set_value("3", capacity)
		hero.core.attributes.set_value("17", 0)
		hero.core.attributes.set_value("1", 1000000)
		hero.core.attributes.set_value("hp", 1000000)
		for i in range(32):
			var enemy = w.factory.create("enemy", 103, Vector2(620 + (i % 8) * 50, 560 + (i / 8) * 40), 2)
			enemy.skills.clear()
			enemy.core.attributes.set_value("1", 1000000)
			enemy.core.attributes.set_value("hp", 1000000)
		var peak_bound := 0
		var peak_target := 0
		var overflow_ticks := 0
		var samples: Array = []
		for tick in range(2500):
			w.time_ms += 16
			w.space.rebuild()
			w.navigation.rebuild()
			w.ai.tick()
			var bound := 0
			var targeted := 0
			var unbound_targeted := 0
			for unit: Dictionary in w.units.values():
				if unit.side == 2:
					bound += int(unit.blocked_by == hero.id)
					targeted += int(unit.target == hero.id)
					unbound_targeted += int(unit.target == hero.id and unit.blocked_by != hero.id)
			peak_bound = maxi(peak_bound, bound)
			peak_target = maxi(peak_target, targeted)
			overflow_ticks += int(targeted > capacity)
			if tick % 125 == 0:
				samples.append({"time":w.time_ms,"bound":bound,"targeted":targeted,"unbound_targeted":unbound_targeted})
		rows.append({"capacity":capacity,"peak_bound":peak_bound,"peak_targeted":peak_target,"overflow_ticks":overflow_ticks,"samples":samples})
		w.dispose()
	var label = "after" if OS.get_cmdline_user_args().has("after") else "before"
	var file = FileAccess.open("res://validation/defense/blocking_limit/%s.json" % label, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	for row in rows:
		print("[BLOCK PROBE] capacity=%d peak_bound=%d peak_targeted=%d overflow_ticks=%d" % [row.capacity,row.peak_bound,row.peak_targeted,row.overflow_ticks])
	quit()
