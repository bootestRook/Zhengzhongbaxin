extends SceneTree

var app

func _initialize() -> void:
	call_deferred("capture")

func prepare(hero_id: int) -> Dictionary:
	app.session.start(73)
	app.session.factory.add_hero(hero_id)
	app.session.phase = "playing"
	app.session.spawn_wave = 1
	app.session.spawn.gaps[0] = 1000000
	return app.session.units[app.session.heroes[0]]

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var hero = prepare(9)
	for tick in range(32):
		app.session.step()
		if tick in [6, 12, 24, 31]:
			await shot("summon_%d" % app.session.time_ms)
	hero = prepare(9)
	app.session.visuals.clear()
	var enemy = app.session.factory.create("enemy", 101, hero.pos + Vector2(160, -60), 2)
	enemy.action = "walk"
	app.session.damage.defeat(enemy, {})
	for tick in range(510):
		app.session.step()
		if tick in [4, 13, 24, 509]:
			await shot("death_%d" % app.session.time_ms)
	hero = prepare(3)
	app.session.visuals.clear()
	for i in range(6):
		enemy = app.session.factory.create("enemy", 101, hero.pos + Vector2(-150 + i % 3 * 150, -350 - i / 3 * 80), 2)
		enemy.core.attributes.set_value("hp", 1000000)
		enemy["busy_until"] = 1000000
	var effects: Dictionary = {}
	var first_missile_at = -1
	for tick in range(1500):
		app.session.step()
		for p in app.session.missiles:
			if p.owner == hero.id and not p.res.is_empty():
				effects[p.res] = true
				if first_missile_at < 0:
					first_missile_at = tick
		if first_missile_at >= 0 and tick - first_missile_at in [0, 4, 8]:
			await shot("mage_arcane_%d" % app.session.time_ms)
		if tick in [60, 100, 250, 800]:
			await shot("mage_initial_%d" % app.session.time_ms)
	print("[INITIAL MAGE] skills=%s upgrades=%s effects=%s" % [hero.skills.keys(), hero.upgrades, effects.keys()])
	DisplayServer.window_set_size(Vector2i(540, 1080))
	await process_frame
	await shot("mage_initial_540")
	app.queue_free()
	await process_frame
	quit()

func shot(name: String) -> void:
	app.get_node("DefenseView").render(app.battle_snapshot())
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/effects_%s.png" % name)
