extends SceneTree

var app
var view

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	view.intent_requested.emit("start", {"seed": 3})
	await create_timer(0.7).timeout
	await preload("res://tests/test_defense_choice_ui.gd").new().click(self, view.get_node("ChoicePanel/Cards/Card0"), Vector2(146, 315))
	await create_timer(0.2).timeout
	for hid in [1, 2, 13, 17]:
		app.session.factory.add_hero(hid)
	for id in app.session.heroes:
		var hero: Dictionary = app.session.units[id]
		hero.pos = hero.home
		hero.entering = false
	for i in range(9):
		app.session.factory.create("enemy", 101, Vector2(430 + (i % 3) * 220, 800 + (i / 3) * 80), 2)
	view.render(app.battle_snapshot())
	var names = ["shield", "fire", "thorns", "arrows", "assassination"]
	for dimensions in [Vector2i(960, 1920), Vector2i(720, 1440), Vector2i(540, 1080)]:
		DisplayServer.window_set_size(dimensions)
		await create_timer(0.2).timeout
		for i in range(5):
			view.begin_skill_hold(i)
			await create_timer(0.5).timeout
			await shot("%s_%d" % [names[i], dimensions.x])
			if i == 0 and dimensions.x == 720:
				await create_timer(0.25).timeout
				await shot("shield_flow_720")
			view.end_skill_hold()
		await shot("released_%d" % dimensions.x)
	print("[OK] 19 native range captures at 960x1920, 720x1440, 540x1080; visual fixture replays the tested hold handler")
	app.queue_free()
	await process_frame
	quit()

func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	if not label.begins_with("released") and view.get_node("Field").skill_range().is_empty():
		push_error("range capture cancelled: %s phase=%s hold=%d focus=%s" % [label, view.current.phase, view.skill_hold_index, root.has_focus()])
		quit(1)
		return
	root.get_texture().get_image().save_png("res://validation/defense/skill_range/%s.png" % label)
