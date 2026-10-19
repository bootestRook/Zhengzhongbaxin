extends SceneTree

const Flow = preload("res://tests/test_defense_fire_terms.gd")
const UI = preload("res://tests/test_defense_fire_ui.gd")
var flow = Flow.new()
var ui = UI.new()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var test = preload("res://tests/test_support.gd").new()
	await ui.run(test, self, true)
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	catalog.load_default()
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	for upgraded in [false, true]:
		var w = flow.world(catalog)
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.pos = Vector2(800, 1200)
		if upgraded:
			for id in [201, 202, 203, 204, 205, 206, 207, 208, 209, 210]:
				flow.choose(w, id)
		for i in range(3):
			flow.fixture.enemy(w, Vector2(740 + i * 70, 500 - i * 80))
		w.skills.cast(hero, hero.skills[17].data, {})
		var prefix = "pyroblast" if upgraded else "fireball"
		var charged: int = hero.skills[17].data.fireball.charge_ms
		for at in range(0, charged - 280, 16):
			flow.step(w, at)
		view.render(w.snapshot())
		await ui.sizes(self, prefix + "_charge")
		flow.step(w, charged)
		for i in range(12):
			flow.step(w, charged + 16 * (i + 1))
		view.render(w.snapshot())
		await ui.sizes(self, prefix + "_flight")
		for i in range(100):
			flow.step(w, w.time_ms + 16)
			if w.missiles.any(func(p): return p.skill.get("fire_phase", "") == "blast"):
				break
		for i in range(7):
			flow.step(w, w.time_ms + 16)
		view.render(w.snapshot())
		await ui.sizes(self, prefix + "_blast")
		w.dispose()
	app.queue_free()
	for failure in test.failures:
		push_error(failure)
	print("[FIRE UI] ", test.assertions, " assertions; failures=", test.failures.size())
	await process_frame
	quit(0 if test.failures.is_empty() else 1)
