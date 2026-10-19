extends "res://validation/defense/monster_movement/measure.gd"

var app

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var label = OS.get_cmdline_user_args()[0]
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.session.submit("start", {"seed": 6})
	var moments = [8000, 20000, 45000, 90000, 160000]
	var next = 0
	print("[READY] legal level-1 seed-6 replay")
	for frame in range(60000):
		advance_choice(app.session)
		if app.session.phase == "result":
			break
		app.session.step()
		app.session.drain_events()
		if next < moments.size() and app.session.time_ms >= moments[next] and app.session.phase == "playing":
			app.get_node("DefenseView").render(app.battle_snapshot())
			await shot("%s_720_%d" % [label, moments[next]])
			next += 1
	app.get_node("DefenseView").render(app.battle_snapshot())
	await shot(label + "_720_end")
	DisplayServer.window_set_size(Vector2i(540, 1080))
	await process_frame
	await process_frame
	await shot(label + "_540_end")
	print("[RESULT] ", JSON.stringify({"finished": app.session.phase == "result", "won": app.session.won,
		"time_ms": app.session.time_ms, "wave": app.session.spawn_wave, "wall": app.session.wall_hp}))
	app.queue_free()
	await process_frame
	quit()

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT + name + ".png") == OK)
