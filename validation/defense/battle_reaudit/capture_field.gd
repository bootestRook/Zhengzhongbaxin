extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var w = app.session
	w.start(89)
	w.factory.add_hero(4)
	w.factory.add_hero(10)
	w.phase = "playing"
	w.spawn_wave = 1
	w.stage = 19
	for hero_id in w.heroes:
		w.units[hero_id]["busy_until"] = 100000
	for item in [["enemy", 101, Vector2(560, 800)], ["elite", 102, Vector2(1030, 820)], ["boss", 105, Vector2(800, 690)]]:
		var unit: Dictionary = w.factory.create(item[0], item[1], item[2], 2)
		unit.core.attributes.set_value("hp", unit.core.attributes.value("1") * 0.5)
		unit["busy_until"] = 100000
	w.time_ms = 500
	app.get_node("DefenseView").render(w.snapshot())
	await process_frame
	await RenderingServer.frame_post_draw
	var bitmap = root.get_texture().get_image()
	var path = "res://validation/defense/battle_reaudit/field_%d.png" % bitmap.get_width()
	bitmap.save_png(path)
	print("[CAPTURE] %s; damaged ordinary/elite/Boss fixture using authoritative current HP" % path)
	app.queue_free()
	await process_frame
	quit()
