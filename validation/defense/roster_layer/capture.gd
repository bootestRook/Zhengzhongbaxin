extends SceneTree

var app
var view
var output: String

func _initialize() -> void:
	output = OS.get_cmdline_user_args()[0]
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.submit("start", {"seed": 6})
	view = app.get_node("DefenseView")
	for count in [0, 3, 5]:
		if count == 3:
			for id in [4, 10, 9]:
				app.session.factory.add_hero(id)
		elif count == 5:
			for id in [1, 13]:
				app.session.factory.add_hero(id)
		var snapshot = app.battle_snapshot()
		# Presentation fixture: retain a caster at the real spawn point, where
		# it overlaps the statue, and separate the other actors for inspection.
		snapshot.phase = "playing"
		for actor in snapshot.actors:
			if actor.kind == "hero" and actor.template != 9:
				actor.pos = Vector2(580 + [4, 10, 9, 1, 13].find(actor.template) * 120, 1100)
		view.render(snapshot)
		for dimensions in [Vector2i(480, 960), Vector2i(720, 1440), Vector2i(960, 1920), Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1024, 768)]:
			DisplayServer.window_set_size(dimensions)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var path = "%s/roster_%d_%dx%d.png" % [output, count, dimensions.x, dimensions.y]
			assert(root.get_texture().get_image().save_png(path) == OK)
			for index in range(5):
				var slot = view.get_node("HUD/Hero%d" % index)
				assert(slot.get_node("EmptySlot").visible == (index >= count))
				assert(slot.get_node("EmptySlot").get_global_rect() == slot.get_node("Portrait").get_global_rect())
			print("[CAPTURE] " + path)
	app.queue_free()
	await process_frame
	quit()
