extends SceneTree

var app

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	DisplayServer.window_set_size(Vector2i(480, 960))
	for hid in [1, 2, 4, 13, 17]:
		var w = app.session
		w.level_id = 5
		w.start(81)
		w.spawn_wave = 20
		w.stage = 19
		w.phase = "playing"
		w.factory.add_hero(hid)
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.pos = hero.home
		hero.entering = false
		var enemy = w.factory.create("enemy", 106, Vector2(600, 800), 2)
		for unit in [hero, enemy]:
			unit.core.attributes.set_value("1", 1000000)
			unit.core.attributes.set_value("hp", 1000000)
		for tick in range(240):
			w.step()
			if tick not in [140, 160, 180, 220]:
				continue
			app.get_node("DefenseView").render(app.battle_snapshot())
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/defense/five_hero_ai_audit/hero_%d_%d.png" % [hid, tick])
	print("[OK] five-hero native action captures")
	app.queue_free()
	await process_frame
	quit()
