extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test: TestSupport, tree: SceneTree) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	app.session.start(23)
	for id in [4, 1, 10, 9, 13]:
		app.session.factory.add_hero(id)
	app.session.phase = "playing"
	var view = app.get_node("DefenseView")
	view.render(app.battle_snapshot())
	var mouse = Mouse.new()
	for i in range(5):
		var slot = view.get_node("HUD/Hero%d" % i)
		test.assert_equal(slot.hero.template, [4, 1, 10, 9, 13][i], "all five roster slots map to their real hero")
		test.assert_true(slot.position.x >= 0 and slot.position.x + slot.size.x <= 960, "five slot layout stays inside the logical canvas")
		await mouse.click(tree, slot.get_node("Portrait"))
		test.assert_true(view.get_node("HeroTerms").visible, "each of five portraits opens selected terms")
		test.assert_equal(view.get_node("HeroTerms").selected_hero_id, slot.hero.id, "term inspection uses the matching hero")
		await mouse.click(tree, slot.get_node("Portrait"))
		await mouse.click(tree, slot.get_node("Skill"))
		test.assert_true(view.get_node("SkillTooltip").visible, "each of five skill circles opens its description")
		await mouse.click(tree, slot.get_node("Skill"))
		test.assert_true(not view.get_node("SkillTooltip").visible, "same skill circle closes the description")
	var hero: Dictionary = app.session.units[app.session.heroes[4]]
	app.session.damage.defeat(hero, {})
	view.render(app.battle_snapshot())
	test.assert_equal(view.get_node("HUD/Hero4/Revive").text, "10", "fifth slot immediately displays the profession countdown")
	await mouse.click(tree, view.get_node("HUD/BattleStats"))
	test.assert_equal(view.get_node("BattlePanels/Contribution/Rows").get_child_count(), 5, "contribution panel includes all five heroes")
	await mouse.click(tree, view.get_node("HUD/BattleStats"))
	app.session.stage = 19
	app.session.spawn_wave = 20
	view.render(app.battle_snapshot())
	test.assert_equal(view.get_node("HUD/RunLevel").text, "20", "HUD exposes level twenty")
	test.assert_equal(view.get_node("HUD/Wave").text, "第20／20波", "HUD exposes the twenty wave ceiling in Chinese")
	app.session.finish(false)
	view.render(app.battle_snapshot())
	var panel = view.get_node("ResultPanel")
	test.assert_equal(panel.get_node("Heroes").get_child_count(), 5, "result shows five real heroes")
	test.assert_true(not panel.has_node("Statues"), "result removes the obsolete statue-upgrade holder")
	await tree.create_timer(1.8).timeout
	for card in panel.get_node("Heroes").get_children():
		test.assert_true(card.position.x >= 0 and card.position.x + card.size.x <= 960, "result card does not overflow with five heroes")
		await mouse.click(tree, card.get_node("Info"))
		test.assert_equal(view.get_node("BattlePanels").hero.template, card.hero.template, "all five result info buttons inspect the matching hero")
		await mouse.click(tree, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1200))
	app.queue_free()
	await tree.process_frame
