extends SceneTree

const U = preload("res://src/features/defense/domain/defense_units.gd")
var app

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.get_node("DefenseView/Field").damage_numbers = false
	DisplayServer.window_set_size(Vector2i(720, 1440))
	for label in ["before", "after"]:
		var w = app.session
		w.start(81)
		w.spawn_wave = 1
		w.phase = "playing"
		w.space = preload("res://validation/defense/blocking_limit/before_space.gd").new(w) if label == "before" else DefenseSpace.new(w)
		for hid in [4, 2, 17, 5, 13]:
			w.factory.add_hero(hid)
		for i in range(w.heroes.size()):
			var hero: Dictionary = w.units[w.heroes[i]]
			hero.pos = [Vector2(800, 750), Vector2(1100, 1250), Vector2(550, 1050), Vector2(950, 1050), Vector2(500, 1250)][i]
			hero.home = hero.pos
			hero.entering = false
			hero.skills.clear()
			hero.core.attributes.set_value("17", 0)
			hero.core.attributes.set_value("1", 1000000)
			hero.core.attributes.set_value("hp", 1000000)
		for i in range(40):
			var enemy = w.factory.create("enemy", [103,106,112][i % 3], Vector2(550 + (i % 10) * 50, 560 - (i / 10) * 35), 2)
			enemy.skills.clear()
			enemy.core.attributes.set_value("1", 1000000)
			enemy.core.attributes.set_value("hp", 1000000)
		for tick in range(1800):
			w.time_ms += 16
			w.visuals = w.visuals.filter(func(v): return w.time_ms < v.expires)
			w.space.rebuild()
			w.navigation.rebuild()
			w.ai.tick()
			if tick in [600,1200,1799]:
				app.get_node("DefenseView").render(app.battle_snapshot())
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://validation/defense/blocking_limit/%s_%d.png" % [label,tick])
		var counts: Dictionary = {}
		for id in w.heroes:
			var hero: Dictionary = w.units[id]
			var targets := 0
			var bound := 0
			for unit: Dictionary in w.units.values():
				if unit.side == 2:
					targets += int(unit.target == id)
					bound += int(unit.blocked_by == id)
			counts[hero.template] = {"capacity":U.stat(hero,3),"bound":bound,"targeted":targets}
		print("[NATIVE BLOCKING] ",label," ",JSON.stringify(counts))
	print("[OK] blocking native comparison captured")
	app.queue_free()
	await process_frame
	quit()
