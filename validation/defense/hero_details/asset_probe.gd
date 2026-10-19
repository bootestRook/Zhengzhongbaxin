extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.position = Vector2i(-3000, 40)
	root.size = Vector2i(960, 960)
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	catalog.load_default()
	var atlas = DefenseAtlas.new(catalog.art())
	var canvas := Control.new()
	root.add_child(canvas)
	canvas.draw.connect(func():
		canvas.draw_rect(Rect2(0, 0, 960, 960), Color("777777"))
		var keys = ["common:panelBg3", "common:panelBg4", "common:heroInfo2Bg", "common:textBg_Box", "common:textBg_Box_Arrow", "common:btnY", "map:tips2", "map:buffCard_hero_Info_face", "common:closeIcon"]
		for i in range(keys.size()):
			var pos = Vector2((i % 3) * 320 + 20, (i / 3) * 310 + 30)
			canvas.draw_string(atlas.font, pos, keys[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)
			atlas.picture(canvas, keys[i], Rect2(pos + Vector2(0, 20), Vector2(280, 250))))
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/hero_details/assets.png")
	quit()
