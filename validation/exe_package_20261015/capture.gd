extends SceneTree

var app
var view
var output: String
var report: Dictionary = {"errors": [], "captures": [], "assets_loaded": 0, "raw_files_verified": 0}

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	output = args[0]
	call_deferred("run_checks", args[1])

func require(value: bool, message: String) -> void:
	if not value:
		report.errors.append(message)
		push_error(message)

func run_checks(expectations_path: String) -> void:
	var expected = JSON.parse_string(FileAccess.get_file_as_string(expectations_path))
	for item in expected.raw_files:
		require(FileAccess.file_exists(item.path), "missing raw file: " + item.path)
		if FileAccess.file_exists(item.path):
			require(FileAccess.get_sha256(item.path) == item.sha256, "outdated raw file: " + item.path)
			report.raw_files_verified += 1
	for path in expected.assets:
		require(ResourceLoader.exists(path), "missing runtime asset: " + path)
		if ResourceLoader.exists(path):
			require(load(path) != null, "unloadable runtime asset: " + path)
			report.assets_loaded += 1
	if not report.errors.is_empty():
		finish()
		return
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	require(app.is_ready_for_use(), "main scene boot failed")
	if not app.is_ready_for_use():
		finish()
		return
	view = app.get_node("DefenseView")
	view.get_node("LevelPanel").hide()
	view.get_node("GalleryPanel").hide()
	view.get_node("HomeInfoPanel").hide()
	var missing: Array = []
	for character in expected.characters:
		if not view.atlas.font.has_char(character.unicode_at(0)):
			missing.append(character)
	report.font_characters = expected.characters.size()
	report.missing_glyphs = missing
	require(missing.is_empty(), "bundled font lacks required glyphs: " + str(missing))
	report.rules = app._catalog.rules()
	report.dpi = DisplayServer.screen_get_dpi()
	for size_value in expected.matrix:
		DisplayServer.window_set_size(Vector2i(size_value[0], size_value[1]))
		await shot("home_%dx%d" % [size_value[0], size_value[1]])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	await process_frame
	await process_frame
	report.fullscreen_size = [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(480, 960))
	await process_frame
	require(DisplayServer.window_get_size() == Vector2i(480, 960), "fullscreen return size failed")
	view.home_intent("levels", {})
	await shot("levels")
	view.get_node("LevelPanel").hide()
	view.home_intent("gallery", {})
	await shot("gallery")
	view.get_node("GalleryPanel").hide()
	app.submit("start", {"seed": 6})
	await create_timer(0.8).timeout
	await shot("initial_choice")
	await click(view.get_node("ChoicePanel/Cards/Card0/Skill"))
	await shot("choice_tooltip")
	view.get_node("SkillTooltip").dismiss()
	await click(view.get_node("ChoicePanel/Cards/Card0/Info"))
	await shot("choice_attributes")
	view.get_node("BattlePanels/Hero").hide()
	app.session.paused = false
	var w = app.session
	var captured_battle: bool = false
	var captured_five: bool = false
	for tick in range(70000):
		if w.phase == "choice":
			choose(w)
		if not captured_battle and w.phase == "playing" and w.time_ms >= 12000:
			captured_battle = true
			await shot("battle")
			app.submit("pause")
			await shot("pause")
			app.submit("pause")
		if not captured_five and w.heroes.size() == 5 and w.phase == "playing":
			captured_five = true
			await shot("five_heroes")
			await click(view.get_node("HUD/Hero4/Portrait"))
			require(view.get_node("BattlePanels/Hero").visible, "fifth hero inspection failed")
			await shot("fifth_attributes")
			view.get_node("BattlePanels/Hero").hide()
			w.paused = false
		if w.phase == "result":
			break
		w.step()
		w.drain_events()
	view.render(app.battle_snapshot())
	await create_timer(2.0).timeout
	await shot("result")
	report.battle = {"wave": w.spawn_wave, "bosses_dead": w.bosses_dead, "heroes": w.heroes.size(), "won": w.won, "phase": w.phase, "seed": w.seed, "time_ms": w.time_ms}
	require(w.phase == "result", "complete battle did not reach result")
	require(captured_battle, "combat state was not captured")
	app.queue_free()
	await process_frame
	finish()

func choose(w) -> void:
	var preferred = [1, 10, 9, 5, 3, 11, 17, 2, 4, 14, 8, 6, 7, 15, 16, 12, 13]
	if w.choice_kind == "hero" and w.refresh_left > 0:
		if not w.offers.any(func(item): return item.id in [1, 10, 9, 5]):
			w.submit("refresh")
	var pick: int = 0
	var best: int = -100000
	for index in range(w.offers.size()):
		var item: Dictionary = w.offers[index]
		var hero_id: int = int(item.id) if item.kind == "hero" else int(w.units[item.owner].template)
		var score: int = 1000 - preferred.find(hero_id) * 40
		if item.kind == "hero":
			score += 2000
		else:
			var option = w.catalog.record("options", item.id)
			score += int(str(option.icon).split(":")[1])
		if score > best:
			best = score
			pick = index
	w.submit("choose", {"index": pick})

func click(control) -> void:
	var position_value = control.get_global_transform_with_canvas() * (control.size / 2)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = position_value
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame

func shot(label: String) -> void:
	view.render(app.battle_snapshot())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image_value = root.get_texture().get_image()
	require(image_value.save_png(output + "/" + label + ".png") == OK, "cannot save capture: " + label)
	report.captures.append({"name": label, "width": image_value.get_width(), "height": image_value.get_height()})

func finish() -> void:
	FileAccess.open(output + "/report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("[ACCEPTANCE] " + JSON.stringify(report))
	quit(0 if report.errors.is_empty() else 1)
