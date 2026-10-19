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
	var w = app.session
	w.level_id = 5
	w.start(1)
	for hid in [5, 4, 17, 1, 2]:
		w.factory.add_hero(hid)
	w.phase = "playing"
	for tick in range(7400):
		if w.phase == "choice":
			w.choices.choose(0)
		w.step()
		w.drain_events()
		if tick < 7150 or tick % 2 != 0:
			continue
		app.get_node("DefenseView").render(app.battle_snapshot())
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/commander_jitter/frames_after/frame_%05d.png" % tick)
	print("[OK] rendered level 5 five-hero combat through ", w.time_ms)
	app.queue_free()
	await process_frame
	quit()
