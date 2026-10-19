extends SceneTree

const Rng = preload("res://src/foundation/rng_set.gd")
var app
var view

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	view = app.get_node("DefenseView")
	var ids = app._catalog.available_heroes()
	var seed_value = 0
	for candidate in range(20000):
		var rng = Rng.new(candidate)
		var pool = ids.duplicate()
		rng.stream("defense.choice").shuffle(pool)
		if pool.slice(0, 3) == [13, 10, 9]:
			seed_value = candidate
			break
	view.intent_requested.emit("select_level", {"level": 3})
	view.intent_requested.emit("start", {"seed": seed_value})
	print("[CAPTURE] seed=%d offers=%s" % [seed_value, JSON.stringify(app.battle_snapshot().offers)])
	for i in range(20):
		await create_timer(0.05).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/choice_motion_%02d.png" % i)
	await shot("choice_reference_720")
	DisplayServer.window_set_size(Vector2i(960, 1920))
	await create_timer(0.2).timeout
	await shot("choice_reference_960")
	DisplayServer.window_set_size(Vector2i(540, 1080))
	await create_timer(0.2).timeout
	await shot("choice_reference_540")
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.2).timeout
	await click(view.get_node("ChoicePanel/Cards/Card0/Info"))
	await shot("choice_details")
	await click(view.get_node("BattlePanels/Hero/Close"))
	await click(view.get_node("ChoicePanel/Refresh"))
	await create_timer(0.75).timeout
	await shot("choice_refreshed")
	await click(view.get_node("ChoicePanel/Cards/Card0"), Vector2(146, 315))
	await create_timer(0.2).timeout
	app.session.choices.offer("upgrade")
	view.render(app.battle_snapshot())
	await create_timer(0.75).timeout
	await shot("choice_upgrade")
	print("[CAPTURE] complete")
	app.queue_free()
	await process_frame
	quit()

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/%s.png" % name)

func click(node: Control, local: Vector2 = Vector2.INF) -> void:
	var pos = node.get_global_transform_with_canvas() * (node.size / 2 if local == Vector2.INF else local)
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
