extends SceneTree

const Flow = preload("res://tests/test_defense_warrior_ui.gd")
const Mouse = preload("res://tests/test_defense_choice_ui.gd")
var app
var view
var panel
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
	view.intent_requested.emit("start", {"seed": Flow.new().recruit_seed(app._catalog)})
	await create_timer(0.75).timeout
	var index: int = app.session.offers.map(func(item): return item.id).find(4)
	await mouse.click(self, panel.get_node("Cards").get_child(index), Vector2(146, 315))
	await create_timer(0.2).timeout
	var owner = app.session.units[app.session.heroes[0]]
	# Layout fixture for the two referenced terms and a third real option.
	var snapshot: Dictionary = app.battle_snapshot()
	snapshot.phase = "choice"
	snapshot.choice_kind = "bonus"
	snapshot.offers = []
	for option_id in [200107, 200102, 200101]:
		snapshot.offers.append({"kind": "upgrade", "id": option_id, "owner": owner.id, "res": owner.res})
	view.render(snapshot)
	await create_timer(0.75).timeout
	await sizes("terms")
	for card in panel.get_node("Cards").get_children():
		assert(not card.has_node("Skill"))
		assert(card.get_node("Description/Text").size.y <= card.get_node("Description").size.y)
	# Real mixed recruitment and upgrade deal.
	assert(preload("res://tests/test_defense_mixed_choice_ui.gd").new().mixed(app.session))
	view.render(app.battle_snapshot())
	await create_timer(0.75).timeout
	await sizes("mixed")
	var upgrade_index = -1
	for i in range(app.session.offers.size()):
		if app.session.offers[i].kind == "upgrade":
			upgrade_index = i
			break
	var before: Dictionary = app.battle_snapshot()
	await mouse.click(self, panel.get_node("Cards").get_child(upgrade_index).get_node("Info"))
	assert(view.get_node("BattlePanels/Hero").visible)
	assert(app.battle_snapshot().history == before.history)
	await mouse.click(self, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1460))
	await mouse.click(self, panel.get_node("Cards").get_child(upgrade_index), Vector2(146, 405))
	await create_timer(0.2).timeout
	assert(app.battle_snapshot().history.size() == before.history.size() + 1)
	# Production chest reward also uses the text layout.
	var reward: Dictionary = app.session.loot.roll()
	assert(not reward.is_empty())
	app.session.loot.place(reward, Vector2(980, 690))
	view.intent_requested.emit("box", {"id": app.session.boxes[0].id})
	await create_timer(0.75).timeout
	assert(not panel.get_node("Cards/Card1").has_node("Skill"))
	await sizes("chest")
	print("[CHOICE TEXT] 9 captures; descriptions fit; mixed info and text-title selection passed; chest uses text layout")
	app.queue_free()
	await process_frame
	quit()

func sizes(label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://validation/defense/choice_text/%s_%d.png" % [label, width]) == OK)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.15).timeout
