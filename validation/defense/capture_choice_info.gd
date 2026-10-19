extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
const Rng = preload("res://src/foundation/rng_set.gd")
var app
var view
var panel
var details
var mouse = Mouse.new()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	panel = view.get_node("ChoicePanel")
	details = view.get_node("BattlePanels")
	var seed_value: int = 0
	for candidate in range(1, 101):
		var ids = app._catalog.available_heroes()
		var index = Rng.new(candidate).stream("defense.choice").next_int(ids.size())
		if ids[index] == 3:
			seed_value = candidate
			break
	view.intent_requested.emit("start", {"seed": seed_value})
	await create_timer(0.75).timeout
	await mouse.click(self, panel.get_node("Cards/Card0/Info"))
	await sizes("choice_info_candidate")
	await mouse.click(self, details.get_node("Hero/Close"), Vector2(480, 1460))
	await mouse.click(self, panel.get_node("Cards/Card0"), Vector2(146, 315))
	await create_timer(0.2).timeout
	# Real fixed-step combat provides production statistics; no reference totals injected.
	for _i in range(500):
		app.session.step()
	var upgrade_index = -1
	for attempt in range(100):
		app.session.choices.offer("upgrade")
		for i in range(app.session.offers.size()):
			if app.session.offers[i].kind == "upgrade":
				upgrade_index = i
				break
		if upgrade_index >= 0:
			break
	assert(upgrade_index >= 0, "capture needs a genuine upgrade in the mixed pool")
	view.render(app.battle_snapshot())
	await create_timer(0.75).timeout
	var before: Dictionary = app.battle_snapshot()
	await mouse.click(self, panel.get_node("Cards").get_child(upgrade_index).get_node("Info"))
	assert(details.hero.id == before.offers[upgrade_index].owner, "attribute panel must resolve the current option owner")
	assert(app.battle_snapshot().history == before.history, "info cannot select an upgrade")
	await sizes("choice_info_upgrade")
	await mouse.click(self, details.get_node("Hero/Expand"))
	await sizes("choice_info_expanded")
	await mouse.click(self, details.get_node("Hero/Close"), Vector2(480, 1460))
	view.intent_requested.emit("choose", {"index": upgrade_index})
	var reward = app.session.loot.roll()
	assert(not reward.is_empty(), "chest fixture requires a genuine reward")
	app.session.loot.place(reward, Vector2(980, 690))
	view.intent_requested.emit("box", {"id": app.session.boxes[0].id})
	await create_timer(0.75).timeout
	await mouse.click(self, panel.get_node("Cards/Card1/Info"))
	assert(details.hero.id == reward.owner, "middle reward i must resolve the stored owner")
	await sizes("choice_info_chest")
	print("[CHOICE INFO CAPTURE] complete; actual pointer paths and real owner statistics")
	app.queue_free()
	await process_frame
	quit()

func sizes(name: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.12).timeout
		assert(details.get_node("Hero").is_visible_in_tree(), "top hero attributes must be visible")
		assert(panel.visible and not app.battle_snapshot().paused, "candidate list and choice state must remain intact")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/%s_%d.png" % [name, width])
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.1).timeout
	print("[CHOICE INFO CAPTURE] ", name, " hero=", details.hero.template)
