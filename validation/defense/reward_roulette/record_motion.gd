extends SceneTree

func _initialize() -> void:
	call_deferred("record_motion")

func record_motion() -> void:
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
	app.get_node("DefenseView").render(app.battle_snapshot())
	var before: Dictionary = app.session.rng.snapshot()
	var history: Array = app.session.history.duplicate(true)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	for frame in range(50):
		await create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/reward_roulette/motion_frames/%02d.png" % frame)
	assert(app.get_node("DefenseView/RewardPanel").finished)
	assert(app.session.rng.snapshot() == before and app.session.history == history)
	print("[MOTION] 50 native frames; full count/spin/reveal playback; rewards and RNG unchanged")
	app.queue_free()
	await process_frame
	quit()
