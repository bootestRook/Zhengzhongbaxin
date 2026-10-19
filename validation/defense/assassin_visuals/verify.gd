extends SceneTree

const Flow = preload("res://tests/test_defense_assassin_terms.gd")

class OpacityProbe extends Control:
	var atlas: DefenseAtlas
	var tint: Color = Color("bf6cff")
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 8, 8), Color.BLACK)
		atlas.draw(self, "sample", Vector2.ZERO, Vector2.ONE, 0, Vector2.ZERO, tint, 0, false, [], Color.TRANSPARENT, true)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = preload("res://tests/test_support.gd").new()
	Flow.new().run(test)
	preload("res://tests/test_defense_assassin_final_multiplier.gd").new().run(test)
	preload("res://tests/test_defense_atlas_bindings.gd").new().run(test, self)
	await opacity(test)
	await battle(test)
	for failure: String in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[ASSASSIN VISUALS] assertions=%d failures=%d" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)

func battle(test: TestSupport) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var w = app.session
	w.start(53)
	w.factory.add_hero(17)
	w.phase = "playing"
	w.stage = 19
	w.spawn_wave = 20
	var flow = Flow.new()
	var owner: Dictionary = w.units[w.heroes[0]]
	flow.normalize(owner)
	owner.pos = Vector2(800, 1050)
	var target = flow.enemy(w, owner.pos + Vector2(0, -130))
	flow.enemy(w, target.pos + Vector2(70, -30))
	flow.enemy(w, target.pos + Vector2(-70, -30))
	for term in [503, 504, 505, 507]:
		flow.choose(w, term)
	test.assert_true(flow.cast(w), "actual assassination emits its damage visuals")
	# Direct cast fixture: reserve its normal cooldown before automatic stepping.
	owner.skills[1435].next = w.time_ms + 8000
	w.skills.assassination.basic_hit(owner, target)
	test.assert_equal(owner.stats.damage, 900.0, "one 300-percent main hit plus both 100-percent areas retain their actual damage on three clustered enemies")
	var styles = w.visuals.filter(func(v): return v.has("assassin_visual"))
	test.assert_equal(styles.map(func(v): return v.assassin_visual), ["strike", "smoke", "fan"], "each damage component has a separate presentation role")
	test.assert_equal(styles[1].layer, -1, "smoke renders behind actors and the electric impact")
	test.assert_equal(owner.skills[1435].data.visual_tint, "#bf6cff", "runtime loads the purple palette from the authoritative workbook")
	test.assert_equal(w.statuses.definitions["20503"].colorChange, "#CB9BE8FF", "shock uses the matching softer purple feedback")
	for time in [64, 208, 416]:
		while w.time_ms < time:
			w.step()
		view.render(w.snapshot())
		var before: Dictionary = w.snapshot()
		var rng: Dictionary = w.rng.snapshot()
		await shot("combined_%d" % time)
		test.assert_equal(w.snapshot(), before, "rendering effects leaves authoritative combat state unchanged")
		test.assert_equal(w.rng.snapshot(), rng, "electric flicker consumes no gameplay randomness")
	w.submit("pause")
	var clock: int = w.time_ms
	for i in range(10):
		w.step()
	test.assert_equal(w.time_ms, clock, "pause freezes effect age with the combat clock")
	w.submit("pause")
	while w.time_ms < 550:
		w.step()
	test.assert_true(not w.visuals.any(func(v): return v.has("assassin_visual")), "short-lived effects are removed after their real cue duration")
	# Isolate smoke in a rendered snapshot to inspect its retained texture/hue.
	owner.skills[1435].data.assassination.fan = false
	owner.skills[1435].next = w.time_ms
	flow.cast(w)
	owner.skills[1435].next = w.time_ms + 8000
	for i in range(12):
		w.step()
	var smoke_snapshot: Dictionary = w.snapshot()
	smoke_snapshot.visuals = smoke_snapshot.visuals.filter(func(v): return v.get("assassin_visual", "") == "smoke")
	view.render(smoke_snapshot)
	await shot("smoke")
	# Shared recoloring must keep fading at draw time, without extra RGB caches.
	var atlas = view.atlas
	var cached: int = atlas.effect_colors.textures.size()
	for i in range(30):
		view.render(smoke_snapshot)
		await process_frame
	test.assert_equal(atlas.effect_colors.textures.size(), cached, "repeated frozen-clock rendering does not grow recolored texture caches")
	app.queue_free()
	await process_frame

func opacity(test: TestSupport) -> void:
	var viewport = SubViewport.new()
	viewport.size = Vector2i(8, 8)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var probe = OpacityProbe.new()
	var catalog = Flow.Catalog.new()
	catalog.load_default()
	probe.atlas = DefenseAtlas.new({"sprites": {"sample": {"page": 0, "rect": [0, 0, 8, 8], "size": [8, 8], "offset": [0, 0]}},
		"animations": {}, "pages": [], "font": catalog.art().font})
	var pixels = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	probe.atlas.pages.append(ImageTexture.create_from_image(pixels))
	viewport.add_child(probe)
	var red: Array = []
	for alpha in [1.0, 0.25, 0.0]:
		probe.tint.a = alpha
		probe.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		red.append(viewport.get_texture().get_image().get_pixel(4, 4).r)
	test.assert_true(red[1] > 0 and red[1] < red[0] * 0.7, "native recolored drawing applies fractional opacity")
	test.assert_true(red[2] < 0.03, "fully faded recolored drawing leaves no visible residue")
	test.assert_equal(probe.atlas.effect_colors.textures.size(), 1, "native fading uses one recolored RGB texture")
	viewport.queue_free()
	await process_frame

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error: int = root.get_texture().get_image().save_png("res://validation/defense/assassin_visuals/%s.png" % name)
	assert(error == OK, "native VFX capture must be saved")
