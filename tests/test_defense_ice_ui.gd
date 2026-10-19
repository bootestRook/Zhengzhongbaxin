extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
const Offers = preload("res://tests/test_defense_fire_ui.gd")

func run(test: TestSupport, tree: SceneTree, capture: bool = false) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ChoicePanel")
	var mouse = Mouse.new()
	var index = -1
	for seed in range(20):
		if seed > 0:
			app.submit("quit")
		view.intent_requested.emit("start", {"seed": seed})
		index = app.session.offers.map(func(item): return item.id).find(13)
		if index >= 0:
			break
	assert(index >= 0)
	await tree.create_timer(0.75).timeout
	var card = panel.get_node("Cards").get_child(index)
	test.assert_equal(card.get_node("TermName").text, "多重射击", "recruitment advertises the automatic starting skill")
	test.assert_equal(card.get_node("Description/Text").text, "招募寒冰射手", "recruitment only names the ice archer")
	if capture:
		await sizes(tree, "recruit")
	await mouse.click(tree, card, Vector2(146, 315))
	await tree.create_timer(0.15).timeout
	test.assert_equal(app.session.units[app.session.heroes[0]].upgrades, [200400], "real recruitment input grants term 400 exactly once")
	for term in [401, 401, 402, 403, 404, 405, 406, 407, 408, 409]:
		index = Offers.new().term_offer(app.session, 200000 + term)
		view.render(app.battle_snapshot())
		await tree.create_timer(0.72).timeout
		card = panel.get_node("Cards").get_child(index)
		var before: Dictionary = app.session.selected.duplicate()
		var rng: Dictionary = app.session.rng.snapshot()
		test.assert_equal(card.get_node("Description/Text").text, app._catalog.record("options", 200000 + term).description, "ice term card displays actual configured rule")
		await mouse.click(tree, card.get_node("Info"))
		test.assert_equal(app.session.selected, before, "inspection cannot apply a candidate ice term")
		test.assert_equal(app.session.rng.snapshot(), rng, "ice attribute inspection cannot consume randomness")
		await mouse.click(tree, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1460))
		if capture and term == 408:
			await sizes(tree, "rain_offer")
		if term == 408:
			var description = card.get_node("Description")
			for i in range(10):
				var wheel = InputEventMouseButton.new()
				wheel.position = description.get_global_transform_with_canvas() * (description.size / 2)
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				tree.root.push_input(wheel, true)
				await tree.process_frame
			var scroll_bar = description.get_v_scroll_bar()
			if scroll_bar.max_value > scroll_bar.page:
				test.assert_true(description.scroll_vertical > 0, "actual mouse wheel reveals the rest of the long rain rule")
			else:
				test.assert_true(description.get_node("Text").get_minimum_size().y <= description.size.y, "rain rule is fully readable when it fits without scrolling")
			print("[ICE DESCRIPTION] text_height=%s viewport_height=%s scroll_max=%s page=%s" % [description.get_node("Text").get_minimum_size().y, description.size.y, scroll_bar.max_value, scroll_bar.page])
			test.assert_equal(app.session.selected, before, "scrolling a term cannot accidentally select it")
			if capture:
				await sizes(tree, "rain_offer_scrolled")
		await mouse.click(tree, card, Vector2(146, 315))
		await tree.create_timer(0.2).timeout
		test.assert_equal(app.session.selected.get(str(200000 + term), 0), 2 if term == 401 and before.get("200401", 0) == 1 else 1, "real input applies each permitted term count")
	var skill: Dictionary = app.battle_snapshot().heroes[0].skills[0]
	test.assert_equal(skill.title, "星辰之箭", "live hero skill name upgrades")
	test.assert_equal(skill.res, app._catalog.record("options", 200409).icon_res, "live star arrow icon upgrades")
	test.assert_equal(skill.level, 11, "live skill level counts automatic and repeated terms")
	await mouse.click(tree, view.get_node("HUD/Hero0/Skill"))
	test.assert_equal(view.get_node("SkillTooltip/Paper/Description").text, skill.description, "live tooltip reads the real upgraded skill snapshot")
	if capture:
		await sizes(tree, "star_description")
	await mouse.click(tree, view.get_node("HUD/Hero0/Skill"))
	if capture:
		var hero: Dictionary = app.session.units[app.session.heroes[0]]
		var fixture = preload("res://tests/test_defense_hero_skill_contracts.gd").new()
		for i in range(4):
			fixture.enemy(app.session, hero.pos + Vector2(-140 + i * 90, -280))
		app.session.skills.cast(hero, hero.skills[20002].data, {})
		app.session.skills.ice.rain(hero, hero.skills[20002].data, hero.pos + Vector2(0, -280))
		for at in range(app.session.time_ms, app.session.time_ms + 200, 16):
			app.session.time_ms = at
			app.session.projectiles.tick()
		view.render(app.battle_snapshot())
		await sizes(tree, "battle_effects")
	test.assert_true(app.session.diagnostics.is_empty(), "ice library has no missing runtime definitions")
	app.queue_free()
	await tree.process_frame
	await tree.process_frame

func sizes(tree: SceneTree, label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await tree.create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		assert(tree.root.get_texture().get_image().save_png("res://validation/defense/ice_terms/skill_scope/%s_%d.png" % [label, width]) == OK)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await tree.create_timer(0.08).timeout
