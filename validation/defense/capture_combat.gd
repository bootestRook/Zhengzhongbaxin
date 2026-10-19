extends SceneTree

var app

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.session.start(17)
	for id in [4, 10, 1, 8]:
		app.session.factory.add_hero(id)
	app.session.phase = "playing"
	app.session.spawn_wave = 20
	app.session.stage = 19
	app.session.wall_hp = 100000
	for i in range(18):
		app.session.factory.create("enemy", [101, 107, 113][i % 3], Vector2(400 + i % 6 * 145, 650 + i / 6 * 100), 2)
	for tick in range(650):
		app.session.step()
		app.session.drain_events()
		if tick in [40, 170, 350, 649]:
			app.get_node("DefenseView").render(app.battle_snapshot())
			await shot("combat_720_%d" % tick)
	DisplayServer.window_set_size(Vector2i(540, 1080))
	await create_timer(0.2).timeout
	await shot("combat_540")
	print("[OK] combat native captures; time=%d missiles=%d" % [app.session.time_ms, app.session.missiles.size()])
	app.queue_free()
	await process_frame
	quit()

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/%s.png" % name)
