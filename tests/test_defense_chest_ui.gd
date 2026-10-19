extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test: TestSupport, tree: SceneTree) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var w = app.session
	w.start(53)
	for hero_id in [1, 2, 4, 13, 17]:
		w.factory.add_hero(hero_id)
	w.phase = "playing"
	w.offers.clear()
	w.pending.clear()
	w.rules.chest_reward_weights = [0, 0, 0, 1]
	var enemy = w.factory.create("elite", 101, Vector2(800, 690), 2)
	w.damage.defeat(enemy, {})
	w.step()
	var view = app.get_node("DefenseView")
	var panel = view.get_node("RewardPanel")
	view.render(app.battle_snapshot())
	panel.set_process(false)
	await tree.create_timer(0.15).timeout
	test.assert_true(panel.visible and not view.get_node("ChoicePanel").visible, "real death automatically opens roulette instead of the old card or ground chest")
	test.assert_equal(panel.get_node("Source").text, "精英掉落", "center identifies the actual elite drop")
	test.assert_true(not panel.has_node("Count") and not panel.has_node("CountCaption"), "source replaces the central count and caption")
	for slot in panel.get_node("Wheel").get_children():
		test.assert_true(not slot.has_node("Name"), "roulette tiles contain icons without term labels")
	test.assert_equal(panel.get_node("Results/Rows").get_child_count(), 4, "four real awards have four result rows")
	test.assert_true(not panel.finished, "roulette starts with count and spinning animation")
	var random_state: Dictionary = w.rng.snapshot()
	var history: Array = w.history.duplicate(true)
	var before: int = w.time_ms
	w.step()
	test.assert_equal(w.time_ms, before, "the battle clock stops while the roulette is visible")
	test.assert_equal(w.submit("reward_close", {"id": -1}), "奖励已关闭", "an invalid completion cannot dismiss the active reward")
	var mouse = Mouse.new()
	# A drag is for reading, never an instruction to skip or dismiss.
	var press = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = panel.get_global_transform_with_canvas() * Vector2(420, 360)
	tree.root.push_input(press, true)
	var release = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = panel.get_global_transform_with_canvas() * Vector2(420, 460)
	tree.root.push_input(release, true)
	await tree.process_frame
	test.assert_true(not panel.finished, "reading gestures do not skip the animation")
	await mouse.click(tree, panel, Vector2(480, 360))
	test.assert_true(panel.finished and w.phase == "reward", "first real click skips animation and keeps the result open")
	for i in range(4):
		var item: Dictionary = w.loot.current.items[i]
		var row = panel.get_node("Results/Rows").get_child(i)
		test.assert_equal(row.get_node("Content/Text/Description").text, app._catalog.record("options", item.id).description, "result rows use the user's exact original descriptions")
		test.assert_equal(row.modulate.a, 1.0, "all skipped results are fully visible")
	test.assert_equal(w.rng.snapshot(), random_state, "skip consumes no gameplay randomness")
	test.assert_equal(w.history, history, "skip does not grant the award again")
	# Completing over the old pause button must not leak through the overlay.
	await mouse.click(tree, panel, Vector2(65, 40))
	test.assert_true(w.phase == "playing" and not panel.visible and not w.paused, "second real click dismisses without clicking the HUD underneath")
	test.assert_equal(w.history, history, "closing keeps the exact already-granted awards")
	test.assert_equal(w.refresh_left, 2, "automatic chest rewards do not spend refreshes")
	# The following queued reward receives its own two-click interaction.
	w.rules.chest_reward_weights = [1, 0, 0, 0]
	w.loot.enqueue("elite")
	w.loot.enqueue("boss")
	w.loot.advance()
	view.render(app.battle_snapshot())
	await tree.create_timer(0.1).timeout
	var first: int = panel.packet.id
	await mouse.click(tree, panel, Vector2(480, 1720))
	await mouse.click(tree, panel, Vector2(480, 1720))
	test.assert_true(panel.visible and panel.packet.id != first and not panel.finished, "next queued reward starts a new animation")
	test.assert_equal(panel.get_node("Source").text, "首领掉落", "queued boss drop changes the central source text")
	panel.set_process(true)
	var next_history: Array = w.history.duplicate(true)
	await tree.create_timer(panel.duration() + 0.1).timeout
	test.assert_true(panel.finished, "normal playback reveals the result without any skip input")
	test.assert_equal(w.history, next_history, "normal playback also leaves rewards unchanged")
	await mouse.click(tree, panel, Vector2(480, 1720))
	test.assert_true(w.phase == "playing" and not panel.visible, "completed animation needs one final click to resume")
	w.choices.options.clear()
	w.loot.enqueue("elite")
	w.loot.advance()
	view.render(app.battle_snapshot())
	test.assert_true(panel.visible and panel.finished and not panel.get_node("Wheel").visible, "exhausted library has a complete non-spinning notice")
	test.assert_equal(panel.get_node("Status").text, "词条已全部获得", "exhaustion is explained without a zero-item lottery")
	await mouse.click(tree, panel, Vector2(480, 1720))
	test.assert_true(w.phase == "playing" and not panel.visible, "exhaustion notice closes with one click")
	app.queue_free()
	await tree.process_frame
