extends SceneTree

var test = preload("res://tests/test_support.gd").new()
var app
var view
var marker
var w
var heroes: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	w = app.session
	w.start(53)
	w.phase = "playing"
	w.offers.clear()
	for id in [4, 2]:
		w.factory.add_hero(id)
		heroes.append(w.units[w.heroes.back()])
	heroes[0].pos = Vector2(650, 1070)
	heroes[1].pos = Vector2(1050, 980)
	for hero in heroes:
		w.damage.defeat(hero, {})
	for i in range(35):
		w.factory.create("enemy", 101 if i % 2 == 0 else 102, Vector2(560 + (i % 7) * 85, 920 + (i / 7) * 65), 2)
	view = app.get_node("DefenseView")
	marker = view.get_node("Field/TombstoneEffects")
	if "--finish" in OS.get_cmdline_user_args():
		await finish_transition()
		complete()
		return
	test.assert_equal(heroes[0].revive_at, 20000, "warrior retains twenty-second revival")
	test.assert_equal(heroes[1].revive_at, 10000, "druid retains ten-second revival")
	test.assert_true(not w.snapshot().heroes[0].tombstone, "death animation still completes before the tombstone appears")
	test.assert_true(marker.z_index < view.get_node("HUD").z_index, "revival effects remain behind the HUD")
	var wall = w.wall_hp
	w.time_ms = 5000
	w.factory.lifecycle()
	view.render(app.battle_snapshot())
	var state = w.snapshot()
	for i in range(2):
		var hero: Dictionary = state.heroes[i]
		var path: Dictionary = marker.descent(hero)
		test.assert_true(hero.tombstone, "both actual deaths produce markers")
		test.assert_equal(path.base, view.get_node("Field").world(heroes[i].pos), "marker stays at the actual defeat position")
		test.assert_equal(path.progress, 0.25 if i == 0 else 0.5, "source descent follows each profession's real deadline")
		test.assert_equal(view.get_node("HUD/Hero%d/Revive" % i).text, "15" if i == 0 else "5", "bottom hero countdown is retained")
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.12).timeout
		await shot("crowded_%d" % width)
	# Freeze an active descent through the real pause intent.
	var before = marker.descent(w.snapshot().heroes[1]).source
	app.submit("pause", {})
	app._process(0.2)
	test.assert_equal(w.time_ms, 5000, "pause freezes the authoritative revival timer")
	test.assert_equal(marker.descent(w.snapshot().heroes[1]).source, before, "pause freezes the falling source")
	await process_frame
	await RenderingServer.frame_post_draw
	var frozen = root.get_texture().get_image().get_data()
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	test.assert_equal(root.get_texture().get_image().get_data(), frozen, "paused light column and sparkles stay frozen")
	app.submit("pause", {})
	# The actual app accumulator drives both revival and descent at 1x/3x.
	var time_before: int = w.time_ms
	app._process(0.16)
	var normal_elapsed: int = w.time_ms - time_before
	app.submit("speed", {})
	app.submit("speed", {})
	test.assert_equal(w.speed, 3, "real speed intents select triple speed")
	time_before = w.time_ms
	var source_before: Vector2 = marker.descent(w.snapshot().heroes[0]).source
	app._process(0.16)
	var fast_elapsed: int = w.time_ms - time_before
	test.assert_true(absi(fast_elapsed - normal_elapsed * 3) <= 48, "triple speed advances the same authoritative clock")
	test.assert_true(marker.descent(w.snapshot().heroes[0]).source.y > source_before.y, "source descends as accelerated battle time advances")
	# Domain fixture replay captures an entire descent; labels retain its real times.
	DisplayServer.window_set_size(Vector2i(720, 1440))
	for i in range(21):
		w.time_ms = 1000 + i * 400
		w.factory.lifecycle()
		view.render(app.battle_snapshot())
		await shot("descent_%02d" % i)
	w.time_ms = 9999
	w.factory.lifecycle()
	var last = w.snapshot().heroes[1]
	var arrival = marker.descent(last)
	test.assert_true(last.tombstone, "source remains present until one millisecond before revival")
	test.assert_true(arrival.source.distance_to(arrival.base - Vector2(0, 65)) < 0.05, "ten-second source reaches the grave at its exact revival deadline")
	w.time_ms = 10000
	w.factory.lifecycle()
	test.assert_true(not w.snapshot().heroes[1].tombstone, "ten-second marker clears at actual revival")
	test.assert_true(w.snapshot().heroes[0].tombstone, "twenty-second marker remains independent")
	view.render(app.battle_snapshot())
	await shot("ten_seconds_revived_720")
	w.time_ms = 19999
	w.factory.lifecycle()
	last = w.snapshot().heroes[0]
	arrival = marker.descent(last)
	test.assert_true(arrival.source.distance_to(arrival.base - Vector2(0, 65)) < 0.05, "twenty-second source also reaches its independent deadline")
	w.time_ms = 20000
	w.factory.lifecycle()
	test.assert_true(not w.snapshot().heroes[0].tombstone, "twenty-second marker clears on revival")
	test.assert_equal(w.wall_hp, wall, "visual waiting consumes no statue health")
	view.render(app.battle_snapshot())
	await shot("both_revived_720")
	for i in range(2):
		test.assert_true(not view.get_node("HUD/Hero%d/Revive" % i).visible, "bottom countdown hides after revival")
	view.intent_requested.emit("quit", {})
	view.intent_requested.emit("home", {})
	test.assert_equal(w.snapshot().phase, "home", "exit clears the revival scene normally")
	preload("res://tests/test_defense_experience.gd").new()._revival(test, app._catalog)
	complete()

func complete() -> void:
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[TOMBSTONE] assertions=", test.assertions, " failures=", test.failures.size())
	app.queue_free()
	await process_frame
	quit(0 if test.failures.is_empty() else 1)

func finish_transition() -> void:
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.12).timeout
	for step in range(19):
		w.time_ms = 9900 + step * 50
		w.factory.lifecycle()
		view.render(app.battle_snapshot())
		await shot("finish_%02d_720" % step)
		if w.time_ms < 10000:
			test.assert_true(heroes[1].dead and not marker.endings.has(heroes[1].id), "waiting does not start the ending early")
		elif w.time_ms < 10600:
			test.assert_true(not heroes[1].dead, "hero revives on time while visual ending plays")
			test.assert_true(marker.endings.has(heroes[1].id), "revival starts a finite afterglow at the old marker")
			var ending: Dictionary = marker.endings[heroes[1].id]
			test.assert_equal(ending.start, 10000, "ending uses the actual revival deadline")
			test.assert_equal(ending.actor.pos, Vector2(1050, 980), "afterglow remains at the grave rather than jumping to the hero spawn")
			view.render(app.battle_snapshot())
			test.assert_equal(marker.endings[heroes[1].id].start, 10000, "repeated render cannot restart the ending")
			test.assert_true(not view.get_node("HUD/Hero1/Revive").visible, "bottom countdown ends on time")
		else:
			test.assert_true(not marker.endings.has(heroes[1].id), "afterglow is removed after its finite duration")
		if step == 4:
			app.submit("pause", {})
			app._process(0.2)
			test.assert_equal(w.time_ms, 10100, "pause freezes an active ending's clock")
			test.assert_equal(marker.endings[heroes[1].id].start, 10000, "pause preserves the same ending")
			await process_frame
			await RenderingServer.frame_post_draw
			var frozen = root.get_texture().get_image().get_data()
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			test.assert_equal(root.get_texture().get_image().get_data(), frozen, "active disappearance freezes visually while paused")
			app.submit("pause", {})
		if step in [0, 4, 8, 16]:
			DisplayServer.window_set_size(Vector2i(540, 1080))
			await create_timer(0.08).timeout
			await shot("finish_%02d_540" % step)
			DisplayServer.window_set_size(Vector2i(720, 1440))
			await create_timer(0.08).timeout
	test.assert_true(marker.waiting.has(heroes[0].id), "other hero's twenty-second descent remains independent")
	w.time_ms = 20000
	w.factory.lifecycle()
	view.render(app.battle_snapshot())
	test.assert_true(marker.endings.has(heroes[0].id), "twenty-second revival also receives the ending")
	app.submit("quit", {})
	app.submit("home", {})
	test.assert_true(marker.waiting.is_empty() and marker.endings.is_empty(), "leaving battle clears all waiting and fading markers")

func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	test.assert_equal(root.get_texture().get_image().save_png("res://validation/defense/tombstone/%s.png" % label), OK, "native revival capture saved")
