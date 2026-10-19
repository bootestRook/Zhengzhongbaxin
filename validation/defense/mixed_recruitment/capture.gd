extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
var app
var captured_mixed: bool = false

func _initialize() -> void:
	call_deferred("run_capture")

func run_capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.session.start(6)
	var w = app.session
	for i in range(60000):
		if w.phase == "choice":
			if not captured_mixed and w.offers.any(func(item): return item.kind == "hero") and w.offers.any(func(item): return item.kind == "upgrade"):
				captured_mixed = true
				await capture_mixed(w)
			choose(w)
		if w.phase == "result":
			break
		w.step()
		w.drain_events()
	app.get_node("DefenseView").render(app.battle_snapshot())
	await create_timer(2.0).timeout
	await shots("result")
	print("[RUN] " + JSON.stringify({"seed": w.seed, "wave": w.spawn_wave, "stage": w.stage + 1, "won": w.won,
		"wall_hp": w.wall_hp, "kills": w.kills, "deaths": w.deaths, "bosses": w.bosses_dead,
		"time_ms": w.time_ms, "history": w.history, "heroes": w.snapshot().heroes.map(func(h): return h.template)}))
	var passed: bool = w.won and w.spawn_wave == 20 and w.bosses_dead == 3 and captured_mixed
	app.queue_free()
	await process_frame
	var test = preload("res://tests/test_support.gd").new()
	await preload("res://tests/test_defense_mixed_choice_ui.gd").new().run(test, self)
	for failure in test.failures:
		push_error(failure)
	if not passed:
		push_error("mixed-recruitment default-health twenty-wave capture did not win or lacked a mixed deal")
	print("[CAPTURE] mixed mouse checks=%d failures=%d" % [test.assertions, test.failures.size()])
	quit(0 if passed and test.failures.is_empty() else 1)

func capture_mixed(w) -> void:
	var view = app.get_node("DefenseView")
	var cards = view.get_node("ChoicePanel/Cards")
	var panels = view.get_node("BattlePanels")
	view.render(app.battle_snapshot())
	await create_timer(0.75).timeout
	print("[DEAL] " + JSON.stringify({"stage": w.stage + 1, "wave": w.spawn_wave, "offers": w.offers, "history": w.history}))
	await shots("mixed")
	var recruit_index = -1
	var upgrade_index = -1
	for i in range(w.offers.size()):
		if w.offers[i].kind == "hero":
			recruit_index = i
		else:
			upgrade_index = i
	var mouse = Mouse.new()
	await mouse.click(self, cards.get_child(recruit_index).get_node("Skill"))
	await shots("recruit_skill")
	await mouse.click(self, cards.get_child(recruit_index).get_node("Info"))
	await shots("recruit_info")
	await mouse.click(self, panels.get_node("Hero/Close"), Vector2(480, 1460))
	await mouse.click(self, cards.get_child(upgrade_index).get_node("Info"))
	await shots("upgrade_info")
	await mouse.click(self, panels.get_node("Hero/Close"), Vector2(480, 1460))

func choose(w) -> void:
	var preferred = [1, 10, 9, 5, 3, 11, 17, 2, 4, 14, 8, 6, 7, 15, 16, 12, 13]
	if w.choice_kind == "hero" and w.refresh_left > 0:
		if not w.offers.any(func(item): return item.id in [1, 10, 9, 5]):
			w.submit("refresh")
	var pick = 0
	var best = -100000
	for index in range(w.offers.size()):
		var item: Dictionary = w.offers[index]
		var hero_id: int = int(item.id) if item.kind == "hero" else int(w.units[item.owner].template)
		var score = 1000 - preferred.find(hero_id) * 40
		if item.kind == "hero":
			score += 2000
		else:
			score += int(str(w.catalog.record("options", item.id).icon).split(":")[1])
		if score > best:
			best = score
			pick = index
	w.submit("choose", {"index": pick})

func shots(state: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		app.get_node("DefenseView").render(app.battle_snapshot())
		await create_timer(0.15).timeout
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/mixed_recruitment/%s_%d.png" % [state, width])
