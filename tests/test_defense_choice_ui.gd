extends RefCounted

func run(test: TestSupport, tree: SceneTree) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ChoicePanel")
	view.intent_requested.emit("start", {"seed": 889})
	await tree.process_frame
	test.assert_true(panel.busy, "entrance blocks early card and refresh input")
	await click(tree, panel.get_node("Cards/Card0"), Vector2(146, 315))
	test.assert_equal(app.battle_snapshot().history.size(), 0, "early click cannot select invisible cards")
	await tree.create_timer(0.7).timeout
	test.assert_equal(app.battle_snapshot().time, 0, "world stays stopped during choice reveal")
	test.assert_true(not panel.busy, "reveal unlocks real controls")
	var entrances: int = panel.entrances
	await click(tree, panel.get_node("Cards/Card0/Info"))
	var battle_panels = view.get_node("BattlePanels")
	test.assert_true(battle_panels.get_node("Hero").visible, "info mouse target opens hero details")
	test.assert_equal(app.battle_snapshot().history.size(), 0, "info does not propagate to card selection")
	test.assert_equal(battle_panels.hero.upgrades[0], app._catalog.record("heroes", int(app.battle_snapshot().offers[0].id)).initial_options[0], "details match selected hero initial skill")
	await click(tree, battle_panels.get_node("Hero/Close"))
	test.assert_equal(panel.entrances, entrances, "closing info does not replay entrance")
	await click(tree, panel.get_node("Refresh"))
	test.assert_equal(app.battle_snapshot().refresh_left, 1, "first real refresh leaves one run-wide use")
	test.assert_equal(panel.entrances, entrances + 1, "refresh replays reveal exactly once")
	await tree.create_timer(0.7).timeout
	await click(tree, panel.get_node("Refresh"))
	test.assert_equal(app.battle_snapshot().refresh_left, 0, "second real refresh exhausts the run-wide budget")
	test.assert_equal(panel.entrances, entrances + 2, "second refresh reveals the replacement deal once")
	await tree.create_timer(0.7).timeout
	test.assert_true(panel.get_node("Refresh").disabled, "refresh button disables after both uses")
	test.assert_equal(panel.get_node("Refresh/Remaining").text, "剩余0", "button displays the true exhausted budget")
	var offers = app.battle_snapshot().offers.duplicate(true)
	await click(tree, panel.get_node("Refresh"))
	test.assert_equal(app.battle_snapshot().offers, offers, "exhausted refresh cannot redraw or mutate offers")
	var pick = 0
	while int(offers[pick].id) == 6:
		pick += 1
	await click(tree, panel.get_node("Cards/Card%d" % pick), Vector2(146, 315))
	await click(tree, panel.get_node("Cards/Card%d" % pick), Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	test.assert_equal(app.battle_snapshot().heroes.size(), 1, "double click recruits exactly one hero")
	test.assert_equal(app.battle_snapshot().history.size(), 1, "confirmation commits one choice")
	test.assert_equal(app.battle_snapshot().heroes[0].template, offers[pick].id, "card mouse input recruits the displayed hero")
	view.intent_requested.emit("quit", {})
	view.intent_requested.emit("home", {})
	view.intent_requested.emit("start", {"seed": 889})
	test.assert_equal(app.battle_snapshot().refresh_left, 2, "a new run resets the shared refresh budget to two")
	await tree.create_timer(0.7).timeout
	entrances = panel.entrances
	await click(tree, panel.get_node("Cards/Card0"), Vector2(146, 315))
	view.intent_requested.emit("pause", {})
	await tree.create_timer(0.2).timeout
	test.assert_equal(app.battle_snapshot().history.size(), 0, "pause cancels delayed confirmation")
	var damage_before: bool = view.get_node("Field").damage_numbers
	await click(tree, battle_panels.get_node("Pause/Damage"))
	test.assert_equal(view.get_node("Field").damage_numbers, not damage_before, "pause damage control changes number display")
	test.assert_equal(app.battle_snapshot().phase, "choice", "display control does not overlap quit")
	await click(tree, battle_panels.get_node("Pause/Resume"))
	test.assert_equal(panel.entrances, entrances, "resume preserves this choice without replay")
	test.assert_true(not panel.busy, "resume restores selectable cards")
	await click(tree, panel.get_node("Cards/Card0"), Vector2(146, 315))
	app.session.choices.offer("hero", true)
	view.render(app.battle_snapshot())
	await tree.create_timer(0.7).timeout
	test.assert_equal(app.battle_snapshot().history.size(), 0, "replacement offers cancel old delayed selection")
	test.assert_equal(panel.get_node("Cards/Card0/Title").text, app.battle_snapshot().offers[0].title, "replacement offer uses the displayed hero metadata")
	var card = panel.get_node("Cards/Card0")
	for option: Dictionary in app._catalog.records("options").values():
		if int(option.get("options_num", 0)) <= 0:
			continue
		var owners: Array = option.get("type", []).filter(func(id): return id > 0 and id <= 18)
		if owners.is_empty():
			continue
		var definition: Dictionary = app._catalog.record("heroes", owners[0])
		card.configure(view.atlas, {"kind": "upgrade", "id": option.id, "owner": 1, "res": definition.res, "description": option.description}, app._catalog, {"heroes": [{"id": 1, "template": definition.id}]})
		var label = card.get_node("TermName")
		var width: float = view.atlas.font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		test.assert_true(width + 20 <= label.size.x, "selectable name fits without truncation: %s" % option.title)
	app.queue_free()
	await tree.process_frame
	await tree.process_frame

func click(tree: SceneTree, control: Control, point: Vector2 = Vector2.INF) -> void:
	var pos = control.get_global_transform_with_canvas() * (control.size / 2 if point == Vector2.INF else point)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame
