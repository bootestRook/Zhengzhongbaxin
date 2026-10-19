extends SceneTree

const Flow = preload("res://tests/test_defense_warrior_ui.gd")
const Fixture = preload("res://tests/test_defense_hero_roster.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.submit("start", {"seed": Flow.new().recruit_seed(app._catalog)})
	var index: int = app.session.offers.map(func(item): return item.id).find(4)
	app.submit("choose", {"index": index})
	var w = app.session
	var hero: Dictionary = w.units[w.heroes[0]]
	# Controlled positions use real instances, real shield action and real impacts.
	hero.pos = Vector2(800, 1180)
	for offset in [Vector2(-180, -160), Vector2(140, -230), Vector2(340, -25), Vector2(-340, -300)]:
		Fixture.new().enemy(w, hero.pos + offset)
	w.visuals.clear()
	assert(w.skills.ready_action(hero))
	while not w.units.values().any(func(unit): return unit.taunt == hero.id):
		w.time_ms += 16
		w.skills.tick()
		w.projectiles.tick()
		assert(w.time_ms < 1500)
	w.time_ms += 160
	var view = app.get_node("DefenseView")
	view.render(w.snapshot())
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://validation/defense/taunt_effects/taunt_%d.png" % width) == OK)
	view.get_node("Field").damage_numbers = false
	view.render(w.snapshot())
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://validation/defense/taunt_effects/damage_hidden_540.png") == OK)
	print("[TAUNT CAPTURE] actual taunted enemies=", w.snapshot().actors.filter(func(actor): return actor.taunted).size(), " diagnostics=", w.diagnostics)
	app.queue_free()
	await process_frame
	quit()
