extends RefCounted

const Ice = preload("res://tests/test_defense_ice_terms.gd")
const Fire = preload("res://tests/test_defense_fire_terms.gd")
const Checks = preload("res://tests/test_defense_projectiles.gd")
const OUT = "res://validation/defense/projectiles"

func run(test, tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		test.assert_true(false, "native screenshots require a rendering display; omit --headless")
		return
	DirAccess.make_dir_recursive_absolute(OUT + "/frames")
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	var evidence: Array = []
	for spec in [["ice3", 13, []], ["ice4", 13, [403]], ["fire1", 1, []],
		["fire2", 1, [206]], ["fire3", 1, [206, 207]], ["pyro", 1, [201, 202, 210]],
		["refraction", 13, [401, 402, 405, 409]]]:
		var w = app.session
		w.start(53)
		w.factory.add_hero(spec[1])
		w.phase = "playing"
		w.spawn_wave = 20
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.pos = Vector2(800, 1220)
		hero.home = hero.pos
		for pair in [["4", 100], ["7", 0], ["12", 0], ["10", 0]]:
			hero.core.attributes.set_value(pair[0], pair[1])
		for term in spec[2]:
			if spec[1] == 13:
				Ice.new().choose(w, term)
			else:
				Fire.new().choose(w, term)
		w.phase = "playing"
		w.offers.clear()
		var checks = Checks.new()
		var target: Dictionary
		if spec[0] == "pyro":
			for y in [930, 750, 570, 390]:
				var enemy = checks.body(w, Vector2(800, y))
				if y == 930:
					target = enemy
		elif spec[0] == "refraction":
			target = checks.body(w, Vector2(800, 830))
			checks.body(w, Vector2(1000, 730))
			checks.body(w, Vector2(800, 590))
		else:
			target = w.factory.create("boss", 104, Vector2(800, 350), 2)
			target.core.attributes.set_value("1", 100000)
			target.core.attributes.set_value("hp", 100000)
			target.core.attributes.set_value("10", 0)
			target.traits.clear()
		if spec[0] == "refraction":
			w.skills.ice.arrow(hero, hero.skills[20002].data, target, false, {"knocked": []}, Vector2.INF)
		elif spec[1] == 13:
			w.skills.cast(hero, hero.skills[20002].data, target)
		else:
			w.skills.fireball.release(hero, hero.skills[17].data.fireball)
		test.assert_true(not w.missiles.is_empty(), "legal capture target emits projectiles for " + spec[0])
		if w.missiles.is_empty():
			continue
		var aim: Vector2 = w.missiles[0].direction
		var record = {"case": spec[0], "initial_count": w.missiles.size(), "initial_degrees": [], "frames": []}
		for p in w.missiles:
			record.initial_degrees.append(rad_to_deg(aim.angle_to(p.direction)))
		var end_ms = 1024 if spec[0] in ["pyro", "refraction"] else 640
		for at in range(0, end_ms + 1, 16):
			w.time_ms = at
			if at > 0:
				w.skills.tick()
				w.projectiles.tick()
				w.statuses.tick()
			if at % 64 != 0:
				continue
			var frame = {"time_ms": at, "missiles": [], "enemies": []}
			for p in w.missiles:
				frame.missiles.append({"id": p.id, "position": [p.pos.x, p.pos.y], "origin": [p.from.x, p.from.y],
					"direction": [p.direction.x, p.direction.y], "kind": p.kind, "hits": p.get("hits", []),
					"hit_limit": p.get("hit_limit", 1), "bounced": p.skill.get("ice_shot", {}).get("bounced", false),
					"fire_phase": p.skill.get("fire_phase", "")})
			for u in w.units.values():
				if u.side == 2:
					frame.enemies.append({"id": u.id, "hp": u.core.attributes.value("hp")})
			record.frames.append(frame)
			app.get_node("DefenseView").render(app.battle_snapshot())
			await tree.process_frame
			await RenderingServer.frame_post_draw
			test.assert_equal(tree.root.get_texture().get_image().save_png(OUT + "/frames/%s_%04d.png" % [spec[0], at]), OK, "native projectile frame saves")
			if at == 384 and spec[0] in ["ice4", "fire3"]:
				for width in [960, 720, 540]:
					DisplayServer.window_set_size(Vector2i(width, width * 2))
					await tree.process_frame
					await RenderingServer.frame_post_draw
					test.assert_equal(tree.root.get_texture().get_image().save_png(OUT + "/%s_%d.png" % [spec[0], width]), OK, "native spread matrix saves")
				DisplayServer.window_set_size(Vector2i(720, 1440))
		evidence.append(record)
		print("[CAPTURE] ", spec[0], " count=", record.initial_count, " degrees=", record.initial_degrees)
	var file = FileAccess.open(OUT + "/flight_measurements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t") + "\n")
	app.queue_free()
	await tree.process_frame
	print("[CAPTURE] assertions=", test.assertions, " failures=", test.failures)
