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
	var tooltip = view.get_node("SkillTooltip")
	var mouse = Mouse.new()
	view.intent_requested.emit("start", {"seed": 17})
	await tree.create_timer(0.75).timeout
	await mouse.click(tree, panel.get_node("Cards/Card0"), Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	var w = app.session
	var owner = w.units[w.heroes[0]]
	w.upgrades.apply(owner, 2)
	test.assert_true(mixed(w), "real catalog provides a mixed deal")
	view.render(app.battle_snapshot())
	await tree.create_timer(0.75).timeout
	var before: Dictionary = app.battle_snapshot()
	var random_before: Dictionary = w.rng.snapshot()
	var upgrade_index = -1
	for i in range(before.offers.size()):
		var item: Dictionary = before.offers[i]
		var card = panel.get_node("Cards").get_child(i)
		var is_recruit: bool = item.kind == "hero"
		var definition = app._catalog.record("heroes", item.id if is_recruit else owner.template)
		var option = app._catalog.record("options", definition.initial_options[0] if is_recruit else item.id)
		test.assert_equal(card.hero_choice, is_recruit, "each card uses its own type within the mixed deal")
		test.assert_equal(card.get_node("Level").text, "招募" if is_recruit else "强化", "mixed card visibly identifies its action")
		test.assert_true(card.get_node("Description").visible, "both mixed card types directly display their descriptions")
		test.assert_true(not card.has_node("Skill"), "mixed cards have no central skill icons")
		test.assert_equal(card.get_node("Traits").visible, is_recruit, "recruitment retains race and profession text")
		test.assert_equal(card.get_node("TermName").text, option.title, "mixed card title names its displayed option")
		test.assert_equal(card.get_node("Description/Text").text, "招募%s" % definition.name if is_recruit else option.description, "mixed card uses recruitment text or the original upgrade description")
		await mouse.click(tree, card.get_node("Info"))
		test.assert_true(details.get_node("Hero").visible and not tooltip.visible, "mixed info opens attributes and dismisses the bubble")
		test.assert_equal(details.hero.template, definition.id, "mixed info uses the correct candidate or owner")
		if is_recruit:
			test.assert_equal(details.hero.attributes, definition.base, "recruit info shows the unowned hero baseline")
			test.assert_equal(details.hero.upgrades, definition.initial_options, "recruit info shows the initial skill")
		else:
			upgrade_index = i
			test.assert_equal(details.hero.id, owner.id, "upgrade info resolves the owned runtime hero")
			test.assert_equal(details.hero.attributes, before.heroes[0].attributes, "upgrade info shows modified current attributes")
			test.assert_equal(details.hero.upgrades, before.heroes[0].upgrades, "upgrade inspection does not pre-learn the candidate")
		await mouse.click(tree, details.get_node("Hero/Close"), Vector2(480, 1460))
	test.assert_equal(w.rng.snapshot(), random_before, "mixed inspection consumes no gameplay RNG")
	test.assert_equal(app.battle_snapshot().history, before.history, "mixed inspection commits no choice")
	test.assert_equal(app.battle_snapshot().offers, before.offers, "mixed inspection preserves the deal")
	var option_id: int = before.offers[upgrade_index].id
	var selected_before: int = w.selected.get(str(option_id), 0)
	await mouse.click(tree, panel.get_node("Cards").get_child(upgrade_index), Vector2(146, 405))
	await tree.create_timer(0.2).timeout
	test.assert_equal(w.heroes.size(), 1, "upgrade click in a mixed deal does not recruit")
	test.assert_equal(w.selected[str(option_id)], selected_before + 1, "upgrade click applies the displayed option exactly once")
	test.assert_equal(w.history.back().kind, "upgrade", "mixed upgrade history records the actual type")
	test.assert_true(mixed(w), "another eligible mixed deal is available")
	view.render(app.battle_snapshot())
	await tree.create_timer(0.75).timeout
	var recruit_index = -1
	for i in range(w.offers.size()):
		if w.offers[i].kind == "hero" and w.offers[i].id != 6:
			recruit_index = i
			break
	var hero_id: int = w.offers[recruit_index].id
	var balance_before: Dictionary = w.choices.hero_weights.duplicate()
	await mouse.click(tree, panel.get_node("Cards").get_child(recruit_index), Vector2(146, 315))
	await mouse.click(tree, panel.get_node("Cards").get_child(recruit_index), Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	test.assert_equal(w.heroes.size(), 2, "mixed recruit double-click adds exactly one hero")
	test.assert_equal(w.units[w.heroes.back()].template, hero_id, "mixed recruit click adds the displayed hero")
	test.assert_equal(w.history.back().kind, "hero", "mixed recruitment history records the actual type")
	test.assert_equal(w.choices.hero_weights, balance_before, "recruit confirmation does not apply upgrade balancing")
	test.assert_true(mixed(w), "mixed refresh has eligible cards to redraw")
	w.refresh_left = 1
	view.render(app.battle_snapshot())
	await tree.create_timer(0.75).timeout
	var history_before: Array = w.history.duplicate(true)
	var recruits_before: Array = w.offers.filter(func(item): return item.kind == "hero").map(func(item): return item.id)
	await mouse.click(tree, panel.get_node("Refresh"))
	await tree.create_timer(0.75).timeout
	test.assert_equal(w.refresh_left, 0, "real mixed refresh consumes the allowance once")
	test.assert_equal(w.history, history_before, "mixed refresh mouse input applies no card")
	test.assert_equal(w.heroes.size(), 2, "mixed refresh mouse input preserves the roster")
	var remaining = app._catalog.available_heroes().filter(func(id): return not recruits_before.has(id) and not w.heroes.any(func(uid): return w.units[uid].template == id))
	if remaining.size() >= 3:
		test.assert_true(w.offers.all(func(item): return item.kind != "hero" or not recruits_before.has(item.id)), "mixed refresh respects previous recruitment exclusions when enough remain")
	var refreshed: Array = w.offers.duplicate(true)
	await mouse.click(tree, panel.get_node("Refresh"))
	test.assert_equal(w.offers, refreshed, "disabled mixed refresh cannot redraw again")
	app.queue_free()
	await tree.process_frame
	await tree.process_frame

func mixed(w) -> bool:
	for i in range(100):
		w.choices.offer("upgrade")
		if w.offers.any(func(item): return item.kind == "hero" and item.id != 6) and w.offers.any(func(item): return item.kind == "upgrade"):
			return true
	return false
