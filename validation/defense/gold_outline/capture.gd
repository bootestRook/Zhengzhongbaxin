extends SceneTree

var app

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var w = app.session
	w.level_id = 5
	w.start(81)
	w.spawn_wave = 20
	w.stage = 19
	w.phase = "playing"
	for hid in [1, 2, 4, 5, 13]:
		w.factory.add_hero(hid)
	var positions := [Vector2(515, 820), Vector2(660, 820), Vector2(810, 820), Vector2(965, 820), Vector2(1100, 820)]
	for i in range(w.heroes.size()):
		var hero: Dictionary = w.units[w.heroes[i]]
		hero.pos = positions[i]
		hero.entering = false
		hero.action = "walk" if i % 2 == 0 else "atk1"
		hero.facing = -1 if i % 2 == 0 else 1
	for pair in [[2, 0], [23, 1], [4, 3], [38, 3], [5, 4]]:
		var i: int = [2, 23, 4, 38, 5].find(pair[0])
		var summon = w.factory.create("summon", pair[0], Vector2(515 + i * 145, 1010), 1, w.heroes[pair[1]])
		summon.action = "walk" if i % 2 == 0 else "atk1"
		summon.facing = -1 if i % 2 == 0 else 1
	for i in range(5):
		w.factory.create("enemy", [103, 106, 112, 107, 113][i], Vector2(515 + i * 145, 580), 2)
	w.visuals.clear()
	w.time_ms = 160
	app.get_node("DefenseView").render(app.battle_snapshot())
	for dimensions in [Vector2i(720, 1440), Vector2i(540, 1080), Vector2i(960, 1920)]:
		DisplayServer.window_set_size(dimensions)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/gold_outline/battle_%d.png" % dimensions.x)
	var shadow: Dictionary = w.units[w.heroes[0]]
	w.units.erase(shadow.id)
	w.heroes.pop_front()
	w.factory.add_hero(17)
	shadow = w.units[w.heroes.back()]
	shadow.pos = positions[0]
	shadow.entering = false
	shadow.action = "atk1"
	shadow.facing = -1
	w.factory.create("summon", 63, Vector2(515, 1140), 1, shadow.id)
	shadow.hidden_until = 300
	DisplayServer.window_set_size(Vector2i(720, 1440))
	app.get_node("DefenseView").render(app.battle_snapshot())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/gold_outline/shadow_hidden_720.png")
	var atlas: DefenseAtlas = app.get_node("DefenseView").atlas
	var resources: Dictionary = {}
	for id in [1, 2, 4, 5, 13, 17]:
		resources[w.catalog.record("heroes", id).res] = true
	for summon: Dictionary in w.catalog.records("summons").values():
		if summon.has("res"):
			resources[summon.res] = true
	var started := Time.get_ticks_usec()
	var keys: Dictionary = {}
	for res: String in resources:
		atlas.outlines.prepare(res, atlas.sprites, atlas.animations, atlas.pages)
		for key: String in atlas.animations:
			if key.begins_with(res + "_"):
				for frame: Dictionary in atlas.animations[key].frames:
					if not atlas.sprites[frame.sprite].get("blank", false):
						keys[frame.sprite] = true
	var maximum := 0
	for key: String in keys:
		var at := Time.get_ticks_usec()
		var texture: ImageTexture = atlas.outlines.texture(key)
		maximum = maxi(maximum, Time.get_ticks_usec() - at)
		assert(texture == atlas.outlines.texture(key), "same animation frame shares the cached outline")
		var r: Array = atlas.sprites[key].rect
		assert(texture.get_size() == Vector2(r[2] + 6, r[3] + 6), "outline padding preserves the frame anchor")
	print("[OK] outline frames=%d resources=%d prepare_and_generate_ms=%.2f slowest_frame_ms=%.2f" % [keys.size(), resources.size(), (Time.get_ticks_usec() - started) / 1000.0, maximum / 1000.0])
	app.queue_free()
	await process_frame
	quit()
