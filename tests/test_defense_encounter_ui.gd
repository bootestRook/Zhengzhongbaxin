extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test: TestSupport, tree: SceneTree, capture: bool = false) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var w = app.session
	w.level_id = 4
	var view = app.get_node("DefenseView")
	var panels = view.get_node("BattlePanels")
	var mouse = Mouse.new()
	w.start(53)
	w.factory.add_hero(1)
	w.phase = "playing"
	w.offers.clear()
	w.pending.clear()
	w.rules.chest_reward_weights = [1, 0, 0, 0]
	view.render(app.battle_snapshot())
	view.send("pause")
	for i in range(w.level.encounters.size()):
		var portrait = panels.get_node("Pause/Monster%d" % (i + 3))
		test.assert_equal(portrait.kind, w.level.encounters[i].kind, "pause portraits identify configured special rows")
		test.assert_equal(portrait.get_node("Boss").text, "首领" if w.level.encounters[i].kind == "boss" else "精英", "pause portrait labels use the actual category")
	if capture:
		await sizes(tree, "pause")
	await mouse.click(tree, panels.get_node("Pause/Resume"))
	for entry in w.level.encounters:
		w.spawn_wave = entry.wave
		var unit = w.factory.create_encounter(entry, Vector2(800, 700))
		w.damage.defeat(unit, {})
		w.step()
		view.render(app.battle_snapshot())
		var reward = view.get_node("RewardPanel")
		test.assert_equal(reward.get_node("Source").text, "首领掉落" if entry.kind == "boss" else "精英掉落", "configured encounter rows use their category reward label")
		await mouse.click(tree, reward, Vector2(480, 1720))
		test.assert_true(reward.finished and w.phase == "reward", "first click reveals the scheduled reward")
		if capture:
			await sizes(tree, "wave_%d" % entry.wave)
		await mouse.click(tree, reward, Vector2(480, 1720))
		test.assert_equal(w.phase, "playing", "closing a configured reward resumes the battle")
	if capture:
		await tree.create_timer(2.0).timeout
		await sizes(tree, "victory")
	app.queue_free()
	await tree.process_frame

func sizes(tree: SceneTree, label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await tree.create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		assert(tree.root.get_texture().get_image().save_png("res://validation/defense/two_elites_one_boss/%s_%d.png" % [label, width]) == OK)
