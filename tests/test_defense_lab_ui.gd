extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test, tree: SceneTree, capture: bool) -> void:
	var app = load("res://scenes/defense_lab.tscn").instantiate()
	tree.root.add_child(app)
	await tree.create_timer(0.4).timeout
	test.assert_equal(app.boot_error, "", "laboratory mounts actual battle scene")
	test.assert_true(app.game.get_node("DefenseView/Field") != null, "original field is present")
	var mouse = self
	var ticks: int = app.lab.world.time_ms
	await mouse.click(tree, app.get_node("%Step"))
	test.assert_equal(app.lab.world.time_ms, ticks + 16, "real step button advances shared controller")
	await mouse.click(tree, app.get_node("%ClearAll"))
	test.assert_equal(app.lab.world.units.size(), 0, "real clear button clears authoritative units")
	app.get_node("%PosX").value = 800
	app.get_node("%PosY").value = 1100
	await mouse.click(tree, app.get_node("%AddHero"))
	print("[LAB UI] hero choice=", app.get_node("%HeroChoice").get_selected_id(), " notice=", app.get_node("%Notice").text, " rect=", app.get_node("%AddHero").get_global_rect())
	test.assert_equal(app.lab.world.heroes.size(), 1, "real summon button creates hero")
	if app.lab.world.heroes.is_empty():
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("res://validation/battle_lab/ui_failure.png")
		app.queue_free()
		await tree.process_frame
		return
	app.get_node("%PosY").value = 750
	app.get_node("%SpawnSurvival").select(1)
	app.get_node("%Count").value = 3
	app.get_node("%Layout").select(1)
	await mouse.click(tree, app.get_node("%AddMonster"))
	test.assert_equal(app.lab.world.units.size(), 4, "real monster button applies batch count")
	test.assert_equal(app.lab.inspect().survival, "immortal", "spawn survival selection reaches real state")
	app.get_node("%Tabs").current_tab = 2
	await tree.process_frame
	app.get_node("%AttributeChoice").select(0)
	app.get_node("%AttributeValue").value = 5000
	await mouse.click(tree, app.get_node("%ApplyAttribute"))
	test.assert_equal(app.lab.inspect().max_hp, 5000.0, "attribute button updates real max HP")
	app.get_node("%HPPercent").value = 50
	await mouse.click(tree, app.get_node("%ApplyHP"))
	test.assert_equal(app.lab.inspect().hp, 2500.0, "HP UI reads back actual half health")
	# Native outer-viewport input must reach a unit inside the scaled battle viewport.
	var hero: Dictionary = app.lab.world.units[app.lab.world.heroes[0]]
	var point: Vector2 = hero.pos + Vector2(-320, -140)
	var outer: Vector2 = app.get_node("%ViewportContainer").get_global_transform_with_canvas() * point
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = outer
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		tree.root.push_input(event, true)
		await tree.process_frame
	test.assert_equal(app.lab.selected_id, hero.id, "native battle click selects the actual hero across viewport scaling")
	app.get_node("%Tabs").current_tab = 1
	app.panel.terms()
	await tree.process_frame
	var index = app.panel.term_ids.find(201)
	app.get_node("%Terms").select(index)
	await mouse.click(tree, app.get_node("%AddTerm"))
	test.assert_true(app.lab.inspect().terms.has(201), "real term button applies fire upgrade")
	index = app.panel.term_ids.find(201)
	app.get_node("%Terms").select(index)
	await mouse.click(tree, app.get_node("%RemoveTerm"))
	test.assert_true(not app.lab.inspect().terms.has(201), "real remove button rebuilds without term")
	var expected: Dictionary = app.lab.state()
	var replay_path = "res://validation/battle_lab/交互重放.json"
	app.file_mode = "replay_save"
	app.file_selected(replay_path)
	test.assert_true(FileAccess.file_exists(replay_path), "UI saves an actual replay file")
	app.dispatch("clear", {"scope": "all"})
	app.load_path(replay_path, true)
	test.assert_equal(app.lab.state(), expected, "UI file replay restores authoritative state")
	var config_path = "res://validation/battle_lab/交互配置.json"
	app.file_mode = "config_save"
	app.file_selected(config_path)
	app.dispatch("clear", {"scope": "all"})
	app.load_path(config_path, false)
	test.assert_equal(app.lab.world.units.size(), 4, "saved configuration rebuilds four actual units")
	test.assert_true(app.lab.world.paused, "loaded configuration is paused")
	app.get_node("%Geometry").button_pressed = true
	app.single_step(150)
	for dimensions in [Vector2i(1360, 1000), Vector2i(960, 720), Vector2i(720, 1080)]:
		tree.root.size = dimensions
		await tree.create_timer(0.25).timeout
		app.fit_battle()
		test.assert_true(app.get_node("%ToolPanel").get_global_rect().end.x <= tree.root.size.x + 1, "tools remain within window width")
		test.assert_true(app.get_node("%ViewportContainer").scale.x > 0, "battle keeps positive uniform scale")
		for tab in [0, 1, 2, 3, 4, 5]:
			app.get_node("%Tabs").current_tab = tab
			app.refresh()
			await tree.process_frame
			if capture:
				await RenderingServer.frame_post_draw
				var path = "res://validation/battle_lab/ui_%d_%d_tab%d.png" % [dimensions.x, dimensions.y, tab]
				test.assert_equal(tree.root.get_texture().get_image().save_png(path), OK, "capture " + path)
	app.queue_free()
	await tree.process_frame
	await tree.process_frame

func click(tree: SceneTree, control: Control) -> void:
	var parent = control.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await tree.process_frame
	await Mouse.new().click(tree, control)
