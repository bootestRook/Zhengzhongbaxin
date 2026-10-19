extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
var app
var view

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var test = preload("res://tests/test_support.gd").new()
	preload("res://tests/test_defense_loot.gd").new().run(test)
	await preload("res://tests/test_defense_chest_ui.gd").new().run(test, self)
	if not test.failures.is_empty():
		for message in test.failures:
			push_error(message)
		quit(1)
		return
	print("[CHEST] %d focused assertions passed" % test.assertions)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var w = app.session
	w.start(17)
	for id in [5, 10, 1, 17]:
		w.factory.add_hero(id)
	w.phase = "playing"
	w.pending.clear()
	w.offers.clear()
	w.spawn_wave = 16
	var hero = w.units[w.heroes[2]]
	w.upgrades.apply(hero, 2)
	w.loot.place(w.choices.card(w.choices.options["3"], hero.id), Vector2(980, 690))
	for i in range(12):
		w.factory.create("enemy", [101, 102, 103][i % 3], Vector2(440 + (i % 5) * 170, 180 + (i / 5) * 210), 2)
	view = app.get_node("DefenseView")
	view.render(app.battle_snapshot())
	var field = view.get_node("Field")
	field.set_process(false)
	field.chest_time = 0
	field.queue_redraw()
	await sizes("chest_ground")
	var body = DefenseChestVisual.body_rect(field.world(w.boxes[0].pos))
	var event = InputEventMouseMotion.new()
	event.position = field.get_global_transform_with_canvas() * body.get_center()
	root.push_input(event, true)
	field.set_process(true)
	await process_frame
	await process_frame
	for i in range(24):
		field.set_process(false)
		field.chest_time = field.hover_started + i * 40
		field.queue_redraw()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/chest_hover_%02d.png" % i)
	print("[CHEST HOVER] hovered=%d" % field.hovered_box)
	await Mouse.new().click(self, field, body.get_center())
	await create_timer(0.7).timeout
	field.queue_redraw()
	await sizes("chest_reward")
	await Mouse.new().click(self, view.get_node("ChoicePanel/Cards/Card1"), Vector2(146, 315))
	await create_timer(0.2).timeout
	print("[CHEST CONFIRM] phase=%s selected=%d" % [w.phase, w.selected["3"]])
	app.queue_free()
	await process_frame
	await process_frame
	quit()

func sizes(name: String) -> void:
	for width in [720, 960, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.impeccable/review/%s_%d.png" % [name, width])
		print("[SHOT] %s_%d" % [name, width])
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.1).timeout
