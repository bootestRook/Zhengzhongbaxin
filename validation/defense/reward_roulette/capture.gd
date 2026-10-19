extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.session.start(53)
	for id in [4, 13, 2]:
		app.session.factory.add_hero(id)
	app.session.phase = "playing"
	app.session.offers.clear()
	app.session.pending.clear()
	app.session.rules.chest_reward_weights = [0, 0, 0, 1]
	app.session.loot.enqueue()
	app.session.loot.advance()
	var view = app.get_node("DefenseView")
	view.render(app.battle_snapshot())
	var panel = view.get_node("RewardPanel")
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/reward_roulette/count.png")
	await create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/reward_roulette/spinning.png")
	var before: Dictionary = app.session.rng.snapshot()
	var history: Array = app.session.history.duplicate(true)
	await Mouse.new().click(self, panel, Vector2(480, 1720))
	assert(panel.finished and app.session.phase == "reward")
	assert(app.session.rng.snapshot() == before and app.session.history == history)
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/reward_roulette/results_%d.png" % width)
	await Mouse.new().click(self, panel, Vector2(480, 1720))
	assert(app.session.phase == "playing" and not panel.visible)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	for count in [1, 2, 3]:
		app.session.start(53)
		for id in [4, 13, 2]:
			app.session.factory.add_hero(id)
		app.session.phase = "playing"
		app.session.offers.clear()
		app.session.pending.clear()
		app.session.rules.chest_reward_weights = [0, 0, 0, 0]
		app.session.rules.chest_reward_weights[count - 1] = 1
		app.session.loot.enqueue()
		app.session.loot.advance()
		view.render(app.battle_snapshot())
		await create_timer(0.15).timeout
		await Mouse.new().click(self, panel, Vector2(480, 1720))
		assert(panel.finished and panel.packet.items.size() == count)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/reward_roulette/count_%d_result.png" % count)
		await Mouse.new().click(self, panel, Vector2(480, 1720))
	print("[ROULETTE] real skip then close; unchanged results/RNG; all 1-4 counts and 8 screenshots")
	app.queue_free()
	await process_frame
	quit()
