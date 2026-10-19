extends SceneTree

var app
var view
var panel
var owners: Dictionary = {}
var checked: int = 0

func _initialize() -> void:
	call_deferred("capture")

func offer(option_id: int) -> Dictionary:
	var option: Dictionary = app._catalog.record("options", option_id)
	var hero_id: int = int(option.type[0])
	return {"kind": "upgrade", "id": option_id, "owner": owners[hero_id], "res": app._catalog.record("heroes", hero_id).res}

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	panel = view.get_node("ChoicePanel")
	app.session.start(53)
	for hero_id in app._catalog.available_heroes():
		app.session.factory.add_hero(hero_id)
		owners[hero_id] = app.session.heroes.back()
	app.session.phase = "playing"
	var snapshot: Dictionary = app.battle_snapshot()
	# Layout fixtures use current definitions; they do not claim natural acquisition.
	for option in app._catalog.records("options").values():
		if option.get("term_id", 0) <= 0 or not owners.has(int(option.type[0])):
			continue
		var card = panel.get_node("Cards/Card0")
		card.configure(view.atlas, offer(option.id), app._catalog, snapshot)
		assert(card.get_node("TermName").text == option.title)
		assert(card.get_node("Description/Text").text == option.description)
		assert(not card.has_node("Skill"))
		checked += 1
	assert(checked == 47)
	# Reproduce the three terms called out in the user's latest screenshot.
	snapshot.phase = "choice"
	snapshot.choice_kind = "upgrade"
	snapshot.offers = [offer(200306), offer(200407), offer(200405)]
	view.render(snapshot)
	await create_timer(0.75).timeout
	await sizes("reported_terms")
	# Also check the short descriptions and their original +/- notation.
	snapshot.offers = [offer(200401), offer(200403), offer(200501)]
	view.render(snapshot)
	await create_timer(0.75).timeout
	await sizes("short_terms")
	print("[ORIGINAL COPY] 47 definition-backed cards checked; 6 captures at 960, 720 and 540 widths")
	app.queue_free()
	await process_frame
	quit()

func sizes(label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.2).timeout
		for card in panel.get_node("Cards").get_children():
			assert(card.get_node("Description/Text").text == card.option.description)
			assert(card.get_node("Description/Text").size.x <= card.get_node("Description").size.x)
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://validation/defense/term_copy_audit/%s_%d.png" % [label, width]) == OK)
