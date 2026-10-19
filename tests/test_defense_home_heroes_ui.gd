extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
const SHARED = ["Avatar", "PlayerName", "PlayerId", "PlayerLevel", "ExperienceText", "ResourceValue0", "ResourceValue1", "ResourceValue2"]

func run(test: TestSupport, tree: SceneTree, capture: bool = false) -> void:
	var original_size := tree.root.size
	for width: int in [720, 540]:
		tree.root.size = Vector2i(width, width * 2)
		var app = load("res://scenes/main.tscn").instantiate()
		tree.root.add_child(app)
		await tree.process_frame
		await tree.process_frame
		var home = app.get_node("DefenseView/Home")
		var page = home.get_node("HeroPage")
		var actor = page.get_node("Actor")
		var scroll = page.get_node("Scroll")
		var snapshot: Dictionary = app.battle_snapshot().duplicate(true)
		var rng: Dictionary = app.session.rng.snapshot()
		var shell: Dictionary = {}
		for name: String in SHARED:
			var node = home.get_node(name)
			shell[name] = [node.get_global_rect(), node.text if node is Label else node.texture]
		await Mouse.new().click(tree, home.get_node("Heroes"))
		test.assert_equal(home.current_page, "heroes", "hero tab switches the middle at %d" % width)
		test.assert_true(page.visible and not home.get_node("BattlePage").visible, "only hero content is visible")
		for name: String in SHARED:
			var node = home.get_node(name)
			test.assert_true(node.is_visible_in_tree(), "shared header stays visible: " + name)
			test.assert_equal([node.get_global_rect(), node.text if node is Label else node.texture], shell[name], "shared header stays identical: " + name)
		test.assert_equal(page.cards.size(), 18, "all eighteen heroes appear")
		for id in page.cards:
			var card = page.cards[id]
			var hero: Dictionary = app._catalog.record("heroes", id)
			test.assert_equal(card.unlocked, app._catalog.available_heroes().has(id), "card lock uses current roster")
			test.assert_equal(card.get_node("Level").text, "Lv:1", "every hero starts at level one")
			test.assert_equal(card.get_node("FragmentCount").text, "0/14", "initial fragment display")
			test.assert_equal(card.get_node("Race").text, hero.tags[0].title, "race comes from hero definition")
			test.assert_equal(card.get_node("Profession").resource_key, hero.tags[1].res, "profession comes from hero definition")
			test.assert_equal(card.get_node("Portrait").material.get_shader_parameter("locked"), not card.unlocked, "locked portraits are gray")
		for id in app._catalog.available_heroes():
			await Mouse.new().click(tree, page.cards[id])
			test.assert_equal(page.selected_hero_id, id, "real card click selects hero %d" % id)
			test.assert_equal(actor.resource_key, app._catalog.record("heroes", id).res, "actor follows selected hero")
			test.assert_equal(actor.action, "idle", "switching hero restarts idle interval")
			test.assert_true(page.cards[id].get_node("Selected").visible, "selected card shows yellow border")
			await Mouse.new().click(tree, home.get_node("HeroDetails"), Vector2(20, 1300))
		await Mouse.new().click(tree, page.cards[3])
		test.assert_equal(page.selected_hero_id, 17, "locked card does not change selection")
		test.assert_true(page.get_node("Notice").visible, "locked card produces notice")
		test.assert_equal(page.get_node("Notice/Text").text, "还未解锁", "locked feedback text")
		if capture:
			await screenshot(tree, "locked_%d" % width)
		await Mouse.new().click(tree, page.cards[1])
		await Mouse.new().click(tree, home.get_node("HeroDetails"), Vector2(20, 1300))
		if capture:
			await screenshot(tree, "heroes_%d" % width)
		if width == 720:
			var actions: Array[String] = [actor.action]
			var start := Time.get_ticks_msec()
			while Time.get_ticks_msec() - start < 6800:
				await tree.process_frame
				if actions.back() != actor.action:
					actions.append(actor.action)
				if actions.size() >= 5:
					break
			test.assert_equal(actions, ["idle", "attack", "idle", "skill", "idle"], "live frames play idle, attack, idle, skill, idle automatically")
		# Real wheel input exercises the scroll container independently of card presses.
		var point: Vector2 = scroll.get_global_transform_with_canvas() * (scroll.size / 2)
		for i in range(20):
			var wheel := InputEventMouseButton.new()
			wheel.position = point
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			tree.root.push_input(wheel, true)
			wheel = wheel.duplicate()
			wheel.pressed = false
			tree.root.push_input(wheel, true)
			await tree.process_frame
		test.assert_true(scroll.scroll_vertical > 0, "real wheel scrolls the hero roster")
		test.assert_equal(page.selected_hero_id, 1, "scrolling cannot change selection")
		scroll.ensure_control_visible(page.cards[18])
		await tree.process_frame
		test.assert_true(page.cards[18].get_global_rect().end.y < home.get_node("Heroes/Icon").get_global_rect().position.y,
			"last complete card scrolls above the raised active navigation")
		await Mouse.new().click(tree, page.cards[18])
		test.assert_equal(page.selected_hero_id, 1, "last locked hero remains nonselectable")
		test.assert_true(page.get_node("Notice").visible, "last card remains reachable")
		if capture:
			await screenshot(tree, "roster_bottom_%d" % width)
		await Mouse.new().click(tree, home.get_node("Battle"))
		test.assert_equal(home.current_page, "battle", "battle tab returns to stage home")
		test.assert_true(not app.get_node("DefenseView/LevelPanel").visible, "tab return does not open an overlay")
		var elapsed: float = actor.elapsed_ms
		await tree.create_timer(0.1).timeout
		test.assert_equal(actor.elapsed_ms, elapsed, "hidden actor stops processing")
		test.assert_equal(app.battle_snapshot(), snapshot, "browsing leaves gameplay state unchanged")
		test.assert_equal(app.session.rng.snapshot(), rng, "browsing consumes no gameplay random stream")
		if capture:
			await screenshot(tree, "battle_home_%d" % width)
		await Mouse.new().click(tree, home.get_node("Heroes"))
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		tree.root.push_input(escape, true)
		await tree.process_frame
		test.assert_equal(home.current_page, "battle", "Escape returns hero page to battle home")
		await Mouse.new().click(tree, home.get_node("BattlePage/LevelSelect"))
		test.assert_true(app.get_node("DefenseView/LevelPanel").visible, "level title still opens stage selection")
		await Mouse.new().click(tree, app.get_node("DefenseView/LevelPanel/LevelClose"))
		await Mouse.new().click(tree, home.get_node("BattlePage/Start"))
		test.assert_equal(app.battle_snapshot().phase, "choice", "returning from heroes still starts a real run")
		await tree.create_timer(0.7).timeout
		await Mouse.new().click(tree, app.get_node("DefenseView/ChoicePanel/Cards/Card0"), Vector2(146, 315))
		await tree.create_timer(0.2).timeout
		test.assert_equal(app.battle_snapshot().heroes.size(), 1, "real choice input recruits after browsing heroes")
		app.queue_free()
		await tree.process_frame
	tree.root.size = original_size

func screenshot(tree: SceneTree, name: String) -> void:
	await tree.process_frame
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png("res://.impeccable/review/hero_page/" + name + ".png")
