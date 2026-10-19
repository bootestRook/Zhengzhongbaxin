extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var w = app.session
	w.start(17)
	w.factory.add_hero(4)
	w.phase = "playing"
	var hero = w.units[w.heroes[0]]
	var view = app.get_node("DefenseView")
	w.time_ms = 200
	view.render(app.battle_snapshot())
	await shot("summoned_gold")
	for i in range(360):
		w.step()
	w.damage.defeat(hero, {})
	var death_position: Vector2 = hero.pos
	w.time_ms = hero.revive_at
	w.factory.lifecycle()
	assert(hero.pos == w.factory.hero_spawn() and hero.pos != death_position)
	var revived_at: int = w.time_ms
	var cues = w.visuals.filter(func(effect): return effect.kind == "revive")
	assert(cues.size() == 2)
	for elapsed in [0, 100, 200, 300, 400, 500]:
		while w.time_ms < revived_at + elapsed:
			w.step()
		view.render(app.battle_snapshot())
		await shot("revive_%03d" % elapsed)
	assert(not w.visuals.any(func(effect): return effect.kind == "revive"))
	print("[REVIVE VISUAL] gold recruitment, cyan revival, one complete animation, expired without residue")
	app.queue_free()
	await process_frame
	quit()

func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://validation/defense/roster_alignment/%s.png" % label) == OK)
