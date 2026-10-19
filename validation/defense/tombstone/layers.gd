extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
var test = preload("res://tests/test_support.gd").new()
var app
var view
var marker
var w
const COVERED_AREA := Rect2(420, 640, 120, 345)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	w = app.session
	view = app.get_node("DefenseView")
	marker = view.get_node("Field/TombstoneEffects")
	for width in [720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		w.start(53)
		w.phase = "playing"
		w.offers.clear()
		w.pending.clear()
		w.factory.add_hero(4)
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.pos = Vector2(800, 1057)
		w.damage.defeat(hero, {})
		for i in range(12):
			w.factory.create("enemy", 101, hero.pos + Vector2((i % 4) * 14 - 21, (i / 4) * 18 - 36), 2)
		w.time_ms = 5000
		w.factory.lifecycle()
		view.render(app.battle_snapshot())
		await create_timer(0.12).timeout
		await shot("layers_battle_%d" % width)
		test.assert_true(await marker_changes_pixels(), "grave, column and soul remain visible above crowded battlefield units")
		w.choices.offer("upgrade")
		view.render(app.battle_snapshot())
		await create_timer(0.75).timeout
		await shot("layers_choice_%d" % width)
		test.assert_true(not await marker_changes_pixels(), "choice card fully occludes the grave, column and soul beneath it")
		test.assert_equal(view.get_node("HUD/Hero0/Revive").text, "15", "choice preserves the bottom hero revival countdown")
		app._process(0.2)
		test.assert_equal(w.time_ms, 5000, "choosing still freezes the actual revival clock")
		await Mouse.new().click(self, view.get_node("ChoicePanel/Cards/Card0"), Vector2(146, 315))
		await create_timer(0.2).timeout
		test.assert_equal(w.phase, "playing", "a real card click still resumes battle")
		test.assert_true(await marker_changes_pixels(), "closing choices reveals the same waiting grave")
		w.time_ms = 19950
		view.render(app.battle_snapshot())
		w.time_ms = 20050
		w.factory.lifecycle()
		view.render(app.battle_snapshot())
		test.assert_true(marker.endings.has(hero.id), "actual revival starts the existing disappearance effect")
		w.choices.offer("upgrade")
		view.render(app.battle_snapshot())
		await create_timer(0.75).timeout
		await shot("layers_finish_choice_%d" % width)
		test.assert_true(not await marker_changes_pixels(), "choice card also occludes the disappearing grave and afterglow")
		app.submit("pause", {})
		test.assert_true(view.get_node("BattlePanels/Pause").visible, "pause panel remains available over the choice")
		await shot("layers_pause_%d" % width)
		app.submit("quit", {})
		test.assert_equal(w.phase, "result", "exit still reaches the result panel")
		await create_timer(1.0).timeout
		await shot("layers_result_%d" % width)
		app.submit("home", {})
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[TOMBSTONE LAYERS] assertions=", test.assertions, " failures=", test.failures.size())
	app.queue_free()
	await process_frame
	quit(0 if test.failures.is_empty() else 1)

func marker_changes_pixels() -> bool:
	var shown: Image = await capture()
	marker.hide()
	var hidden: Image = await capture()
	marker.show()
	var scale_value = shown.get_width() / 960.0
	var area = Rect2i(COVERED_AREA.position * scale_value, COVERED_AREA.size * scale_value)
	return shown.get_region(area).get_data() != hidden.get_region(area).get_data()

func capture() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func shot(label: String) -> void:
	var picture: Image = await capture()
	test.assert_equal(picture.save_png("res://validation/defense/tombstone/%s.png" % label), OK, "native layering capture saved")
