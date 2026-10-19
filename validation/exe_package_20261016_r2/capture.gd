extends SceneTree

var app
var view
var output: String
var report: Dictionary = {"errors": [], "captures": [], "assets_loaded": 0, "raw_files_verified": 0, "rewards": []}

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
	for panel in ["LevelPanel", "GalleryPanel", "HomeInfoPanel"]:
		view.get_node(panel).hide()
	var missing: Array = []
	for character in expected.characters:
		if not view.atlas.font.has_char(character.unicode_at(0)):
			missing.append(character)
	report.font_characters = expected.characters.size()
	report.missing_glyphs = missing
	require(missing.is_empty(), "bundled font lacks required glyphs: " + str(missing))
	report.rules = app._catalog.rules()
	report.unlocked_heroes = app._catalog.available_heroes()
	require(report.unlocked_heroes == [1, 2, 4, 13, 17], "latest unlocked hero set differs")
	require(report.rules.chest_reward_weights == [50, 30, 15, 5], "roulette count weights differ")
	report.roster = []
	for hero_id in report.unlocked_heroes:
		var definition: Dictionary = app._catalog.record("heroes", hero_id)
		require(definition.initial_options.size() == 1, "hero must have one initial skill: " + str(hero_id))
		var option = app._catalog.record("options", definition.initial_options[0])
		report.roster.append({"id": hero_id, "name": definition.name, "initial_skill": option.title})
	report.dpi = DisplayServer.screen_get_dpi()
	for dimensions in expected.matrix:
		DisplayServer.window_set_size(Vector2i(dimensions[0], dimensions[1]))
		await shot("home_%dx%d" % [dimensions[0], dimensions[1]])
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
	report.refresh_sequence = [app.session.refresh_left]
	require(app.session.refresh_left == 2, "new run does not have two refreshes")
	await create_timer(0.8).timeout
	await shot("initial_choice")
	await click(view.get_node("ChoicePanel/Cards/Card0/Info"))
	await shot("choice_attributes")
	view.get_node("BattlePanels").close_hero()
	app.session.paused = false
	for remaining in [1, 0]:
		await click(view.get_node("ChoicePanel/Refresh"))
		await create_timer(0.8).timeout
		require(app.session.refresh_left == remaining, "refresh does not consume the shared allowance")
		report.refresh_sequence.append(app.session.refresh_left)
		await shot("refresh_%d" % remaining)
	app.submit("quit")
	app.submit("home")
	app.submit("start", {"seed": 6})
	report.refresh_sequence.append(app.session.refresh_left)
	require(app.session.refresh_left == 2, "new run does not restore the refreshes")
	await create_timer(0.8).timeout
	var w = app.session
	var captured_battle: bool = false
	var captured_five: bool = false
	for tick in range(70000):
		if w.phase == "choice":
			choose(w)
		if w.phase == "reward":
			await check_reward(w)
		if not captured_battle and w.phase == "playing" and w.time_ms >= 12000:
			captured_battle = true
			await shot("battle")
			await click(view.get_node("HUD/Hero0/Skill"))
			require(view.get_node("SkillTooltip").visible, "short skill click does not open description")
			await shot("skill_tooltip")
			view.get_node("SkillTooltip").dismiss()
			await press(view.get_node("HUD/Hero0/Skill"), true)
			await create_timer(0.5).timeout
			var field = view.get_node("Field")
			require(field.range_hero_id == w.heroes[0], "long press does not preview the correct hero")
			require(not field.skill_range().is_empty(), "long press has no live cast range")
			field.set_process(false)
			field.range_flow = 0.25
			report.skill_range = {"hero": w.heroes[0], "radius": field.skill_range().get("radius", 0)}
			await shot("skill_range")
			await press(view.get_node("HUD/Hero0/Skill"), false)
			require(field.range_hero_id == 0, "releasing skill does not hide range")
			field.set_process(true)
			app.submit("pause")
			await shot("pause")
			app.submit("pause")
		if not captured_five and w.heroes.size() == 5 and w.phase == "playing":
			captured_five = true
			await shot("five_heroes")
			for hero in app.battle_snapshot().heroes:
				require(hero.skills.size() == 1, "recruited hero does not expose one current initial skill")
			await click(view.get_node("HUD/Hero4/Portrait"))
			require(view.get_node("BattlePanels/Hero").visible, "fifth hero inspection failed")
			await shot("fifth_attributes")
			view.get_node("BattlePanels").close_hero()
			w.paused = false
		if w.phase == "result":
			break
		if tick % 128 == 0:
			await process_frame
		w.step()
		w.drain_events()
	view.render(app.battle_snapshot())
	await create_timer(2.0).timeout
	await shot("result")
	report.battle = {"wave": w.spawn_wave, "encounters": w.encounters_cleared.duplicate(), "heroes": w.heroes.size(), "won": w.won, "phase": w.phase, "seed": w.seed, "time_ms": w.time_ms}
	require(captured_battle and captured_five and w.won and w.spawn_wave == 20 and w.encounters_cleared.size() == 3, "latest legal five-hero twenty-wave victory failed")
	report.scheduled_encounters = w.level.encounters.map(func(item): return {"wave": item.wave, "kind": item.kind})
	require(w.level.encounters.map(func(item): return item.kind) == ["elite", "elite", "boss"], "fixed encounters must be two elites and one boss")
	require(report.rewards.all(func(item): return item.source in ["elite", "boss"]), "ordinary enemies must not open roulette")
	require(report.rewards.filter(func(item): return item.source == "elite").size() >= 2 and report.rewards.filter(func(item): return item.source == "boss").size() == 1, "legal run must cover elite and final boss roulette")
	app.queue_free()
	await process_frame
	finish()

func check_reward(w) -> void:
	view.render(app.battle_snapshot())
	var panel = view.get_node("RewardPanel")
	panel.set_process(false)
	var packet: Dictionary = w.loot.current.duplicate(true)
	var label: String = "reward_%s_%d" % [packet.source, report.rewards.size() + 1]
	report.rewards.append({"source": packet.source, "wave": w.spawn_wave, "items": packet.items.map(func(item): return item.id), "requested": packet.requested})
	require(panel.visible, "automatic reward panel is hidden")
	require(panel.get_node("Source").text == ("精英掉落" if packet.source == "elite" else "首领掉落"), "reward source label differs")
	var before_time: int = w.time_ms
	var before_refreshes: int = w.refresh_left
	w.step()
	require(w.time_ms == before_time, "reward does not pause battle clock")
	panel.elapsed = 0.25
	panel.update_motion()
	await shot(label + "_spin")
	var history: Array = w.history.duplicate(true)
	if not packet.items.is_empty():
		await click(panel, Vector2(480, 1720))
		require(panel.finished and w.phase == "reward", "first reward click must reveal without closing")
		await shot(label + "_result")
		for i in range(packet.items.size()):
			require(panel.get_node("Results/Rows").get_child(i).get_node("Content/Text/Description").text == app._catalog.record("options", packet.items[i].id).description, "reward description differs from current term")
	await click(panel, Vector2(480, 1720))
	require(w.history == history, "reward click grants duplicate awards")
	require(w.refresh_left == before_refreshes, "reward consumes refresh allowance")

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

func press(control, down: bool, point: Vector2 = Vector2.INF) -> void:
	var event = InputEventMouseButton.new()
	event.position = control.get_global_transform_with_canvas() * (control.size / 2 if point == Vector2.INF else point)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event, true)
	await process_frame

func click(control, point: Vector2 = Vector2.INF) -> void:
	await press(control, true, point)
	await press(control, false, point)

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
