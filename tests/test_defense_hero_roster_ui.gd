extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test: TestSupport, tree: SceneTree) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ChoicePanel")
	var tooltip = view.get_node("SkillTooltip")
	var mouse = Mouse.new()
	view.intent_requested.emit("start", {"seed": 53})
	await tree.create_timer(0.75).timeout
	var before: Dictionary = app.battle_snapshot()
	var rng: Dictionary = app.session.rng.snapshot()
	for i in range(3):
		var card = panel.get_node("Cards").get_child(i)
		test.assert_true(not card.has_node("Skill") and not card.has_node("Skill2"), "recruit card uses text instead of skill icon controls")
		test.assert_equal(card.get_node("Title").text, app._catalog.record("heroes", before.offers[i].id).name, "candidate title uses the new hero name")
		test.assert_equal(card.get_node("Description/Text").text, "招募%s" % card.hero.name, "candidate only shows recruitment text inline")
		await mouse.click(tree, card.get_node("Info"))
		test.assert_equal(view.get_node("BattlePanels").hero.upgrades, app._catalog.record("heroes", before.offers[i].id).initial_options, "candidate attributes preview its single learned base skill")
		await mouse.click(tree, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1460))
	test.assert_equal(app.battle_snapshot().history, before.history, "inspection cannot recruit a candidate")
	test.assert_equal(app.session.rng.snapshot(), rng, "inspection consumes no gameplay randomness")
	await mouse.click(tree, panel.get_node("Cards/Card0"), Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	for hid in [1, 2, 4, 13, 17]:
		app.session.factory.add_hero(hid)
	view.render(app.battle_snapshot())
	before = app.battle_snapshot()
	for i in range(5):
		var card = view.get_node("HUD/Hero%d" % i)
		test.assert_equal(card.hero.skills.size(), 1, "five roster slots each expose one actual skill")
		test.assert_true(not card.has_node("Skill2"), "obsolete second roster button is removed")
		test.assert_equal(card.get_node("Skill").get_rect().get_center().x, card.size.x / 2, "single roster skill stays centered")
		await mouse.click(tree, card.get_node("Skill"))
		test.assert_true(tooltip.visible and tooltip.target_index == i, "each roster icon opens its corresponding hero skill")
		test.assert_equal(tooltip.get_node("Paper/Description").text, before.heroes[i].skills[0].description, "roster description agrees with its actual skill")
		test.assert_true(not app.battle_snapshot().paused, "inspection leaves combat running")
	await mouse.click(tree, tooltip.get_node("Paper"))
	test.assert_true(not tooltip.visible, "paper dismisses the skill bubble")
	app.session.paused = true
	view.render(app.battle_snapshot())
	view.show_skill(0)
	test.assert_true(tooltip.visible and app.battle_snapshot().paused, "inspection preserves manual pause")
	tooltip.dismiss()
	app.queue_free()
	await tree.process_frame
