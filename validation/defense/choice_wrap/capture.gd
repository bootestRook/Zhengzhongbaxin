extends SceneTree

var app
var view
var output: String
var prefix: String

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	output = args[0]
	prefix = args[1]
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.submit("start", {"seed": 6})
	for hero_id in [2, 4]:
		app.session.factory.add_hero(hero_id)
	view = app.get_node("DefenseView")
	var snapshot = app.battle_snapshot()
	snapshot.choice_kind = "upgrade"
	snapshot.offers = []
	for option_id in [77, 89, 329]:
		var hero = snapshot.heroes[0 if option_id != 329 else 1]
		snapshot.offers.append({"kind": "upgrade", "id": option_id, "owner": hero.id, "res": hero.res})
	view.render(snapshot)
	await create_timer(0.8).timeout
	var metrics: Array = []
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("%s/%s_%d.png" % [output, prefix, width]) == OK)
		for index in range(3):
			var card = view.get_node("ChoicePanel/Cards/Card%d" % index)
			var scroll = card.get_node("Description")
			var label = scroll.get_node("Text")
			metrics.append({"width": width, "option": card.option.id, "lines": label.get_line_count(),
				"text_width": label.size.x, "area_width": scroll.size.x, "text_height": label.size.y,
				"area_height": scroll.size.y, "font_size": label.get_theme_font_size("font_size")})
	var card = view.get_node("ChoicePanel/Cards/Card0")
	var area = card.get_node("Description")
	var label = area.get_node("Text")
	# Reuse the real card through hidden/recruit/upgrade states, including
	# the longest production description and an unbroken numeric fragment.
	for sample in [app._catalog.record("options", 680).description, "1234567890".repeat(8)]:
		area.hide()
		label.text = "招募"
		await process_frame
		label.text = sample
		area.show()
		area.scroll_vertical = 0
		await process_frame
		await process_frame
		assert(label.size.x <= area.size.x)
		assert(label.size.y > 1 and label.get_line_count() > 1)
		var bar = area.get_v_scroll_bar()
		assert(bar.max_value > bar.page)
		area.scroll_vertical = int(bar.max_value)
		await process_frame
		assert(area.scroll_vertical > 0)
		metrics.append({"stress": sample, "lines": label.get_line_count(), "text_width": label.size.x,
			"area_width": area.size.x, "scroll_bottom": area.scroll_vertical})
	print("[WRAP] " + JSON.stringify(metrics))
	FileAccess.open("%s/%s.json" % [output, prefix], FileAccess.WRITE).store_string(JSON.stringify(metrics, "\t") + "\n")
	app.queue_free()
	await process_frame
	quit()
