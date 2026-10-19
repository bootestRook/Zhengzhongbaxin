extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var w = app.session
	var view = app.get_node("DefenseView")
	var panel = view.get_node("RewardPanel")
	var mouse = Mouse.new()
	for source in ["elite", "boss"]:
		for width in [960, 720, 540]:
			DisplayServer.window_set_size(Vector2i(width, width * 2))
			w.start(53)
			for id in [1, 2, 4, 13, 17]:
				w.factory.add_hero(id)
			w.phase = "playing"
			w.offers.clear()
			w.pending.clear()
			w.spawn_wave = 20
			w.rules.chest_reward_weights = [1, 0, 0, 0] if source == "elite" else [0, 0, 0, 1]
			w.bosses_dead = 0 if source == "elite" else w.level.bosses.size() - 1
			var id: int = 101 if source == "elite" else int(w.level.bosses.back()[0])
			var target = w.factory.create(source, id, Vector2(800, 690), 2)
			w.damage.defeat(target, {})
			w.step()
			assert(w.phase == "reward" and w.loot.current.source == source)
			view.render(app.battle_snapshot())
			panel.set_process(false)
			panel.elapsed = panel.COUNT_TIME + panel.SPIN_TIME / 2
			panel.update_motion()
			var time: int = w.time_ms
			var history: Array = w.history.duplicate(true)
			var rng: Dictionary = w.rng.snapshot()
			await create_timer(0.15).timeout
			await shot(source + "_spin", width)
			await mouse.click(self, panel, Vector2(480, 1720))
			assert(panel.finished and w.phase == "reward")
			assert(w.history == history and w.rng.snapshot() == rng and w.time_ms == time)
			await shot(source + "_result", width)
			await mouse.click(self, panel, Vector2(480, 1720))
			assert(w.phase == "playing" if source == "elite" else w.phase == "result" and w.won)
	print("[DROP CAPTURES] 12 native captures; actual elite/final boss deaths; paused skip then close; final reward before victory")
	app.queue_free()
	await process_frame
	quit()

func shot(label: String, width: int) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://validation/defense/elite_boss_rewards/%s_%d.png" % [label, width]) == OK)
