extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test: TestSupport, tree: SceneTree) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ChoicePanel")
	var mouse = Mouse.new()
	view.intent_requested.emit("start", {"seed": 889})
	await mouse.click(tree, panel.get_node("Cards/Card0"), Vector2(146, 405))
	test.assert_equal(app.battle_snapshot().heroes.size(), 0, "text-title selection stays locked during entrance")
	await tree.create_timer(0.75).timeout
	var before: Dictionary = app.battle_snapshot()
	var random_before: Dictionary = app.session.rng.snapshot()
	for i in range(before.offers.size()):
		var card = panel.get_node("Cards").get_child(i)
		test.assert_true(not card.has_node("Skill"), "candidate has no skill icon or obsolete hit target")
		test.assert_equal(card.tooltip_text, "", "candidate does not obscure adjacent cards with a native tooltip")
		test.assert_equal(card.get_node("TermName").text, card.option.title, "candidate directly names its initial skill")
		test.assert_equal(card.get_node("Description/Text").text, "招募%s" % card.hero.name, "candidate description only names the recruitment")
		await mouse.click(tree, card.get_node("Info"))
		test.assert_true(view.get_node("BattlePanels/Hero").visible, "text candidate keeps its hero attribute entry")
		await mouse.click(tree, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1460))
	await tree.create_timer(0.2).timeout
	test.assert_equal(app.battle_snapshot().history, before.history, "reading descriptions and attributes cannot recruit a candidate")
	test.assert_equal(app.session.rng.snapshot(), random_before, "reading text consumes no gameplay RNG")
	# Reuse the production card for every currently available hero definition.
	var card = panel.get_node("Cards/Card0")
	for item in app.session.choices.hero_pool():
		var hero: Dictionary = app._catalog.record("heroes", item.id)
		card.configure(view.atlas, item, app._catalog, before)
		await tree.process_frame
		await tree.process_frame
		test.assert_true(card.get_node("Description").visible, "every recruit displays its description without a popup")
		test.assert_equal(card.get_node("Description/Text").text, "招募%s" % hero.name, "every recruit uses only the requested recruitment text")
		test.assert_true(card.get_node("Traits").text.contains(hero.tags[0].title) and card.get_node("Traits").text.contains(hero.tags[1].title), "race and profession remain readable as text")
		test.assert_true(not card.has_node("Skill") and not card.has_node("SkillName"), "all five recruits use the shared text layout")
		test.assert_true(card.get_node("Description/Text").size.x <= card.get_node("Description").size.x, "recruit description wraps within the card")
	panel.last_key = ""
	view.render(app.battle_snapshot())
	await tree.create_timer(0.75).timeout
	await mouse.click(tree, panel.get_node("Cards/Card0/TermName"))
	await tree.create_timer(0.2).timeout
	test.assert_equal(app.battle_snapshot().heroes.size(), 1, "clicking the skill title recruits the displayed candidate once")
	app.queue_free()
	await tree.process_frame
	await tree.process_frame
