extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test: TestSupport, tree: SceneTree) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ChoicePanel")
	var details = view.get_node("BattlePanels")
	var mouse = Mouse.new()
	view.intent_requested.emit("start", {"seed": 3})
	await tree.create_timer(0.75).timeout
	for i in range(3):
		await mouse.click(tree, panel.get_node("Cards").get_child(i).get_node("Info"))
		var definition = app._catalog.record("heroes", int(app.battle_snapshot().offers[i].id))
		test.assert_true(details.get_node("Hero").visible, "candidate i opens the top attribute panel")
		test.assert_equal(details.hero.template, definition.id, "new hero info matches the candidate definition")
		test.assert_equal(details.hero.attributes, definition.base, "unrecruited candidate info displays baseline attributes")
		await mouse.click(tree, details.get_node("Hero/Close"), Vector2(480, 1460))
	var fire_index := -1
	for i in range(app.battle_snapshot().offers.size()):
		if app.battle_snapshot().offers[i].id == 1:
			fire_index = i
	await mouse.click(tree, panel.get_node("Cards").get_child(fire_index), Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	app.session.upgrades.apply(app.session.units[app.session.heroes[0]], 3)
	# Add another real owned hero so owner identity differs from the candidate slot.
	app.session.factory.add_hero(2)
	app.session.pending = [app.session.heroes[0]]
	app.session.choices.offer("bonus")
	view.render(app.battle_snapshot())
	await tree.create_timer(0.75).timeout
	var before: Dictionary = app.battle_snapshot()
	var random_before: Dictionary = app.session.rng.snapshot()
	for i in range(before.offers.size()):
		var card = panel.get_node("Cards").get_child(i)
		test.assert_equal(card.get_node("Description/Text").text, card.option.description, "upgrade explanation is inline before opening attributes")
		await mouse.click(tree, card.get_node("Info"))
		view.render(app.battle_snapshot())
		var owner: Dictionary = {}
		for owned: Dictionary in before.heroes:
			if int(owned.id) == int(before.offers[i].owner):
				owner = owned
		test.assert_true(details.get_node("Hero").visible, "upgrade i opens hero attributes instead of an option description modal")
		test.assert_true(not view.get_node("SkillTooltip").visible, "inline upgrade explanation needs no separate bubble")
		test.assert_equal(details.hero.id, owner.id, "upgrade i resolves the owning runtime hero")
		test.assert_equal(details.hero.attributes, owner.attributes, "upgrade i uses current attributes")
		test.assert_equal(details.hero.upgrades, owner.upgrades, "upgrade i shows learned skills rather than the unchosen option")
		test.assert_equal(details.hero.stats, owner.stats, "upgrade i shows the owner's battle statistics")
		await mouse.click(tree, details.get_node("Hero/Expand"))
		test.assert_true(details.expanded, "upgrade attributes support the existing expand arrow")
		var escape = InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		tree.root.push_input(escape, true)
		await tree.process_frame
		test.assert_true(not details.get_node("Hero").visible, "Escape closes the upgrade attribute panel")
	await tree.create_timer(0.2).timeout
	test.assert_equal(app.battle_snapshot().offers, before.offers, "attribute inspection preserves upgrade candidates")
	test.assert_equal(app.battle_snapshot().history, before.history, "attribute inspection cannot queue or apply a choice")
	test.assert_equal(app.battle_snapshot().time, before.time, "attribute inspection does not change the stopped choice clock")
	test.assert_equal(app.battle_snapshot().paused, before.paused, "attribute inspection preserves pause state")
	test.assert_equal(app.session.rng.snapshot(), random_before, "attribute inspection consumes no gameplay RNG")
	app.queue_free()
	await tree.process_frame
	await tree.process_frame
