extends RefCounted

const Fire = preload("res://tests/test_defense_fire_terms.gd")
const Checks = preload("res://tests/test_defense_fire_centers.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const OUT = "res://validation/defense/fire_centers"

func run(test, tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		test.assert_true(false, "fire center screenshots require a native rendering display")
		return
	DirAccess.make_dir_recursive_absolute(OUT + "/frames")
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	var evidence: Array = []
	var checks = Checks.new()
	for pyro in [false, true]:
		var w = app.session
		w.start(53)
		w.factory.add_hero(1)
		w.spawn_wave = 20
		var owner: Dictionary = w.units[w.heroes[0]]
		owner.pos = Vector2(800, 1420)
		owner.home = owner.pos
		for pair in [["4", 100], ["7", 0], ["10", 0], ["12", 0]]:
			owner.core.attributes.set_value(pair[0], pair[1])
		for id in [201, 202, 204, 205] + ([210] if pyro else []):
			Fire.new().choose(w, id)
		w.phase = "playing"
		w.offers.clear()
		var targets: Array = []
		for y in ([1000, 700, 400] if pyro else [1000]):
			targets.append(checks.body(w, Vector2(800, y)))
		w.skills.fireball.release(owner, owner.skills[17].data.fireball)
		test.assert_equal(w.missiles.size(), 1, "native fire capture emits one actual projectile")
		var projectile: Dictionary = w.missiles[0]
		var name = "pyro" if pyro else "ordinary"
		var record = {"case": name, "impacts": [], "frames": [], "target_moved": false}
		var anchors: Dictionary = {}
		var seen: Dictionary = {}
		for at in range(0, 4097, 16):
			w.time_ms = at
			if at > 0:
				w.skills.tick()
				w.projectiles.tick()
				w.statuses.tick()
			for p in w.missiles:
				var phase = checks.kind(p)
				if phase.is_empty():
					continue
				if not seen.has(p.id):
					seen[p.id] = true
					if not anchors.has(p.target):
						anchors[p.target] = w.units[p.target].pos
						record.impacts.append({"target": p.target, "time_ms": at, "position": vector(anchors[p.target]),
							"projectile_contact": vector(projectile.pos)})
					test.assert_equal(p.pos, anchors[p.target], "native " + phase + " freezes the target impact position")
					test.assert_equal(p.radius, 351.0 if phase == "secondary" else 270.0, "native effect damage radius")
				test.assert_equal(p.pos, anchors[p.target], "native fire effects retain their anchor throughout flight and delay")
			if not record.target_moved and not record.impacts.is_empty() and at >= record.impacts[0].time_ms + 96:
				targets[0].pos += Vector2(350, 0)
				record.target_moved = true
				record["moved_at_ms"] = at
			if at % 128 != 0:
				continue
			var frame = {"time_ms": at, "effects": [], "targets": []}
			for p in w.missiles:
				var phase = checks.kind(p)
				if not phase.is_empty():
					frame.effects.append({"id": p.id, "target": p.target, "phase": phase, "position": vector(p.pos),
						"radius": p.radius, "start": p.start, "damage_at": p.at, "applied": p.applied})
			for u in targets:
				frame.targets.append({"id": u.id, "position": vector(u.pos), "hp": U.hp(u)})
			record.frames.append(frame)
			app.get_node("DefenseView").render(app.battle_snapshot())
			await tree.process_frame
			await RenderingServer.frame_post_draw
			test.assert_equal(tree.root.get_texture().get_image().save_png(OUT + "/frames/%s_%04d.png" % [name, at]), OK, "native fire center frame saves")
		test.assert_equal(record.impacts.size(), 3 if pyro else 1, "native flight hits the expected distinct targets")
		test.assert_equal(seen.size(), 9 if pyro else 3, "native flight creates one complete effect group per hit")
		test.assert_equal(projectile.hits, targets.map(func(u): return u.id), "native penetration retains actual contact order")
		evidence.append(record)
		print("[FIRE CAPTURE] ", name, " impacts=", record.impacts)
	var file = FileAccess.open(OUT + "/center_measurements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "\t") + "\n")
	app.queue_free()
	await tree.process_frame
	print("[FIRE CAPTURE] assertions=", test.assertions, " failures=", test.failures)

func vector(point: Vector2) -> Array:
	return [point.x, point.y]
