extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	root.size = Vector2i(540, 1080)
	var w = app.session
	w.start(6)
	for hid in [4, 17, 1, 2, 13]:
		w.factory.add_hero(hid)
	w.offers.clear()
	w.phase = "playing"
	for tick in range(7500):
		for pick in range(25):
			if w.phase == "choice":
				w.submit("choose", {"index": 0})
			elif w.phase == "reward":
				w.submit("reward_close", {"id": w.loot.current.id})
			else:
				break
		w.step()
		w.drain_events()
		if tick not in [3749, 7499]:
			continue
		for pick in range(25):
			if w.phase == "choice":
				w.submit("choose", {"index": 0})
			elif w.phase == "reward":
				w.submit("reward_close", {"id": w.loot.current.id})
			else:
				break
		app.get_node("DefenseView").render(app.battle_snapshot())
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		var path = "res://validation/defense/guard_line/battle_%ds.png" % (w.time_ms / 1000)
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("[GUARD CAPTURE] ", w.time_ms, "ms ", w.snapshot().heroes.map(func(h): return {"hero": h.template, "pos": str(h.pos)}))
	app.queue_free()
	await process_frame
	quit()
