extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
const Warrior = preload("res://tests/test_defense_warrior_ui.gd")

func run(test: TestSupport, tree: SceneTree) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var field = view.get_node("Field")
	var tooltip = view.get_node("SkillTooltip")
	var mouse = Mouse.new()
	view.intent_requested.emit("start", {"seed": Warrior.new().recruit_seed(app._catalog)})
	await tree.create_timer(0.7).timeout
	var warrior_index = -1
	for i in range(app.battle_snapshot().offers.size()):
		if app.battle_snapshot().offers[i].id == 4:
			warrior_index = i
	test.assert_true(warrior_index >= 0, "range fixture recruits warrior from a real offer")
	if warrior_index < 0:
		app.queue_free()
		await tree.process_frame
		return
	await mouse.click(tree, view.get_node("ChoicePanel/Cards").get_child(warrior_index), Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	var button = view.get_node("HUD/Hero0/Skill")
	await mouse.click(tree, button)
	test.assert_true(tooltip.visible and field.range_hero_id == 0, "short press keeps skill description without range preview")
	var before: Dictionary = app.battle_snapshot()
	var rng: Dictionary = app.session.rng.snapshot()
	await press(tree, button, true)
	await tree.create_timer(0.15).timeout
	test.assert_equal(field.range_hero_id, 0, "press below hold threshold does not show range")
	await tree.create_timer(0.3).timeout
	test.assert_equal(field.range_hero_id, before.heroes[0].id, "held icon previews the corresponding real hero")
	test.assert_true(not tooltip.visible, "range preview dismisses the existing skill bubble")
	test.assert_equal(field.skill_range(), {"center": field.world(before.heroes[0].pos), "radius": 200.0}, "shield range is foot-centered with actual casting radius")
	var phase: float = field.range_flow
	await tree.create_timer(0.1).timeout
	test.assert_true(field.range_flow != phase, "dash border flows on presentation time")
	view.get_node("HUD/Hero1/Skill").mouse_exited.emit()
	test.assert_equal(field.range_hero_id, before.heroes[0].id, "an unrelated icon exit cannot cancel the held skill")
	test.assert_equal(app.battle_snapshot(), before, "range inspection preserves the complete combat snapshot")
	test.assert_equal(app.session.rng.snapshot(), rng, "range inspection consumes no gameplay randomness")
	var hero: Dictionary = app.session.units[app.session.heroes[0]]
	hero.pos += Vector2(30, -20)
	view.render(app.battle_snapshot())
	test.assert_equal(field.skill_range().center, field.world(hero.pos), "preview follows moving hero without another press")
	app.session.upgrades.apply(hero, 200103)
	view.render(app.battle_snapshot())
	test.assert_equal(field.skill_range().radius, 200.0, "taunt expansion leaves the casting preview at two hundred")
	await press(tree, button, false)
	test.assert_equal(field.range_hero_id, 0, "releasing the icon hides range immediately")
	test.assert_true(not tooltip.visible, "long release does not accidentally trigger a short-click bubble")
	await mouse.click(tree, button)
	test.assert_true(tooltip.visible, "short press still works after a long press")
	tooltip.dismiss()
	await touch(tree, button, true)
	await tree.create_timer(0.45).timeout
	test.assert_equal(field.range_hero_id, before.heroes[0].id, "touchscreen hold uses the same range interaction")
	await touch(tree, button, false)
	test.assert_true(field.range_hero_id == 0 and not tooltip.visible, "touch release clears range without a short-click bubble")
	await press(tree, button, true)
	await tree.create_timer(0.45).timeout
	var move = InputEventMouseMotion.new()
	move.position = button.get_global_transform_with_canvas() * Vector2(-20, 0)
	tree.root.push_input(move, true)
	await tree.process_frame
	test.assert_equal(field.range_hero_id, 0, "dragging outside the icon cancels range")
	await press(tree, button, false, Vector2(-20, 0))
	test.assert_true(not tooltip.visible, "drag cancellation cannot open a description")
	await press(tree, button, true)
	await tree.create_timer(0.45).timeout
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	tree.root.push_input(escape, true)
	await tree.process_frame
	test.assert_equal(field.range_hero_id, 0, "Escape cancels range preview")
	test.assert_true(not app.battle_snapshot().paused, "cancelling preview with Escape does not pause combat")
	await press(tree, button, false)
	await press(tree, button, true)
	await tree.create_timer(0.45).timeout
	hero.dead = true
	view.render(app.battle_snapshot())
	test.assert_equal(field.range_hero_id, 0, "hero death clears a held preview")
	await press(tree, button, false)
	hero.dead = false
	view.render(app.battle_snapshot())
	await press(tree, button, true)
	await tree.create_timer(0.45).timeout
	view.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	test.assert_equal(field.range_hero_id, 0, "window focus loss clears held range")
	await press(tree, button, false)
	await press(tree, button, true)
	await tree.create_timer(0.45).timeout
	view.send("pause")
	test.assert_equal(field.range_hero_id, 0, "pause clears held range")
	await press(tree, button, false)
	view.send("pause")
	for hid in [1, 2, 13, 17]:
		app.session.factory.add_hero(hid)
	view.render(app.battle_snapshot())
	var radii = [200.0, 1200.0, 900.0, 900.0, 400.0]
	for i in range(5):
		button = view.get_node("HUD/Hero%d/Skill" % i)
		await press(tree, button, true)
		await tree.create_timer(0.45).timeout
		test.assert_equal(field.range_hero_id, app.battle_snapshot().heroes[i].id, "each hero icon owns its preview")
		test.assert_equal(field.skill_range().radius, radii[i], "each skill uses its own live maximum casting distance")
		await press(tree, button, false)
	app.session.choices.offer("upgrade")
	view.render(app.battle_snapshot())
	await tree.create_timer(0.7).timeout
	button = view.get_node("HUD/Hero0/Skill")
	await press(tree, button, true)
	await tree.create_timer(0.45).timeout
	test.assert_equal(field.range_hero_id, 0, "choice overlay does not expose a battle range underneath its cards")
	await press(tree, button, false)
	test.assert_true(tooltip.visible, "skill descriptions remain accessible during choices")
	test.assert_equal(app.battle_snapshot().time, before.time, "range inspection does not advance the rule clock")
	app.queue_free()
	await tree.process_frame

func press(tree: SceneTree, control: Control, down: bool, point: Vector2 = Vector2.INF) -> void:
	var event = InputEventMouseButton.new()
	event.position = control.get_global_transform_with_canvas() * (control.size / 2 if point == Vector2.INF else point)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	tree.root.push_input(event, true)
	await tree.process_frame

func touch(tree: SceneTree, control: Control, down: bool) -> void:
	var event = InputEventScreenTouch.new()
	event.position = tree.root.get_final_transform() * control.get_global_transform_with_canvas() * (control.size / 2)
	event.index = 0
	event.pressed = down
	Input.parse_input_event(event)
	await tree.process_frame
