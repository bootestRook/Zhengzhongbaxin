extends SceneTree

var app
var view
var output: String = "res://validation/defense/tombstone"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.submit("start", {"seed": 17})
	var w = app.session
	var pick = 0
	while w.offers[pick].id == 6:
		pick += 1
	app.submit("choose", {"index": pick})
	for tick in range(360):
		w.step()
	var hero = w.units[w.heroes[0]]
	var death_position: Vector2 = hero.pos
	assert(death_position != hero.home)
	w.damage.defeat(hero, {})
	assert(hero.dead)
	w.time_ms = hero.death_finish_at + 1000
	w.factory.lifecycle()
	for hero_id in app._catalog.available_heroes():
		if hero_id != hero.template:
			w.factory.add_hero(hero_id)
			break
	var snapshot = app.battle_snapshot()
	assert(snapshot.heroes[0].tombstone)
	assert(snapshot.heroes[0].pos == death_position)
	view = app.get_node("DefenseView")
	view.render(snapshot)
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await shot("death_%d" % width)
	var report = {"hero": hero.template, "death_position": [death_position.x, death_position.y],
		"formation": [hero.home.x, hero.home.y], "tombstone_position": [snapshot.heroes[0].pos.x, snapshot.heroes[0].pos.y]}
	w.time_ms = hero.revive_at
	w.factory.lifecycle()
	assert(not hero.dead and hero.pos == w.factory.hero_spawn())
	assert(not w.snapshot().heroes[0].tombstone)
	report["revival_position"] = [hero.pos.x, hero.pos.y]
	view.render(app.battle_snapshot())
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await shot("revived_720")
	FileAccess.open(output + "/report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t") + "\n")
	print("[TOMBSTONE] " + JSON.stringify(report))
	app.queue_free()
	await process_frame
	quit()

func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output + "/" + label + ".png") == OK)
