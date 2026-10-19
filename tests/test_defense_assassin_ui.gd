extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
const Flow = preload("res://tests/test_defense_assassin_terms.gd")

func term_offer(w, term: int) -> int:
	w.pending = [w.heroes[0]]
	for i in range(100):
		w.choices.offer("bonus")
		for index in range(w.offers.size()):
			if w.offers[index].id == 200000 + term:
				return index
	assert(false, "legal assassin term must appear")
	return 0

func run(test: TestSupport, tree: SceneTree, capture: bool = false) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ChoicePanel")
	var mouse = Mouse.new()
	var index = -1
	for seed_value in range(1, 20):
		view.intent_requested.emit("start", {"seed": seed_value})
		index = app.session.offers.map(func(item): return item.id).find(17)
		if index >= 0:
			break
		app.session.phase = "home"
	await tree.create_timer(0.75).timeout
	var card = panel.get_node("Cards").get_child(index)
	test.assert_equal(card.get_node("Description/Text").text, "招募闪电刺客", "recruitment only names the lightning assassin")
	if capture:
		await sizes(tree, "recruit")
	await mouse.click(tree, card, Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	test.assert_equal(app.session.units[app.session.heroes[0]].upgrades, [200500], "real click grants only recruitment term")
	for term in Flow.TERMS:
		var previous_count = int(app.session.selected.get(str(200000 + term), 0))
		index = term_offer(app.session, term)
		view.render(app.battle_snapshot())
		await tree.create_timer(0.75).timeout
		card = panel.get_node("Cards").get_child(index)
		test.assert_equal(card.get_node("TermName").text, app._catalog.record("options", 200000 + term).title, "upgrade title uses unified library")
		test.assert_equal(card.get_node("Description/Text").text, app._catalog.record("options", 200000 + term).description, "upgrade body uses exact current definition")
		if capture and term in [504, 508]:
			await sizes(tree, "term_%d" % term)
		await mouse.click(tree, card, Vector2(146, 315))
		await tree.create_timer(0.2).timeout
		test.assert_equal(app.session.selected.get(str(200000 + term), 0), previous_count + 1, "real click commits before next candidates replace the card")
	test.assert_equal(app.session.selected.get("200501", 0), 2, "real input grants both damage ranks")
	test.assert_equal(app.session.units[app.session.heroes[0]].skills[1435].data.assassination.damage_percent, 460.0, "real UI choice changes actual skill instance")
	await mouse.click(tree, view.get_node("HUD/Hero0/Skill"))
	test.assert_equal(view.get_node("SkillTooltip/Paper/Description").text, app._catalog.record("options", 200500).description, "battle tooltip uses current base definition")
	await mouse.click(tree, view.get_node("SkillTooltip/Paper"))
	var flow = Flow.new()
	var owner: Dictionary = app.session.units[app.session.heroes[0]]
	flow.normalize(owner)
	owner.pos = Vector2(700, 1000)
	flow.enemy(app.session, owner.pos + Vector2(20, -100))
	flow.enemy(app.session, owner.pos + Vector2(120, -100))
	flow.cast(app.session)
	view.render(app.battle_snapshot())
	if capture:
		await sizes(tree, "battle")
	app.session.start(53)
	app.session.factory.add_hero(17)
	app.session.phase = "playing"
	app.session.choices.options = {"200504": app._catalog.record("options", 200504)}
	app.session.loot.enqueue("elite")
	app.session.loot.advance()
	view.render(app.battle_snapshot())
	await tree.create_timer(0.15).timeout
	var reward_panel = view.get_node("RewardPanel")
	test.assert_equal(reward_panel.get_node("Results/Rows").get_child(0).get_node("Content/Text/Description").text, app._catalog.record("options", 200504).description, "automatic reward retains the original hero term copy")
	await mouse.click(tree, reward_panel, Vector2(480, 1720))
	await mouse.click(tree, reward_panel, Vector2(480, 1720))
	test.assert_equal(app.session.selected.get("200504", 0), 1, "automatic reward applies the actual hero term once")
	test.assert_true(app.session.units[app.session.heroes[0]].skills[1435].data.assassination.smoke, "chest reward changes real battle capability")
	app.queue_free()
	await tree.process_frame

func sizes(tree: SceneTree, label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await tree.create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		assert(tree.root.get_texture().get_image().save_png("res://validation/defense/assassin_terms/%s_%d.png" % [label, width]) == OK)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await tree.create_timer(0.08).timeout
