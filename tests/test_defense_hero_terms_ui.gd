extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func grant(w, hero: Dictionary, option_id: int) -> void:
	var option: Dictionary = w.catalog.record("options", option_id)
	assert(w.choices.eligible(option, hero), "term fixture must satisfy the real prerequisites and count limit")
	w.offers = [w.choices.card(option, hero.id)]
	w.phase = "choice"
	assert(w.choices.choose(0).is_empty(), "term fixture uses the public choice operation")

func run(test: TestSupport, tree: SceneTree, capture: bool = false) -> void:
	var mouse = Mouse.new()
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("HeroTerms")
	var rows = panel.get_node("Panel/Scroll/Rows")
	view.send("start", {"seed": 3})
	await tree.create_timer(0.7).timeout
	await mouse.click(tree, view.get_node("ChoicePanel/Cards/Card0"), Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	var w = app.session
	for template in [4, 1, 2, 13, 17]:
		if not w.heroes.any(func(id): return w.units[id].template == template):
			w.factory.add_hero(template)
	var assassin: Dictionary = {}
	var assassin_index: int = -1
	for i in range(w.heroes.size()):
		if w.units[w.heroes[i]].template == 17:
			assassin = w.units[w.heroes[i]]
			assassin_index = i
	for id in [200501, 200501, 200502, 200503, 200504, 200505, 200506, 200507, 200508]:
		grant(w, assassin, id)
	view.render(w.snapshot())
	var before: Dictionary = w.snapshot()
	var rng: Dictionary = w.rng.snapshot()
	await mouse.click(tree, view.get_node("HUD/Hero%d/Portrait" % assassin_index))
	await tree.process_frame
	test.assert_true(panel.visible and not view.get_node("BattlePanels/Hero").visible, "real roster click opens selected terms instead of attributes")
	test.assert_true(not panel.has_node("Panel/Close"), "secondary panel has no close button")
	test.assert_equal(panel.get_node("Panel/HeroName").text, assassin.name, "panel names the actual selected hero")
	test.assert_equal(panel.get_node("Heroes").get_child_count(), 5, "side rail contains only the five owned heroes")
	test.assert_equal(rows.get_child_count(), 8, "duplicate terms merge into one entry and the initial skill is excluded")
	test.assert_true(not rows.get_children().any(func(row): return row.option_id == 200500), "assassination starter is not listed as a selected term")
	for row in rows.get_children():
		var option: Dictionary = app._catalog.record("options", row.option_id)
		test.assert_equal(row.get_node("Heading/Line/Name").text, option.title, "term name uses source wording")
		test.assert_equal(row.get_node("Description").get_parsed_text(), option.description, "term description preserves original text, brackets and line breaks")
		var count_label = row.get_node("Heading/Line/Count")
		if row.option_id == 200501:
			test.assert_true(count_label.visible and count_label.text == "X2", "repeated selection displays uppercase X and the actual quantity")
			test.assert_equal(count_label.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "repeat quantity is right aligned")
			test.assert_true(absf(count_label.get_rect().end.x - count_label.get_parent().size.x) < 1, "quantity occupies the right edge of the term name line")
		else:
			test.assert_true(not count_label.visible and count_label.text.is_empty(), "single selections have no quantity suffix")
	test.assert_equal(w.snapshot(), before, "opening terms does not issue commands or alter combat state")
	test.assert_equal(w.rng.snapshot(), rng, "opening terms consumes no gameplay randomness")
	var first_row = rows.get_child(0)
	for i in range(10):
		view.render(w.snapshot())
		await tree.process_frame
	test.assert_equal(rows.get_child(0), first_row, "unchanged combat snapshots reuse the existing term rows")
	var clock: int = w.time_ms
	app.set_process(true)
	await tree.create_timer(0.18).timeout
	app.set_process(false)
	test.assert_true(w.time_ms > clock and panel.visible and not w.paused, "real battle frames continue while the secondary panel is open")
	if capture:
		await sizes(test, tree, panel, "selected_terms")
	var scroll = panel.get_node("Panel/Scroll")
	await drag(tree, scroll, false)
	test.assert_true(scroll.scroll_vertical > 0 and panel.visible and not w.paused, "dragging with the mouse scrolls inside the frame without closing or pausing")
	scroll.scroll_vertical = 0
	await tree.process_frame
	await drag(tree, scroll, true)
	test.assert_true(scroll.scroll_vertical > 0 and panel.visible and not w.paused, "touch swipe scrolls inside the frame without closing or pausing")
	for i in range(18):
		await wheel(tree, scroll)
	test.assert_true(scroll.scroll_vertical > 0, "actual mouse wheel scrolls the long selected-term list")
	var last_row = rows.get_child(rows.get_child_count() - 1)
	test.assert_true(last_row.get_global_rect().end.y <= scroll.get_global_rect().end.y + 2, "scrolling reaches the complete final term")
	if capture:
		await shot(tree, "selected_terms_bottom_720")
	for i in range(w.heroes.size()):
		await mouse.click(tree, panel.get_node("Heroes").get_child(i))
		var hero: Dictionary = w.units[w.heroes[i]]
		test.assert_equal(panel.selected_hero_id, hero.id, "side portrait switches to its runtime owner")
		test.assert_equal(panel.get_node("Panel/HeroName").text, hero.name, "side selection updates hero identity")
		var expected: Array = []
		var initial: Array = app._catalog.record("heroes", int(hero.template)).initial_options.map(func(id): return int(id))
		for id in hero.upgrades:
			if not initial.has(int(id)) and not expected.has(id):
				expected.append(id)
		test.assert_equal(rows.get_children().map(func(row): return row.option_id), expected, "each hero shows only its own selected terms in acquisition order")
		test.assert_equal(panel.get_node("Panel/Empty").visible, expected.is_empty(), "heroes with only initial skills show the empty strengthening state")
		test.assert_equal(scroll.scroll_vertical, 0, "switching heroes resets the term scroll position")
		test.assert_true(not w.paused, "side selection leaves combat running")
	var hero: Dictionary = w.units[w.heroes[0]]
	await mouse.click(tree, panel.get_node("Heroes").get_child(0))
	if capture:
		await shot(tree, "initial_terms_720")
	var initial_count: int = rows.get_child_count()
	for option: Dictionary in app._catalog.records("options").values():
		if hero.template in option.get("type", []) and w.choices.eligible(option, hero):
			grant(w, hero, int(option.id))
			break
	view.render(w.snapshot())
	await tree.process_frame
	test.assert_equal(rows.get_child_count(), initial_count + 1, "a real newly acquired term refreshes the open panel")
	await mouse.click(tree, panel.get_node("Backdrop"), Vector2(480, 1800))
	test.assert_true(not panel.visible and not w.paused, "outside blank area dismisses without pausing")
	await mouse.click(tree, view.get_node("HUD/Hero0/Portrait"))
	await mouse.click(tree, view.get_node("HUD/Hero0/Portrait"))
	test.assert_true(not panel.visible and not w.paused, "outside click over the underlying portrait dismisses without reopening it")
	await mouse.click(tree, view.get_node("HUD/Hero0/Portrait"))
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	tree.root.push_input(escape, true)
	await tree.process_frame
	test.assert_true(not panel.visible and not w.paused, "Escape closes the new panel without toggling pause")
	await mouse.click(tree, view.get_node("HUD/Pause"))
	test.assert_true(w.paused, "manual pause remains reachable after scrolling and closing selected terms")
	await mouse.click(tree, view.get_node("BattlePanels/Pause/Resume"))
	test.assert_true(not w.paused, "manual resume remains reachable after browsing selected terms")
	await mouse.click(tree, view.get_node("HUD/Hero0/Portrait"))
	w.loot.enqueue("elite")
	w.loot.advance()
	view.render(w.snapshot())
	test.assert_true(not panel.visible and view.get_node("RewardPanel").visible, "automatic rewards replace the browsing panel without an input-blocking overlay")
	view.send("quit")
	view.send("home")
	test.assert_true(not panel.visible and panel.selected_hero_id == 0, "leaving the run clears the old panel selection")
	app.queue_free()
	await tree.process_frame

func wheel(tree: SceneTree, control: Control) -> void:
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = control.get_global_transform_with_canvas() * (control.size / 2)
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

func drag(tree: SceneTree, control: Control, touch: bool) -> void:
	var from = control.get_global_transform_with_canvas() * Vector2(control.size.x / 2, control.size.y * 0.75)
	var to = control.get_global_transform_with_canvas() * Vector2(control.size.x / 2, control.size.y * 0.3)
	if touch:
		from = tree.root.get_final_transform() * from
		to = tree.root.get_final_transform() * to
		var down = InputEventScreenTouch.new()
		down.position = from
		down.index = 0
		down.pressed = true
		Input.parse_input_event(down)
	else:
		var down = InputEventMouseButton.new()
		down.position = from
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		tree.root.push_input(down, true)
	await tree.process_frame
	var previous: Vector2 = from
	for i in range(1, 9):
		var point = from.lerp(to, i / 8.0)
		if touch:
			var motion = InputEventScreenDrag.new()
			motion.position = point
			motion.relative = point - previous
			motion.index = 0
			Input.parse_input_event(motion)
		else:
			var motion = InputEventMouseMotion.new()
			motion.position = point
			motion.relative = point - previous
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			tree.root.push_input(motion, true)
		previous = point
		await tree.process_frame
	if touch:
		var up = InputEventScreenTouch.new()
		up.position = to
		up.index = 0
		up.pressed = false
		Input.parse_input_event(up)
	else:
		var up = InputEventMouseButton.new()
		up.position = to
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		tree.root.push_input(up, true)
	await tree.process_frame

func sizes(test: TestSupport, tree: SceneTree, panel: Control, name: String) -> void:
	for width in [720, 540, 960]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await tree.create_timer(0.1).timeout
		var line = panel.get_node("Panel/Scroll/Rows").get_child(0).get_node("Heading/Line")
		test.assert_true(line.get_node("Name").get_global_rect().end.x <= line.get_node("Count").get_global_rect().position.x, "name and right-aligned quantity do not overlap at width %d" % width)
		await shot(tree, "%s_%d" % [name, width])
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await tree.create_timer(0.1).timeout

func shot(tree: SceneTree, name: String) -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	assert(tree.root.get_texture().get_image().save_png("res://validation/defense/hero_terms/%s.png" % name) == OK)
