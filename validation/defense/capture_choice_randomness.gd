extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_choice_rules.gd").new().run(test)
	await preload("res://tests/test_defense_run_seed_ui.gd").new().run(test, self)
	if not test.failures.is_empty():
		for message in test.failures:
			push_error(message)
		quit(1)
		return
	print("[CHOICE RULES] %d focused assertions passed" % test.assertions)
	for i in range(3):
		var app = load("res://scenes/main.tscn").instantiate()
		root.add_child(app)
		await process_frame
		app.set_process(false)
		await Mouse.new().click(self, app.get_node("DefenseView/Home/BattlePage/Start"))
		await create_timer(0.75).timeout
		var ids: Array = []
		for item in app.session.offers:
			ids.append(item.id)
		print("[FRESH APP] run=%d seed=%d candidates=%s" % [i + 1, app.session.seed, ids])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/choice_fresh_start_%d.png" % (i + 1))
		if i == 0:
			await Mouse.new().click(self, app.get_node("DefenseView/ChoicePanel/Refresh"))
			await create_timer(0.75).timeout
			ids.clear()
			for item in app.session.offers:
				ids.append(item.id)
			print("[REFRESH] seed=%d candidates=%s" % [app.session.seed, ids])
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/defense/choice_fresh_refresh.png")
		app.queue_free()
		await process_frame
		await process_frame
	quit()
