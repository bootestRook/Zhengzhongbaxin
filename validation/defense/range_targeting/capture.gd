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
	for sample in [[13, 20002, "arrows", 750], [1, 17, "fire", 1000], [17, 1435, "assassination", 160]]:
		app.session.start(53)
		app.session.factory.add_hero(sample[0])
		app.session.phase = "playing"
		app.session.spawn_wave = 20
		app.session.stage = 19
		var hero: Dictionary = app.session.units[app.session.heroes[0]]
		hero.entering = false
		hero.pos = Vector2(hero.home.x, 480) if sample[0] == 17 else hero.home
		hero.attack_at = 1000000
		for state in hero.skills.values():
			state.next = 1000000
		hero.skills[sample[1]].next = 0
		var origin: Vector2 = hero.pos
		var target = app.session.factory.create("enemy", 101, origin - Vector2(0, sample[3]), 2)
		target.core.attributes.set_value("1", 100000)
		target.core.attributes.set_value("hp", 100000)
		target["busy_until"] = 1000000
		for tick in range(500):
			app.session.step()
			app.session.drain_events()
			if hero.stats.damage > 0:
				break
		var expected: Vector2 = target.pos if sample[0] == 17 else origin
		if hero.stats.damage <= 0 or target.pos.y >= 850 or hero.pos != expected:
			push_error("range fixture did not damage the upper target at its expected formation or assassination landing")
			quit(1)
			return
		print("[RANGE COMBAT] ", JSON.stringify({"hero": sample[0], "skill": sample[1], "origin": [origin.x, origin.y],
			"target": [target.pos.x, target.pos.y], "position": [hero.pos.x, hero.pos.y], "damage": hero.stats.damage,
			"cooldown_next": hero.skills[sample[1]].next, "target_hp": target.core.attributes.value("hp")}))
		view.render(app.battle_snapshot())
		for dimensions in [Vector2i(960, 1920), Vector2i(720, 1440), Vector2i(540, 1080)]:
			DisplayServer.window_set_size(dimensions)
			await create_timer(0.2).timeout
			view.begin_skill_hold(0)
			await create_timer(0.5).timeout
			await process_frame
			await RenderingServer.frame_post_draw
			if view.get_node("Field").skill_range().is_empty():
				push_error("skill range preview was not visible during combat capture")
				quit(1)
				return
			var error = root.get_texture().get_image().save_png("res://validation/defense/range_targeting/%s_%d.png" % [sample[2], dimensions.x])
			if error != OK:
				push_error("failed to save native range combat capture")
				quit(1)
				return
			view.end_skill_hold()
		if sample[0] == 17:
			var landing: Vector2 = hero.pos
			for tick in range(500):
				app.session.step()
				app.session.drain_events()
				if hero.pos.y > landing.y and hero.pos.y < 480:
					break
			if hero.pos.y <= landing.y or hero.pos.y >= 480 or hero.action != "walk":
				push_error("assassin did not gradually walk back from its outside landing")
				quit(1)
				return
			print("[OUTSIDE RETURN] ", JSON.stringify({"landing_y": landing.y, "return_y": hero.pos.y, "action": hero.action}))
			view.render(app.battle_snapshot())
			DisplayServer.window_set_size(Vector2i(720, 1440))
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://validation/defense/range_targeting/assassination_return_720.png")
	print("[OK] ten native captures of real ranged damage, outside assassination and gradual return")
	app.queue_free()
	await process_frame
	quit()
