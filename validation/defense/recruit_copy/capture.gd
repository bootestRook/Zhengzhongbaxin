extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.session.start(889)
	var view = app.get_node("DefenseView")
	var pool: Array = app.session.choices.hero_pool()
	for group in range(2):
		var snapshot: Dictionary = app.battle_snapshot()
		snapshot.offers = pool.slice(group * 2, group * 2 + 3)
		view.render(snapshot)
		await create_timer(0.75).timeout
		for width in [960, 720, 540]:
			DisplayServer.window_set_size(Vector2i(width, width * 2))
			await create_timer(0.15).timeout
			for card in view.get_node("ChoicePanel/Cards").get_children():
				assert(card.get_node("Description/Text").text == "招募%s" % card.hero.name)
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://validation/defense/recruit_copy/recruit_%d_%d.png" % [group, width]) == OK)
	print("[RECRUIT COPY] all five heroes; 6 native captures; only recruitment text")
	app.queue_free()
	await process_frame
	quit()
