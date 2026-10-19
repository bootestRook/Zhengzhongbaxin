extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.submit("start", {"seed": 3})
	var view = app.get_node("DefenseView")
	var report = {"unlocked": app._catalog.available_heroes(), "opening": [], "refreshed": []}
	for label in ["opening", "refreshed"]:
		await create_timer(0.8).timeout
		for item in app.battle_snapshot().offers:
			assert(report.unlocked.has(item.id))
			report[label].append(item.title)
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://validation/defense/initial_roster/%s_720.png" % label) == OK)
		if label == "opening":
			await preload("res://tests/test_defense_choice_ui.gd").new().click(self, view.get_node("ChoicePanel/Refresh"))
	FileAccess.open("res://validation/defense/initial_roster/report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("[ROSTER UI] " + JSON.stringify(report))
	app.queue_free()
	await process_frame
	quit()
