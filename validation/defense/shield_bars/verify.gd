extends SceneTree

const Flow = preload("res://tests/test_defense_druid_terms.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
var test = preload("res://tests/test_support.gd").new()
var app
var view
var target: Dictionary
var attacker: Dictionary
var upper_roster: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	var w = app.session
	var flow = Flow.new()
	if "--motion" in OS.get_cmdline_user_args():
		await motion(flow)
		finish()
		return
	if "--targets" in OS.get_cmdline_user_args():
		await target_types(flow)
		finish()
		return
	for width in [720, 540]:
		w.start(53)
		w.factory.add_hero(2)
		w.phase = "playing"
		w.offers.clear()
		var owner: Dictionary = w.units[w.heroes[0]]
		flow.normalize(owner)
		owner.pos = Vector2(950, 1050)
		target = flow.ally(w, 1)
		target.pos = Vector2(700, 900)
		flow.choose(w, 303)
		attacker = flow.enemy(w, Vector2(1000, 700))
		w.visuals.clear()
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.15).timeout
		var empty = await frame("before", width)
		test.assert_equal(empty, [0, 0], "no shield produces no gray shield segment in either consumer")
		test.assert_true(flow.cast(w), "actual thorn cast grants base and extra shields")
		test.assert_equal(target.shield, 65.0, "display receives combined shield amount from the domain")
		w.visuals.clear()
		var gained = await frame("gained", width)
		test.assert_true(gained[0] > 0 and gained[1] > 0, "real shield gain appears inside both health bars")
		var hp = U.hp(target)
		w.damage.heal(owner, target, 10000)
		w.visuals.clear()
		var full_health = await frame("full_health", width)
		test.assert_true(full_health[0] > 0 and full_health[1] > 0, "full health and shield share the original bar")
		w.damage.hit(attacker, target, U.hp(target) - hp, true, true, {"kind": "periodic"})
		w.damage.hit(attacker, target, 32, true, true, {"kind": "attack"})
		test.assert_equal(U.hp(target), hp, "absorbed hit preserves health")
		w.visuals.clear()
		var reduced = await frame("absorbed", width)
		for i in range(2):
			test.assert_true(reduced[i] > 0 and reduced[i] < gained[i], "gray shield segment shrinks with actual shield consumption")
		w.damage.hit(attacker, target, 100, true, true, {"kind": "attack"})
		w.visuals.clear()
		test.assert_equal(await frame("broken", width), [0, 0], "exhausted shields clear both bars")
		flow.cast(w)
		w.time_ms = 11000
		w.statuses.tick()
		w.visuals.clear()
		test.assert_equal(target.shield, 0.0, "timed statuses remove their remaining shield")
		test.assert_equal(await frame("expired", width), [0, 0], "expiration clears both bars")
		flow.cast(w)
		w.damage.defeat(target, {})
		w.visuals.clear()
		test.assert_equal(await frame("dead", width), [0, 0], "dead targets do not retain gray shield segments")
	finish()

func finish() -> void:
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[SHIELD BARS] assertions=", test.assertions, " failures=", test.failures.size())
	app.queue_free()
	await process_frame
	quit(0 if test.failures.is_empty() else 1)

func target_types(flow) -> void:
	var w = app.session
	w.start(53)
	w.factory.add_hero(2)
	w.phase = "playing"
	w.offers.clear()
	var owner: Dictionary = w.units[w.heroes[0]]
	var cases: Array = []
	for i in range(3):
		var kind = ["enemy", "elite", "boss"][i]
		var unit = w.factory.create(kind, 101, Vector2(540 + i * 230, 850), 2)
		flow.normalize(unit)
		# An actual amount shield exceeding maximum life exercises clipping.
		w.damage.apply_skill(unit, unit, {"damage": [[8, 150, 5], [0, 0, 2]]})
		test.assert_equal(unit.shield, 1500.0, "amount shield can exceed maximum health")
		cases.append(unit)
	for width in [720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.15).timeout
		var previous: Dictionary = {}
		for label in ["full", "reduced", "tiny"]:
			if label != "full":
				for unit in cases:
					w.damage.hit(owner, unit, 750 if label == "reduced" else 749, true, true, {"kind": "attack"})
			w.visuals.clear()
			view.render(app.battle_snapshot())
			await process_frame
			await RenderingServer.frame_post_draw
			var bitmap = root.get_texture().get_image()
			test.assert_equal(bitmap.save_png("res://validation/defense/shield_bars/targets_%s_%d.png" % [label, width]), OK, "target types captured")
			var field = view.get_node("Field")
			for unit in cases:
				var head = field.world(unit.pos) + Vector2(unit.motion.hp_offset[0] - 47.5, unit.motion.hp_offset[1])
				var count = shield_pixels(bitmap, field, Rect2(head, Vector2(95, 10)))
				print("[TARGET] ", unit.kind, " ", width, " ", label, " shield=", unit.shield, " pixels=", count)
				test.assert_true(count == 0 if unit.kind == "enemy" else count > 0, "ordinary visibility and elite/boss shield rendering retained")
				if unit.kind != "enemy" and label != "full":
					test.assert_true(count < previous[unit.id], "elite/boss shield pixels track remaining amount")
				previous[unit.id] = count
				var outside = shield_pixels(bitmap, field, Rect2(head + Vector2(97, 0), Vector2(12, 10)))
				test.assert_equal(outside, 0, "large shields cannot overflow the bar")
				test.assert_equal(shield_pixels(bitmap, field, Rect2(head - Vector2(0, 10), Vector2(95, 6))), 0, "no separate shield strip above target health")
		for unit in cases:
			w.damage.apply_skill(unit, unit, {"damage": [[8, 149.9, 5], [0, 0, 2]]})

func frame(label: String, width: int) -> Array:
	view.render(app.battle_snapshot())
	await process_frame
	await RenderingServer.frame_post_draw
	var bitmap = root.get_texture().get_image()
	test.assert_equal(bitmap.save_png("res://validation/defense/shield_bars/%s_%d.png" % [label, width]), OK, "native capture saved")
	var field = view.get_node("Field")
	var head = field.world(target.pos) + Vector2(target.motion.hp_offset[0] - 36, target.motion.hp_offset[1])
	var roster = view.get_node("HUD/Hero1")
	var counts = [shield_pixels(bitmap, field, Rect2(head, Vector2(72, 10))),
		shield_pixels(bitmap, roster, Rect2(14, 173, 144, 10))]
	test.assert_equal(shield_pixels(bitmap, field, Rect2(head - Vector2(0, 10), Vector2(72, 6))), 0, "no separate shield strip above actor health")
	var upper = shield_pixels(bitmap, roster, Rect2(14, 161, 144, 6))
	if label == "before":
		upper_roster[width] = upper
	if not target.dead:
		test.assert_equal(upper, upper_roster[width], "shield does not alter the existing portrait above its health bar")
	print("[PIXELS] ", label, " width=", width, " shield=", target.shield, " gray=", counts)
	return counts

func shield_pixels(bitmap: Image, control: CanvasItem, area: Rect2) -> int:
	var transform = control.get_global_transform_with_canvas()
	var scale = Vector2(bitmap.get_width() / 960.0, bitmap.get_height() / 1920.0)
	var start = (transform * area.position) * scale
	var end = (transform * area.end) * scale
	var count = 0
	for y in range(ceili(start.y), floori(end.y)):
		for x in range(ceili(start.x), floori(end.x)):
			var color = bitmap.get_pixel(x, y)
			if minf(color.r, minf(color.g, color.b)) > 0.65 and maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b)) < 0.08:
				count += 1
	return count

func motion(flow) -> void:
	var w = app.session
	w.start(53)
	w.factory.add_hero(2)
	w.phase = "playing"
	w.offers.clear()
	var owner: Dictionary = w.units[w.heroes[0]]
	flow.normalize(owner)
	owner.pos = Vector2(950, 1050)
	target = flow.ally(w, 1)
	target.pos = Vector2(700, 900)
	attacker = flow.enemy(w, Vector2(1000, 700))
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.15).timeout
	w.time_ms = 1000
	view.render(app.battle_snapshot())
	await process_frame
	await RenderingServer.frame_post_draw
	w.damage.apply_skill(target, target, {"damage": [[8, 50, 5], [0, 0, 2]]})
	var luminance: Dictionary = {}
	for step in range(25):
		w.time_ms = 1040 + step * 40
		if step == 13:
			w.damage.hit(attacker, target, 220, true, true, {"kind": "attack"})
		w.visuals.clear()
		view.render(app.battle_snapshot())
		await process_frame
		await RenderingServer.frame_post_draw
		var bitmap = root.get_texture().get_image()
		test.assert_equal(bitmap.save_png("res://validation/defense/shield_bars/motion_%02d.png" % step), OK, "motion frame saved")
		var field = view.get_node("Field")
		var head = field.world(target.pos) + Vector2(target.motion.hp_offset[0] - 36, target.motion.hp_offset[1])
		luminance[step] = [mean_gray(bitmap, field, Rect2(head, Vector2(72, 10))),
			mean_gray(bitmap, view.get_node("HUD/Hero1"), Rect2(14, 173, 144, 10))]
		await create_timer(0.02).timeout
	for i in range(2):
		test.assert_true(luminance[0][i] > luminance[8][i] + 0.05, "shield gain flash settles to silver gray")
		test.assert_true(luminance[13][i] > luminance[18][i] + 0.03, "absorbed hit flashes then settles")
		test.assert_true(absf(luminance[8][i] - luminance[12][i]) < 0.01, "stable shield does not loop or replay its animation")
	w.paused = true
	w.time_ms = 2050
	w.damage.apply_skill(target, target, {"damage": [[8, 10, 5], [0, 0, 2]]})
	view.render(app.battle_snapshot())
	await process_frame
	await RenderingServer.frame_post_draw
	var before = root.get_texture().get_image()
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var after = root.get_texture().get_image()
	test.assert_equal(before.get_data(), after.get_data(), "paused battle leaves feedback frozen")
	w.damage.defeat(target, {})
	view.render(app.battle_snapshot())
	await process_frame
	await RenderingServer.frame_post_draw
	test.assert_true(not view.get_node("Field").health_bars.has(target.id), "dead target releases its presentation cache")
	print("[MOTION] gain=", luminance[0], " settled=", luminance[8], " hit=", luminance[13], " recovered=", luminance[18])

func mean_gray(bitmap: Image, control: CanvasItem, area: Rect2) -> float:
	var transform = control.get_global_transform_with_canvas()
	var scale = Vector2(bitmap.get_width() / 960.0, bitmap.get_height() / 1920.0)
	var start = (transform * area.position) * scale
	var end = (transform * area.end) * scale
	var total = 0.0
	var count = 0
	for y in range(ceili(start.y) + 2, floori(end.y)):
		for x in range(ceili(start.x), floori(end.x)):
			var color = bitmap.get_pixel(x, y)
			if minf(color.r, minf(color.g, color.b)) > 0.65 and maxf(color.r, maxf(color.g, color.b)) - minf(color.r, minf(color.g, color.b)) < 0.08:
				total += color.r
				count += 1
	return total / maxf(1, count)
