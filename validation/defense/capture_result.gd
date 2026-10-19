extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
const Repack = preload("res://validation/defense/atlas_repack_fixture.gd")
var app
var view
var result
var mouse = Mouse.new()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	result = view.get_node("ResultPanel")
	view.intent_requested.emit("start", {"seed": 889})
	await create_timer(0.75).timeout
	await mouse.click(self, view.get_node("ChoicePanel/Cards/Card1"), Vector2(146, 315))
	await create_timer(0.2).timeout
	for _i in range(8500):
		if app.session.phase == "playing":
			app.session.step()
		elif app.session.phase == "choice":
			app.session.submit("choose", {"index": 0})
		else:
			break
	view.render(app.battle_snapshot())
	await mouse.click(self, view.get_node("HUD/Pause"))
	await mouse.click(self, view.get_node("BattlePanels/Pause/Quit"))
	app.set_process(true)
	var motion_at: int = Time.get_ticks_msec()
	var timings: Array = []
	for i in range(21):
		await create_timer(0.1).timeout
		timings.append({"file": "result_motion_%02d.png" % i, "elapsed_ms": Time.get_ticks_msec() - motion_at})
		await shot("result_motion_%02d" % i)
	var timing_file = FileAccess.open("res://validation/defense/result_motion_times.json", FileAccess.WRITE)
	timing_file.store_string(JSON.stringify(timings, "\t") + "\n")
	timing_file.close()
	await sizes("result_actual")
	await sizes("result_hero_details")
	await mouse.click(self, result.get_node("Confirm"))
	assert(app.session.phase == "home", "real result confirmation must reach home")
	app.set_process(false)
	view.intent_requested.emit("start", {"seed": 889})
	# A labelled layout fixture matches the user's four-character composition.
	# These values only exist in this validation script, never in game results.
	for id in [11, 10, 1, 8]:
		app.session.factory.add_hero(id)
	app.session.stage = 16
	var killed: int = 0
	for i in range(16):
		killed += int(app.session.level.waves[i].count)
	app.session.kills = killed
	app.session.kills += roundi(app.session.level.waves[16].count * 0.2)
	app.session.spawn_wave = 17
	var amounts = [5580, 32210, 3480, 1160]
	var taken = [831, 0, 0, 45]
	for i in range(4):
		var hero = app.session.units[app.session.heroes[i]]
		hero.stats.damage = amounts[i]
		hero.stats.taken = taken[i]
	app.session.bosses_dead = 1
	app.session.level.raw.reward = ["resource:1:109", "resource:2:1"]
	view.intent_requested.emit("quit", {})
	var fixture: Dictionary = app.battle_snapshot()
	fixture.result.rewards[1] = {"res": "resultReference:crystal", "kind": "gem", "count": 1}
	fixture.result.rewards.append({"res": "gameIcon:heroHead8_new", "kind": "hero_exp", "count": 9})
	fixture.result.rewards.append({"res": "gameIcon:heroHead14_new", "kind": "hero_exp", "count": 23})
	fixture.result.rewards.append({"res": "resultReference:equipment", "kind": "equipment", "count": 1})
	result.active = false
	result.render(fixture)
	await create_timer(2.0).timeout
	await sizes("result_reference_fixture")
	await mouse.click(self, result.get_node("Confirm"))
	view.intent_requested.emit("start", {"seed": 891})
	view.intent_requested.emit("quit", {})
	await create_timer(1.8).timeout
	await sizes("result_empty")
	await mouse.click(self, result.get_node("Confirm"))
	view.intent_requested.emit("start", {"seed": 892})
	app.session.factory.add_hero(11)
	app.session.stage = 19
	app.session.spawn_wave = 20
	app.session.bosses_dead = 3
	app.session.finish(true)
	view.render(app.battle_snapshot())
	await create_timer(1.8).timeout
	await sizes("result_victory")
	print("[RESULT CAPTURE] complete")
	app.queue_free()
	await process_frame
	app = null
	view = null
	result = null
	await process_frame
	quit()

func sizes(name: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.12).timeout
		if name == "result_hero_details":
			await mouse.click(self, result.get_node("Heroes").get_child(0).get_node("Info"))
			assert(view.get_node("BattlePanels/Hero").visible, "real window result i must open details at %d" % width)
			assert(not view.get_node("BattlePanels/Pause").visible, "result must not reopen pause")
		await shot("%s_%d" % [name, width])
		if name == "result_hero_details":
			await mouse.click(self, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1200))
			assert(not view.get_node("BattlePanels/Hero").visible, "real details blank-area dismissal at %d" % width)
			print("[RESULT CAPTURE] %d: details open/close through input; pause remains hidden" % width)
	DisplayServer.window_set_size(Vector2i(720,1440))
	await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/%s.png" % name)
