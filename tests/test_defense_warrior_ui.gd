extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")

func recruit_seed(catalog) -> int:
	for seed in range(1, 40):
		var probe = Session.new(catalog)
		probe.start(seed)
		var found = probe.offers.any(func(item): return item.id == 4)
		probe.dispose()
		if found:
			return seed
	assert(false, "warrior recruitment seed must exist")
	return 1

func term_offer(w, term: int) -> int:
	var owner: int = w.heroes[0]
	assert(w.choices.eligible(w.catalog.record("options", 200000 + term), w.units[owner]))
	w.pending = [owner]
	for i in range(40):
		w.choices.offer("bonus")
		for index in range(w.offers.size()):
			if w.offers[index].id == 200000 + term:
				return index
	assert(false, "eligible term must appear in the bonus fixture")
	return 0

func run(test: TestSupport, tree: SceneTree) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ChoicePanel")
	var tooltip = view.get_node("SkillTooltip")
	var mouse = Mouse.new()
	view.intent_requested.emit("start", {"seed": recruit_seed(app._catalog)})
	await tree.create_timer(0.75).timeout
	var index: int = app.session.offers.map(func(item): return item.id).find(4)
	var card = panel.get_node("Cards").get_child(index)
	test.assert_true(not card.has_node("Skill"), "warrior recruitment removes its skill icon")
	test.assert_equal(card.get_node("Description/Text").text, "招募勇者", "recruitment only names the warrior")
	await mouse.click(tree, card, Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	test.assert_equal(app.battle_snapshot().heroes[0].upgrades, [200100], "real recruitment grants the new shield only")
	# Reward fixtures supply legal bonus rounds; clicks use the production Intent.
	for term in [101, 103, 105, 104, 106, 107, 102]:
		index = term_offer(app.session, term)
		view.render(app.battle_snapshot())
		await tree.create_timer(0.75).timeout
		card = panel.get_node("Cards").get_child(index)
		var before: Dictionary = app.session.selected.duplicate()
		var rng: Dictionary = app.session.rng.snapshot()
		test.assert_true(not card.has_node("Skill"), "warrior terms omit the redundant skill circle")
		test.assert_equal(card.get_node("Description/Text").text, app._catalog.record("options", 200000 + term).description, "new term description appears directly on the card")
		await tree.process_frame
		test.assert_true(card.get_node("Description/Text").size.y <= card.get_node("Description").size.y, "every current warrior term fits without scrolling")
		if term == 102:
			test.assert_equal(card.get_node("Description/Text").get_line_count(), 1, "short cooldown description stays on one line without splitting the Chinese word")
		test.assert_equal(app.session.selected, before, "viewing a term cannot acquire it")
		test.assert_equal(app.session.rng.snapshot(), rng, "viewing a term consumes no gameplay randomness")
		await mouse.click(tree, card, Vector2(146, 315))
		await tree.create_timer(0.15).timeout
		test.assert_equal(app.session.selected[str(200000 + term)], 1, "real card input acquires each new term once")
	var skill: Dictionary = app.battle_snapshot().heroes[0].skills[0]
	test.assert_equal(skill.total, 9000, "roster cooldown uses the upgraded skill instance")
	test.assert_equal(skill.description, app._catalog.record("options", 200100).description, "upgraded roster preserves the original shield wording without appended implementation details")
	await mouse.click(tree, view.get_node("HUD/Hero0/Skill"))
	test.assert_equal(tooltip.get_node("Paper/Description").text, skill.description, "live roster displays the upgraded description")
	await mouse.click(tree, tooltip.get_node("Paper"))
	await mouse.click(tree, view.get_node("HUD/Hero0/Portrait"))
	test.assert_equal(view.get_node("HeroTerms/Panel/Scroll/Rows").get_child_count(), 7, "selected terms contain all seven warrior upgrades and exclude the initial shield")
	test.assert_true(app.session.diagnostics.is_empty(), "new terms produce no runtime diagnostics")
	app.queue_free()
	await tree.process_frame
