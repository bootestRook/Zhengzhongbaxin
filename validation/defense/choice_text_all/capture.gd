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
	# Definition-backed layout fixtures cover every available recruit.
	var group_index = 0
	for group in [[1, 2, 4], [13, 17, 2]]:
		var snapshot: Dictionary = app.battle_snapshot()
		snapshot.offers = []
		for hero_id in group:
			var hero = app._catalog.record("heroes", hero_id)
			snapshot.offers.append({"kind": "hero", "id": hero_id, "owner": 0, "res": hero.res})
		view.render(snapshot)
		await create_timer(0.75).timeout
		await sizes("recruit_%d" % group_index)
		group_index += 1
	view.render(app.battle_snapshot())
	await create_timer(0.75).timeout
	var warrior_index: int = app.session.offers.map(func(item): return item.id).find(4)
	await mouse.click(self, panel.get_node("Cards").get_child(warrior_index).get_node("TermName"))
	await create_timer(0.2).timeout
	assert(app.battle_snapshot().heroes.size() == 1)
	app.session.factory.add_hero(13)
	# Recreate the user's mixed card arrangement using real definitions and owned heroes.
	var snapshot: Dictionary = app.battle_snapshot()
	snapshot.phase = "choice"
	snapshot.choice_kind = "upgrade"
	snapshot.offers = [
		{"kind": "upgrade", "id": 200101, "owner": snapshot.heroes[0].id, "res": snapshot.heroes[0].res},
		{"kind": "hero", "id": 2, "owner": 0, "res": app._catalog.record("heroes", 2).res},
		{"kind": "upgrade", "id": 200403, "owner": snapshot.heroes[1].id, "res": snapshot.heroes[1].res}]
	view.render(snapshot)
	await create_timer(0.75).timeout
	await sizes("mixed_druid")
	var before: Dictionary = app.battle_snapshot()
	await mouse.click(self, panel.get_node("Cards/Card1/Info"))
	assert(view.get_node("BattlePanels/Hero").visible)
	assert(view.get_node("BattlePanels").hero.template == 2)
	assert(app.battle_snapshot().history == before.history)
	await mouse.click(self, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1460))
	# Real chest input and collection continue to use the same text card.
	view.render(app.battle_snapshot())
	var reward: Dictionary = app.session.loot.roll()
	assert(not reward.is_empty())
	app.session.loot.place(reward, Vector2(980, 690))
	view.intent_requested.emit("box", {"id": app.session.boxes[0].id})
	await create_timer(0.75).timeout
	await sizes("chest")
	await mouse.click(self, panel.get_node("Cards/Card1/TermName"))
	await create_timer(0.2).timeout
	assert(app.battle_snapshot().phase == "playing")
	assert(app.battle_snapshot().history.back().id == reward.id)
	print("[ALL TEXT CARDS] 12 captures; all five recruits, mixed druid, chest, attributes and real title confirmation passed")
	app.queue_free()
	await process_frame
	quit()

func sizes(label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.15).timeout
		for card in panel.get_node("Cards").get_children():
			if not card.visible:
				continue
			assert(not card.has_node("Skill"))
			assert(card.get_node("Description").visible)
			assert(card.get_node("Description/Text").text == card.option.description)
			assert(card.get_node("Description/Text").size.x <= card.get_node("Description").size.x)
			assert(card.tooltip_text.is_empty())
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://validation/defense/choice_text_all/%s_%d.png" % [label, width]) == OK)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.15).timeout
