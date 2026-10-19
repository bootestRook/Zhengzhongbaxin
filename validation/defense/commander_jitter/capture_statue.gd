extends SceneTree

const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")
const Statue = preload("res://src/features/defense/domain/defense_statue.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var w = app.session
	w.level_id = 3
	w.start(81)
	w.phase = "playing"
	var enemy = w.factory.create("enemy", 101, Vector2(1250, 1460), 2)
	enemy.skills.clear()
	w.ai.tick()
	assert(w.wall_hp == 3900 and enemy.attacks == 0)
	for width in [480, 720]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		app.get_node("DefenseView").render(app.battle_snapshot())
		await shot("statue_distant_%d" % width)
	enemy.pos = Geometry.approach(enemy, Statue.TARGET)
	w.ai.tick()
	w.time_ms = enemy.attack_events[0].at
	w.ai.advance_attack(enemy)
	assert(w.wall_hp < 3900)
	for width in [480, 720]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		app.get_node("DefenseView").render(app.battle_snapshot())
		await shot("statue_hit_%d" % width)
	print("[STATUE VISUAL] distant enemy cannot attack; contact hit number appears on statue at 480 and 720 widths")
	app.queue_free()
	await process_frame
	quit()

func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://validation/defense/commander_jitter/%s.png" % label) == OK)
