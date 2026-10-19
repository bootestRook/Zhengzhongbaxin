extends SceneTree

const U = preload("res://src/features/defense/domain/defense_units.gd")

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var w = app.session
	w.start(89)
	w.factory.add_hero(1)
	w.phase = "playing"
	w.offers.clear()
	w.pending.clear()
	w.time_ms = 500
	w.visuals.clear()
	var cases: Array = []
	cases.append({"label": "ordinary", "unit": w.factory.create("enemy", 101, Vector2(570, 710), 2)})
	cases.append({"label": "wave_elite", "unit": w.factory.create("elite", 102, Vector2(1010, 710), 2)})
	for i in range(3):
		var entry: Dictionary = w.level.encounters[i]
		w.spawn_wave = entry.wave
		var pos = [Vector2(570, 1040), Vector2(1010, 1040), Vector2(800, 1300)][i]
		cases.append({"label": "encounter_%d" % entry.wave, "unit": w.factory.create_encounter(entry, pos)})
	var metadata: Array = []
	for item in cases:
		var unit: Dictionary = item.unit
		metadata.append({"label": item.label, "kind": unit.kind, "max_hp": U.stat(unit, 1),
			"x": unit.pos.x - 320 + unit.motion.hp_offset[0], "y": unit.pos.y - 97 + unit.motion.hp_offset[1]})
	var details = FileAccess.open("res://validation/defense/elite_health_bars/actors.json", FileAccess.WRITE)
	details.store_string(JSON.stringify(metadata, "\t") + "\n")
	details.close()
	var view = app.get_node("DefenseView")
	for percent in [100, 50, 25, 0]:
		for item in cases:
			var unit: Dictionary = item.unit
			if percent == 0:
				w.damage.defeat(unit, {})
			else:
				unit.core.attributes.set_value("hp", U.stat(unit, 1) * percent / 100.0)
		view.render(w.snapshot())
		for width in [720, 540]:
			DisplayServer.window_set_size(Vector2i(width, width * 2))
			await create_timer(0.15).timeout
			await process_frame
			await RenderingServer.frame_post_draw
			var bitmap = root.get_texture().get_image()
			var path = "res://validation/defense/elite_health_bars/hp_%d_%d.png" % [percent, bitmap.get_width()]
			assert(bitmap.save_png(path) == OK)
			print("[CAPTURE] %s" % path)
	app.queue_free()
	await process_frame
	quit()
