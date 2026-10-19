extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test: TestSupport, tree: SceneTree) -> void:
	var starts: Array = []
	var deals: Dictionary = {}
	for _i in range(6):
		var app = load("res://scenes/main.tscn").instantiate()
		tree.root.add_child(app)
		await tree.process_frame
		app.set_process(false)
		await Mouse.new().click(tree, app.get_node("DefenseView/Home/BattlePage/Start"))
		test.assert_equal(app.session.phase, "choice", "ordinary start mouse input supplies a seed and opens candidates")
		test.assert_true(app.session.seed > 0 and app.session.seed <= 0x7fffffff, "app injects a valid system-generated run seed")
		starts.append(app.session.seed)
		deals[JSON.stringify(app.session.offers)] = true
		app.queue_free()
		await tree.process_frame
		await tree.process_frame
	test.assert_true(starts[0] != starts[1] or starts[1] != starts[2], "fresh app instances do not reset to one fixed opening seed")
	test.assert_true(deals.size() > 1, "fresh app starts exercise more than one opening candidate deal")
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var payload = {"seed": 3}
	app.submit("start", payload)
	var fixed = app.session.offers.duplicate(true)
	test.assert_equal(app.session.seed, 3, "explicit seed is not overwritten by app entropy")
	test.assert_equal(payload, {"seed": 3}, "app does not mutate caller-owned start input")
	app.submit("quit")
	app.submit("start", {"seed": 3})
	test.assert_equal(app.session.offers, fixed, "explicit seeded retry reproduces the opening")
	app.submit("quit")
	var unseeded: Dictionary = {}
	app.submit("start", unseeded)
	test.assert_equal(unseeded, {}, "ordinary retry seed is injected into a copied request")
	test.assert_true(app.session.seed != 3, "ordinary retry replaces the previous run seed")
	app.queue_free()
	await tree.process_frame
	await tree.process_frame
