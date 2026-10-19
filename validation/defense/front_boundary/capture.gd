extends SceneTree

var app
var view

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	for hid in [17, 4]:
		app.session.start(3)
		app.session.factory.add_hero(hid)
		app.session.phase = "playing"
		app.session.spawn_wave = 20
		app.session.stage = 19
		var hero: Dictionary = app.session.units[app.session.heroes[0]]
		hero.entering = false
		hero.pos = hero.home
		for state in hero.skills.values():
			state.next = 1000000
		if hid == 17:
			hero.skills[1435].next = 0
		var point = Vector2(hero.home.x, hero.home.y - 320 if hid == 17 else 650)
		var target = app.session.factory.create("enemy", 101, point, 2)
		target.core.attributes.set_value("1", 100000)
		target.core.attributes.set_value("hp", 100000)
		target["busy_until"] = 1000000
		var minimum: float = hero.pos.y
		for tick in range(120 if hid == 17 else 700):
			app.session.step()
			app.session.drain_events()
			minimum = minf(minimum, hero.pos.y)
		if hero.stats.damage <= 0 or minimum < 480:
			push_error("forward engagement did not produce a legal real attack")
			quit(1)
			return
		print("[FORWARD COMBAT] ", JSON.stringify({"hero": hid, "home": [hero.home.x, hero.home.y], "target": [point.x, point.y],
			"pos": [hero.pos.x, hero.pos.y], "minimum_y": minimum, "attacks": hero.attacks, "damage": hero.stats.damage, "boundary": app.session.guard.line()}))
		view.render(app.battle_snapshot())
		for dimensions in [Vector2i(960, 1920), Vector2i(720, 1440), Vector2i(540, 1080)]:
			DisplayServer.window_set_size(dimensions)
			await create_timer(0.2).timeout
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/defense/front_boundary/%s_%d.png" % ["assassin" if hid == 17 else "warrior", dimensions.x])
	print("[OK] six native forward-engagement captures; actual movement, skill and basic-attack damage")
	app.queue_free()
	await process_frame
	quit()
