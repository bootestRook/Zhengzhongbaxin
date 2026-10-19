extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var w = app.session
	w.level_id = 1
	w.start(81)
	w.spawn_wave = 3
	w.stage = 2
	w.phase = "playing"
	w.factory.add_hero(2)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.pos = Vector2(800, 1080)
	hero.entering = false
	w.factory.create("summon", 23, Vector2(680, 900), 1, hero.id)
	w.factory.create("enemy", 103, Vector2(560, 680), 2)
	w.factory.create("elite", 112, Vector2(800, 680), 2)
	w.factory.create("boss", int(w.level.bosses[0][0]), Vector2(1040, 680), 2)
	w.visuals.clear()
	app.get_node("DefenseView").render(app.battle_snapshot())
	for dimensions in [Vector2i(720, 1440), Vector2i(540, 1080)]:
		DisplayServer.window_set_size(dimensions)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/monster_rings_hidden/battle_%d.png" % dimensions.x)
	print("[OK] normal/elite/boss circles hidden; friendly markers and outlines retained")
	app.queue_free()
	await process_frame
	quit()
