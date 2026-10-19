extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test: TestSupport, tree: SceneTree, capture: bool = false) -> void:
	var original_size := tree.root.size
	for width: int in [720, 540]:
		tree.root.size = Vector2i(width, width * 2)
		var app = load("res://scenes/main.tscn").instantiate()
		tree.root.add_child(app)
		await tree.process_frame
		await tree.process_frame
		tree.root.size = Vector2i(width, width * 2)
		await tree.process_frame
		await tree.process_frame
		var home = app.get_node("DefenseView/Home")
		var page = home.get_node("HeroPage")
		var detail = home.get_node("HeroDetails")
		var snapshot: Dictionary = app.battle_snapshot().duplicate(true)
		var rng: Dictionary = app.session.rng.snapshot()
		await Mouse.new().click(tree, home.get_node("Heroes"))
		await Mouse.new().click(tree, page.cards[1])
		test.assert_true(detail.visible, "unlocked card opens hero secondary screen at %d" % width)
		test.assert_true(not page.get_node("Actor").is_processing(), "covered page actor is paused")
		test.assert_true(detail.get_node("Panel/Upgrade").disabled, "upgrade stays disabled while effects and costs are unconfigured")
		if capture:
			await screenshot(test, tree, "detail_%d" % width, width)
		await Mouse.new().click(tree, detail.get_node("Panel/Main0/Hit"))
		test.assert_true(detail.get_node("AttributeTip").visible, "basic attribute icon opens its own explanation")
		test.assert_equal(detail.get_node("AttributeTip/Title").text, "生命", "basic attribute explanation has the correct title")
		test.assert_equal(detail.get_node("AttributeTip/Value").text, "600", "basic attribute explanation shows actual level-one value")
		if capture:
			await screenshot(test, tree, "attribute_hp_%d" % width, width)
		await Mouse.new().click(tree, detail.get_node("Panel/Title"))
		test.assert_true(not detail.get_node("AttributeTip").visible and detail.visible, "outside click closes the attribute explanation")
		await Mouse.new().click(tree, detail.get_node("Panel/Info"))
		test.assert_true(detail.get_node("Attributes").visible, "info button opens detailed attributes")
		if capture:
			await screenshot(test, tree, "attributes_%d" % width, width)
		await Mouse.new().click(tree, detail.get_node("Attributes/Extra0_0/Hit"))
		test.assert_true(detail.get_node("Attributes").visible and detail.get_node("AttributeTip").visible, "attribute explanation is layered over expanded attributes")
		test.assert_equal(detail.get_node("AttributeTip/Title").text, "生命恢复", "expanded attribute explanation has its own title")
		test.assert_true(detail.get_node("AttributeTip/Description").text.begins_with("每5秒"), "regeneration explanation follows current five-second runtime rule")
		if capture:
			await screenshot(test, tree, "attribute_regen_%d" % width, width)
		await Mouse.new().click(tree, detail.get_node("Panel/Title"))
		test.assert_true(not detail.get_node("AttributeTip").visible and detail.get_node("Attributes").visible, "outside click dismisses only the top explanation")
		await Mouse.new().click(tree, detail.get_node("Panel/Title"))
		test.assert_true(not detail.get_node("Attributes").visible and detail.visible, "outside click closes only the attribute panel")
		for id in app._catalog.available_heroes():
			detail.get_node("Roster").ensure_control_visible(detail.portraits[id])
			await tree.process_frame
			await Mouse.new().click(tree, detail.portraits[id])
			var hero: Dictionary = app._catalog.record("heroes", id)
			test.assert_equal(detail.selected_hero_id, id, "carousel selects the actual hero")
			test.assert_equal(page.selected_hero_id, id, "carousel selection is retained by the hero page")
			test.assert_equal(detail.get_node("Panel/Title").text, hero.name, "hero name follows selection")
			test.assert_equal(detail.get_node("Panel/Actor").resource_key, hero.res, "detail body follows selection")
			test.assert_equal(detail.get_node("Panel/Level").text, "LV.1", "detail starts at level one")
			for index in range(3):
				test.assert_equal(float(detail.get_node("Panel/Main%d/Value" % index).text), float(hero.base[str([1,4,10][index])]), "basic attributes come from this hero definition")
			test.assert_equal(detail.initial_options, hero.initial_options, "initial skill IDs are exact current hero options")
			test.assert_equal(detail.get_node("Panel/Skills").get_child_count(), hero.initial_options.size(), "only actual initial skills are shown")
			for option_id in hero.initial_options:
				var option: Dictionary = app._catalog.record("options", option_id)
				var skill: Dictionary = app._catalog.record("skills", int(option.get("trigger_skill", 0)))
				await Mouse.new().click(tree, detail.get_node("Panel/Skills/Skill%d" % option_id))
				test.assert_true(detail.get_node("SkillTip").visible, "initial skill click opens its tooltip")
				test.assert_equal(detail.get_node("SkillTip/Title").text, option.title, "skill title matches data")
				test.assert_equal(detail.get_node("SkillTip/Description").get_parsed_text(), detail.skill_description(option, skill), "skill description uses the complete skill definition")
				test.assert_true(detail.get_node("SkillTip/Description").bbcode_enabled, "skill description supports rich text")
				test.assert_true(detail.get_node("SkillTip/Description").text.contains("[color=#28712c][b]"), "skill numeric values use rich text emphasis")
				test.assert_true(not detail.get_node("SkillTip/Description").get_parsed_text().contains("基础冷却"), "cooldown is kept out of the skill description")
				test.assert_equal(detail.get_node("SkillTip/Cooldown/Value").get_parsed_text(), detail.cooldown_text(skill, hero), "skill cooldown is shown in the shared red field")
				test.assert_equal(detail.get_node("SkillTip/Cooldown").position.x + detail.get_node("SkillTip/Cooldown").size.x, 642.0, "cooldown box keeps its right edge aligned")
				test.assert_equal(detail.get_node("SkillTip/Title").offset_right + 16.0, detail.get_node("SkillTip/Cooldown").position.x, "skill title and cooldown keep a fixed gap")
				test.assert_equal(detail.get_node("SkillTip/Cooldown/Value").horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "cooldown text is right aligned")
				test.assert_equal(detail.get_node("SkillTip/Cooldown").position.y + detail.get_node("SkillTip/Cooldown").size.y / 2.0, 64.0, "cooldown box is vertically centered with the skill title")
				test.assert_equal(detail.get_node("SkillTip/Cooldown").get_class(), "Control", "cooldown display has no frame or panel")
				test.assert_equal(detail.get_node("SkillTip/Icon").resource_key, option.icon_res, "skill icon matches data")
				test.assert_true(detail.get_node("SkillTip/Description").get_minimum_size().y <= detail.get_node("SkillTip/Description").size.y, "complete description fits tooltip")
				if capture and id in [1, 2]:
					await screenshot(test, tree, "skill_%d_%d" % [id, width], width)
				await Mouse.new().click(tree, detail.get_node("SkillTip/Title"))
				test.assert_true(detail.get_node("SkillTip").visible, "click inside the tooltip leaves it open")
				await Mouse.new().click(tree, detail.portraits[id])
				test.assert_true(not detail.get_node("SkillTip").visible and detail.visible, "outside click dismisses only skill tooltip")
			await Mouse.new().click(tree, detail.get_node("Panel/Info"))
			for column in range(detail.EXTRA_ATTRIBUTES.size()):
				for row in range(detail.EXTRA_ATTRIBUTES[column].size()):
					var attribute_id: int = detail.EXTRA_ATTRIBUTES[column][row]
					test.assert_equal(float(detail.get_node("Attributes/Extra%d_%d/Value" % [column,row]).text), float(hero.base[str(attribute_id)]), "expanded attribute value belongs to selected hero")
			await escape(tree)
			test.assert_true(not detail.get_node("Attributes").visible and detail.visible, "Escape dismisses floating panel before detail")
		# A click used to dismiss a popup must not also select the hero underneath.
		detail.get_node("Roster").ensure_control_visible(detail.portraits[1])
		await tree.process_frame
		await Mouse.new().click(tree, detail.get_node("Panel/Info"))
		await Mouse.new().click(tree, detail.portraits[1])
		test.assert_equal(detail.selected_hero_id, 17, "outside dismissal does not click through to carousel")
		detail.get_node("Roster").ensure_control_visible(detail.portraits[18])
		await tree.process_frame
		await Mouse.new().click(tree, detail.portraits[18])
		test.assert_equal(detail.selected_hero_id, 17, "locked carousel portrait cannot be selected")
		test.assert_true(detail.get_node("Notice").visible, "locked carousel portrait gives feedback")
		await Mouse.new().click(tree, detail.get_node("Panel/Upgrade"))
		test.assert_equal(app.battle_snapshot(), snapshot, "disabled upgrade and browsing do not modify gameplay state")
		test.assert_equal(app.session.rng.snapshot(), rng, "details consume no gameplay random stream")
		detail.set_equipment({"sockets": {"gloves": ["gem_82_1"]}, "gem_defs": {"gem_82_1": 82}, "definitions": {"82": {"effect": {"attribute": "9", "value": 1}}}})
		test.assert_equal(detail.cooldown_text({"cd": 10000}, {"base": {"9": 0}}), "9.9秒（原冷却-0.1秒）", "equipped cooldown gem shows actual and saved cooldown")
		test.assert_equal(detail.cooldown_text({"cd": 10000}, {"base": {"9": 10}}), "8.9秒（原冷却-1.1秒）", "outside cooldown reduction is included in the actual value")
		detail.set_equipment({})
		await Mouse.new().click(tree, detail.get_node("Panel"), Vector2(400, 720))
		test.assert_true(detail.visible, "blank space inside the paper does not close details")
		await Mouse.new().click(tree, detail.get_node("RosterPaper"), Vector2(5, 5))
		test.assert_true(detail.visible, "carousel margin does not close details")
		await Mouse.new().click(tree, detail.get_node("Panel/Info"))
		await Mouse.new().click(tree, detail.get_node("Attributes/Extra0_0/Hit"))
		await Mouse.new().click(tree, detail, Vector2(20, 1300))
		test.assert_true(not detail.get_node("AttributeTip").visible and detail.get_node("Attributes").visible and detail.visible, "blank area dismisses only the top attribute explanation")
		await Mouse.new().click(tree, detail, Vector2(20, 1300))
		test.assert_true(not detail.get_node("Attributes").visible and detail.visible, "second blank click dismisses only the expanded attributes")
		await Mouse.new().click(tree, detail, Vector2(20, 1300))
		test.assert_true(not detail.visible and page.visible, "blank area returns to the hero page")
		test.assert_equal(page.selected_hero_id, 17, "blank dismissal preserves selected hero")
		test.assert_true(page.get_node("Actor").is_processing(), "page actor resumes after closing details")
		await Mouse.new().click(tree, page.cards[1])
		await Mouse.new().click(tree, detail.get_node("Panel/Skills").get_child(0))
		await Mouse.new().click(tree, detail, Vector2(20, 1300))
		test.assert_true(not detail.get_node("SkillTip").visible and detail.visible, "blank area dismisses only the skill explanation")
		await Mouse.new().click(tree, home.get_node("Battle"))
		test.assert_true(not detail.visible and home.current_page == "heroes", "outside dismissal consumes the click above bottom navigation")
		await Mouse.new().click(tree, page.cards[1])
		await escape(tree)
		test.assert_true(not detail.visible and home.current_page == "heroes", "Escape closes detail before navigating away")
		app.queue_free()
		await tree.process_frame
	tree.root.size = original_size

func escape(tree: SceneTree) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	tree.root.push_input(event, true)
	await tree.process_frame

func screenshot(test: TestSupport, tree: SceneTree, name: String, width: int) -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var capture_image := tree.root.get_texture().get_image()
	test.assert_equal(capture_image.get_size(), Vector2i(width, width * 2), "native screenshot has the requested physical dimensions")
	capture_image.save_png("res://.impeccable/review/hero_details/" + name + ".png")
