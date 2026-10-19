extends SceneTree

const Files = preload("res://src/platform/lab_files.gd")
var app
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/defense_lab.tscn").instantiate()
	root.add_child(app)
	await create_timer(0.4).timeout
	app.load_path("res://tests/lab_cases/08_ice_combo.json", false)
	app.get_node("%Tabs").current_tab = 4
	app.get_node("%LogFilter").text = "skill_combo"
	var timeline: Array = []
	for stage in [{"ticks": 46, "name": "first", "extra": 0}, {"ticks": 18, "name": "waiting", "extra": 0}, {"ticks": 1, "name": "second", "extra": 4}, {"ticks": 16, "name": "hits", "extra": 0}]:
		app.single_step(stage.ticks)
		await process_frame
		await process_frame
		var extra: Array = app.lab.world.missiles.filter(func(p): return p.start == 1040)
		if stage.name in ["first", "waiting", "second"] and extra.size() != stage.extra:
			failures.append("unexpected repeat volley at " + stage.name)
		var path = "res://validation/battle_lab/ice_combo/%s.png" % stage.name
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(path) != OK: failures.append("capture failed: " + path)
		timeline.append({"stage": stage.name, "time_ms": app.lab.world.time_ms, "damage": app.lab.inspect(1).stats.damage,
			"projectiles": app.lab.world.snapshot().missiles.size(), "image": path})
	if app.lab.inspect(1).stats.damage != 140.0: failures.append("two actual hits must total 140")
	Files.write_json("res://validation/battle_lab/ice_combo/visual.json", {"failures": failures, "timeline": timeline, "runtime_fingerprint": Files.fingerprint()})
	for failure in failures: push_error("TEST FAILURE: " + failure)
	print("[ICE COMBO VISUAL] ", timeline, " failures=", failures)
	app.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
