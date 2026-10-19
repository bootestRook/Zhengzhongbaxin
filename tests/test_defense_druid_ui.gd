extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
const Flow = preload("res://tests/test_defense_druid_terms.gd")

func term_offer(w, term: int) -> int:
	w.pending = [w.heroes[0]]
	for i in range(80):
		w.choices.offer("bonus")
		for index in range(w.offers.size()):
			if w.offers[index].id == 200000 + term:
				return index
	assert(false, "legal druid term must appear")
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
		index = app.session.offers.map(func(item): return item.id).find(2)
		if index >= 0:
			break
		app.session.phase = "home"
	await tree.create_timer(0.75).timeout
	var card = panel.get_node("Cards").get_child(index)
	test.assert_equal(card.get_node("Description/Text").text, "招募德鲁伊", "recruitment only names the druid")
	test.assert_true(not card.get_node("Description/Text").text.contains("攻击力"), "recruitment hides internal attack coefficients")
	if capture:
		await sizes(tree, "recruit")
	await mouse.click(tree, card, Vector2(146, 315))
	await tree.create_timer(0.15).timeout
	test.assert_equal(app.session.units[app.session.heroes[0]].upgrades, [200301], "real click recruits druid with only thorn armor")
	for term in Flow.TERMS:
		index = term_offer(app.session, term)
		view.render(app.battle_snapshot())
		await tree.create_timer(0.75).timeout
		card = panel.get_node("Cards").get_child(index)
		test.assert_equal(card.get_node("TermName").text, app._catalog.record("options", 200000 + term).title, "upgrade title matches source")
		test.assert_equal(card.get_node("Description/Text").text, app._catalog.record("options", 200000 + term).description, "upgrade displays exact approved public copy")
		var before: Dictionary = app.session.selected.duplicate()
		var rng: Dictionary = app.session.rng.snapshot()
		await mouse.click(tree, card.get_node("Info"))
		test.assert_equal(app.session.selected, before, "inspecting term does not acquire it")
		test.assert_equal(app.session.rng.snapshot(), rng, "inspecting term consumes no random draws")
		await mouse.click(tree, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1460))
		if capture and term in [303, 307, 312]:
			await sizes(tree, "term_%d" % term)
		await mouse.click(tree, card, Vector2(146, 315))
		await tree.create_timer(0.15).timeout
	test.assert_equal(app.session.selected["200302"], 2, "real input obtains two evergreen ranks")
	test.assert_equal(app.battle_snapshot().heroes[0].skills[0].level, 10, "live skill counts nine upgrades plus initial skill")
	await mouse.click(tree, view.get_node("HUD/Hero0/Skill"))
	test.assert_equal(view.get_node("SkillTooltip/Paper/Description").text, app._catalog.record("options", 200301).description, "battle skill tooltip uses same public copy")
	await mouse.click(tree, view.get_node("SkillTooltip/Paper"))
	var flow = Flow.new()
	var target = flow.ally(app.session)
	var second = flow.ally(app.session, 13)
	var owner: Dictionary = app.session.units[app.session.heroes[0]]
	owner.pos = Vector2(700, 1100)
	target.pos = Vector2(850, 900)
	second.pos = Vector2(600, 850)
	flow.cast(app.session)
	flow.enemy(app.session, target.pos + Vector2(65, -150))
	app.session.time_ms = 5000
	app.session.skills.thorns.tick()
	view.render(app.battle_snapshot())
	if capture:
		await sizes(tree, "flowers")
	# Use a fresh legal chest term fixture; all terms in this run are exhausted.
	app.session.start(53)
	app.session.factory.add_hero(2)
	app.session.phase = "playing"
	app.session.choices.options = {"200303": app._catalog.record("options", 200303)}
	app.session.loot.enqueue("elite")
	app.session.loot.advance()
	view.render(app.battle_snapshot())
	await tree.create_timer(0.15).timeout
	var reward_panel = view.get_node("RewardPanel")
	test.assert_equal(reward_panel.get_node("Results/Rows").get_child(0).get_node("Content/Text/Description").text, app._catalog.record("options", 200303).description, "automatic reward retains the original hero term copy")
	await mouse.click(tree, reward_panel, Vector2(480, 1720))
	await mouse.click(tree, reward_panel, Vector2(480, 1720))
	test.assert_equal(app.session.selected.get("200303", 0), 1, "automatic reward applies the actual hero term once")
	app.queue_free()
	await tree.process_frame

func sizes(tree: SceneTree, label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await tree.create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		assert(tree.root.get_texture().get_image().save_png("res://validation/defense/druid_terms/%s_%d.png" % [label, width]) == OK)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await tree.create_timer(0.08).timeout
