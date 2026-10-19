extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
var test = preload("res://tests/test_support.gd").new()
var app
var view
var transfer
var w

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	w = app.session
	view = app.get_node("DefenseView")
	transfer = view.get_node("ChoiceTransfer")
	transfer.set_process(false)
	var mouse = Mouse.new()
	for width in [720, 540]:
		w.start(53)
		w.pending.clear()
		w.factory.add_hero(4)
		w.factory.add_hero(2)
		var owner: Dictionary = w.units[w.heroes[1]]
		owner.pos = Vector2(880, 1010)
		w.units[w.heroes[0]].pos = Vector2(550, 890)
		w.visuals.clear()
		offer(200303, owner.id)
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.75).timeout
		var card = view.get_node("ChoicePanel/Cards/Card0")
		await mouse.click(self, card.get_node("Info"))
		test.assert_true(transfer.flights.is_empty(), "inspecting an upgrade does not launch an icon")
		await mouse.click(self, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1460))
		await mouse.click(self, card, Vector2(146, 315))
		await create_timer(0.18).timeout
		test.assert_equal(w.selected.get("200303", 0), 1, "real card click commits the actual druid upgrade")
		test.assert_equal(transfer.flights.size(), 1, "one successful selection launches one transfer")
		var flight: Dictionary = transfer.flights[0]
		test.assert_equal(flight.owner, owner.id, "effect tracks the option owner rather than the first hero")
		test.assert_equal(flight.icon, app._catalog.record("options", 200303).icon_res, "flying token uses the chosen term icon")
		var rng = w.rng.snapshot()
		var history = w.history.duplicate(true)
		app.submit("pause", {})
		transfer._process(0.2)
		test.assert_equal(flight.elapsed, 0.0, "manual pause freezes the flying icon")
		app.submit("pause", {})
		for i in range(24):
			if i == 5:
				var old: Vector2 = transfer.target(owner.id).point
				owner.pos += Vector2(2, -1)
				view.render(app.battle_snapshot())
				test.assert_equal(transfer.target(owner.id).point - old, Vector2(2, -1), "destination follows a moving hero")
			await shot("local_%d_%02d" % [width, i])
			transfer._process(0.04)
		test.assert_true(transfer.flights.is_empty(), "flight and landing feedback clean themselves up")
		test.assert_equal(w.rng.snapshot(), rng, "visual feedback consumes no gameplay randomness")
		test.assert_equal(w.history, history, "animation never re-applies the selected option")
		# The same already-acquired term is rejected by the real domain interface.
		offer(200303, owner.id)
		await create_timer(0.75).timeout
		await mouse.click(self, card, Vector2(146, 315))
		await create_timer(0.18).timeout
		test.assert_true(transfer.flights.is_empty(), "rejected selection cannot launch an icon")
		test.assert_equal(w.history, history, "rejected choice retains the previous history")
		var other: Dictionary = w.units[w.heroes[0]]
		var pool: Array = w.choices.upgrade_pool([], other.id)
		offer(int(pool[0].id), other.id)
		w.damage.defeat(other, {})
		view.render(app.battle_snapshot())
		await create_timer(0.75).timeout
		await mouse.click(self, card, Vector2(146, 315))
		await create_timer(0.18).timeout
		test.assert_equal(transfer.flights.size(), 1, "dead hero can still receive a legal selected upgrade")
		test.assert_true(transfer.target(other.id).dead, "dead recipient uses its own roster portrait")
		await shot("dead_recipient_%d" % width)
		app.submit("quit", {})
		test.assert_true(transfer.flights.is_empty(), "exit cancels transfers and landing effects")
		app.submit("home", {})
		test.assert_true(transfer.flights.is_empty(), "home has no retained transfer state")
	for failure in test.failures:
		push_error("TEST FAILURE: " + failure)
	print("[CHOICE TRANSFER] assertions=", test.assertions, " failures=", test.failures.size())
	app.queue_free()
	await process_frame
	quit(0 if test.failures.is_empty() else 1)

func offer(id: int, owner: int) -> void:
	w.offers = [w.choices.card(app._catalog.record("options", id), owner)]
	w.phase = "choice"
	w.choice_kind = "upgrade"
	view.render(app.battle_snapshot())

func shot(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	test.assert_equal(root.get_texture().get_image().save_png("res://validation/defense/choice_transfer/%s.png" % label), OK, "native choice transfer capture saved")
