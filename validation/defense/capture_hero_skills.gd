extends SceneTree

var app
var rows: Array = []

func _initialize() -> void:
	call_deferred("capture")

func prepare(hid: int) -> Dictionary:
	app.session.start(53)
	app.session.factory.add_hero(hid)
	if not app.session.pending.is_empty():
		app.session.choices.offer("bonus")
		app.session.submit("choose", {"index": 0})
	app.session.phase = "playing"
	app.session.spawn_wave = 1
	app.session.spawn.gaps[0] = 1000000
	app.session.stage = 19
	var hero: Dictionary = app.session.units[app.session.heroes[0]]
	for i in range(6):
		var enemy = app.session.factory.create("enemy", 101, hero.pos + Vector2(-120 + i % 3 * 120, (-270 if not hero.front else -70) - i / 3 * 40), 2)
		enemy.core.attributes.set_value("1", 100000)
		enemy.core.attributes.set_value("hp", 100000)
		enemy.core.attributes.set_value("4", 1)
		enemy["busy_until"] = 1000000
	return hero

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	for hid in app._catalog.available_heroes():
		var hero = prepare(hid)
		var captured = false
		var movies: Dictionary = {}
		var shots: Dictionary = {}
		for tick in range(1500):
			app.session.step()
			for p in app.session.missiles:
				if p.owner == hero.id:
					movies[p.res] = true
					var inspect_age = 800 if p.kind == 31 else (32 if p.kind == 9 else 160)
					if hid == 1 and p.kind in [31, 9, 2] and not shots.has(p.kind) and app.session.time_ms - p.start > inspect_age:
						shots[p.kind] = true
						await shot("fire_stage_%d" % p.kind)
			if not captured and tick > 120 and not app.session.missiles.is_empty():
				await shot("hero_%02d" % hid)
				captured = true
		if not captured:
			await shot("hero_%02d" % hid)
		rows.append({"hero": hid, "name": hero.name, "skills": hero.skills.keys(), "options": hero.upgrades.duplicate(), "movies": movies.keys(), "damage": hero.stats.damage})
		print("[CAPTURE] hero=%d skills=%s effects=%s" % [hid, hero.skills.keys(), movies.keys()])
	var file = FileAccess.open("res://validation/defense/hero_skill_native.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t") + "\n")
	app.queue_free()
	await process_frame
	quit()

func shot(name: String) -> void:
	app.get_node("DefenseView").render(app.battle_snapshot())
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/skills_%s.png" % name)
