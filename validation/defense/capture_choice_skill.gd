extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
var app
var view
var panel
var tooltip
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
	tooltip = view.get_node("SkillTooltip")
	view.intent_requested.emit("start", {"seed": 889})
	await create_timer(0.75).timeout
	for i in range(3):
		await mouse.click(self, panel.get_node("Cards").get_child(i).get_node("Skill"))
		view.render(app.battle_snapshot())
		assert(tooltip.visible and app.session.history.is_empty(), "candidate skill must only show its description")
		await sizes("choice_skill_hero_%d" % i)
		await mouse.click(self, tooltip.get_node("Paper"))
	var pick: int = 0
	while app.battle_snapshot().offers[pick].id == 6:
		pick += 1
	await mouse.click(self, panel.get_node("Cards").get_child(pick), Vector2(146, 315))
	await create_timer(0.2).timeout
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
	await mouse.click(self, panel.get_node("Cards").get_child(upgrade_index).get_node("Skill"))
	view.render(app.battle_snapshot())
	assert(tooltip.visible, "option description must persist on repeated snapshots")
	await sizes("choice_skill_upgrade")
	view.intent_requested.emit("choose", {"index": upgrade_index})
	var reward = app.session.loot.roll()
	app.session.loot.place(reward, Vector2(980, 690))
	view.intent_requested.emit("box", {"id": app.session.boxes[0].id})
	await create_timer(0.75).timeout
	await mouse.click(self, panel.get_node("Cards/Card1/Skill"))
	assert(tooltip.visible and tooltip.target_index == 0, "single middle-slot chest skill must resolve logical reward zero")
	await sizes("choice_skill_chest")
	# Layout-only fixture uses the three genuine definitions from user Image 2.
	# The click displays metadata and never submits this fixture as a choice.
	view.intent_requested.emit("quit", {})
	view.intent_requested.emit("home", {})
	view.intent_requested.emit("start", {"seed": 889})
	var fixture: Dictionary = app.battle_snapshot()
	fixture.offers = []
	for id in [9, 8, 1]:
		var hero = app._catalog.record("heroes", id)
		var option = app._catalog.record("options", int(hero.initial_options[0]))
		fixture.offers.append({"kind": "hero", "id": id, "owner": 0, "res": hero.res, "title": hero.name, "description": option.description, "subtitle": option.title})
	view.render(fixture)
	await create_timer(0.75).timeout
	await mouse.click(self, panel.get_node("Cards/Card0/Skill"))
	await sizes("choice_skill_reference_fixture")
	print("[CHOICE SKILL CAPTURE] complete; skill clicks preserve real selection history")
	app.queue_free()
	await process_frame
	app = null
	view = null
	panel = null
	tooltip = null
	await process_frame
	quit()

func sizes(name: String) -> void:
	print("[CHOICE SKILL CAPTURE] ", name, " origin=", tooltip.origin)
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.12).timeout
		assert(tooltip.visible, "captured bubble must be visible")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/%s_%d.png" % [name, width])
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.1).timeout
