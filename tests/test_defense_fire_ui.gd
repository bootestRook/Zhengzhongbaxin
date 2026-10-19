extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func term_offer(w, term: int) -> int:
	var owner: int = w.heroes[0]
	assert(w.choices.eligible(w.catalog.record("options", term), w.units[owner]))
	w.pending = [owner]
	for i in range(60):
		w.choices.offer("bonus")
		for index in range(w.offers.size()):
			if w.offers[index].id == term:
				return index
	assert(false, "eligible fire term must appear in the bonus fixture")
	return 0

func run(test: TestSupport, tree: SceneTree, capture: bool = false) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ChoicePanel")
	var mouse = Mouse.new()
	view.intent_requested.emit("start", {"seed": 3})
	await tree.create_timer(0.75).timeout
	var index: int = app.session.offers.map(func(item): return item.id).find(1)
	var card = panel.get_node("Cards").get_child(index)
	test.assert_equal(card.get_node("Description/Text").text, "招募火焰术士", "recruitment only names the fire mage")
	if capture:
		await sizes(tree, "recruit")
	await mouse.click(tree, card, Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	test.assert_equal(app.battle_snapshot().heroes[0].upgrades, [200], "real recruitment grants only fireball")
	for term in [201, 202, 203, 204, 205, 206, 207, 208, 209, 210]:
		index = term_offer(app.session, term)
		view.render(app.battle_snapshot())
		await tree.create_timer(0.75).timeout
		card = panel.get_node("Cards").get_child(index)
		var before: Dictionary = app.session.selected.duplicate()
		var rng: Dictionary = app.session.rng.snapshot()
		test.assert_true(not card.has_node("Skill"), "fire upgrade displays text directly without redundant skill circle")
		test.assert_equal(card.get_node("Description/Text").text, app._catalog.record("options", term).description, "fire upgrade card preserves original text")
		await mouse.click(tree, card.get_node("Info"))
		test.assert_equal(app.session.selected, before, "viewing attributes cannot acquire a term")
		test.assert_equal(app.session.rng.snapshot(), rng, "inspecting fire terms consumes no random draws")
		await mouse.click(tree, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1460))
		if capture:
			await sizes(tree, "term_%d" % term)
		await mouse.click(tree, card, Vector2(146, 315))
		await tree.create_timer(0.15).timeout
		test.assert_equal(app.session.selected[str(term)], 1, "real card input selects each legal fire term once")
	var skill: Dictionary = app.battle_snapshot().heroes[0].skills[0]
	test.assert_equal(skill.level, 11, "all retained fire terms contribute to actual skill level")
	test.assert_equal(skill.title, "炎爆术", "learned pyroblast updates the live skill label")
	test.assert_equal(skill.res, app._catalog.record("options", 210).icon_res, "learned pyroblast updates its live icon")
	test.assert_true(app.session.diagnostics.is_empty(), "new fire library produces no missing definitions")
	await mouse.click(tree, view.get_node("HUD/Hero0/Skill"))
	test.assert_equal(view.get_node("SkillTooltip/Paper/Description").text, app._catalog.record("options", 210).description, "live pyroblast bubble preserves original term copy")
	if capture:
		await sizes(tree, "pyroblast_description")
	app.queue_free()
	await tree.process_frame

func sizes(tree: SceneTree, label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await tree.create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		assert(tree.root.get_texture().get_image().save_png("res://validation/defense/fire_terms/%s_%d.png" % [label, width]) == OK)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await tree.create_timer(0.08).timeout
