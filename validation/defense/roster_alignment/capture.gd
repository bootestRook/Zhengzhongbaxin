extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var report: Array = []
	var batches = [[4, 1, 2, 5, 13], [17, 4, 1, 2, 5]]
	for batch in range(batches.size()):
		var w = app.session
		w.start(17)
		for id in batches[batch]:
			w.factory.add_hero(id)
		w.phase = "playing"
		for state in ["alive", "dead_early", "dead_late"]:
			if state == "dead_early":
				for id in w.heroes:
					w.damage.defeat(w.units[id], {})
				w.time_ms = 1000
				w.factory.lifecycle()
			elif state == "dead_late":
				w.time_ms = 9000
				w.factory.lifecycle()
			view.render(app.battle_snapshot())
			for width in [480, 720, 960]:
				DisplayServer.window_set_size(Vector2i(width, width * 2))
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png("res://validation/defense/roster_alignment/%d_%s_%d.png" % [batch, state, width]) == OK)
				for index in range(5):
					var slot = view.get_node("HUD/Hero%d" % index)
					var center = slot.get_node("Portrait/Art").get_global_rect().get_center()
					assert(slot.get_node("Revive").get_global_rect().get_center() == center)
					report.append({"width": width, "hero": slot.hero.template, "state": state,
						"center": [center.x, center.y], "countdown": slot.get_node("Revive").text})
	FileAccess.open("res://validation/defense/roster_alignment/report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("[ALIGNMENT] %d center checks, six hero templates, single and double digit countdowns" % report.size())
	app.queue_free()
	await process_frame
	quit()
