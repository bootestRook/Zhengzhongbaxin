extends SceneTree

const Flow = preload("res://tests/test_defense_warrior_ui.gd")
const Mouse = preload("res://tests/test_defense_choice_ui.gd")
var app
var view
var flow = Flow.new()
var mouse = Mouse.new()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	view.intent_requested.emit("start", {"seed": flow.recruit_seed(app._catalog)})
	await create_timer(0.75).timeout
	var index: int = app.session.offers.map(func(item): return item.id).find(4)
	var card = view.get_node("ChoicePanel/Cards").get_child(index)
	await sizes("recruit")
	await mouse.click(self, card, Vector2(146, 315))
	await create_timer(0.2).timeout
	# Explicit bonus fixtures exercise actual eligibility and real confirmation.
	for term in [101, 103, 105, 104, 106, 107, 102]:
		index = flow.term_offer(app.session, term)
		view.render(app.battle_snapshot())
		await create_timer(0.75).timeout
		card = view.get_node("ChoicePanel/Cards").get_child(index)
		if term in [101, 106, 107]:
			await sizes("term_%d" % term)
		await mouse.click(self, card, Vector2(146, 315))
		await create_timer(0.2).timeout
	await mouse.click(self, view.get_node("HUD/Hero0/Skill"))
	await sizes("upgraded_shield")
	await mouse.click(self, view.get_node("SkillTooltip/Paper"))
	await mouse.click(self, view.get_node("HUD/Hero0/Portrait"))
	await sizes("learned_terms")
	print("[WARRIOR CAPTURE] upgrades=", app.battle_snapshot().heroes[0].upgrades, " diagnostics=", app.session.diagnostics)
	app.queue_free()
	await process_frame
	quit()

func sizes(label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		var screenshot = root.get_texture().get_image()
		assert(screenshot.save_png("res://validation/defense/warrior_terms/%s_%d.png" % [label, width]) == OK)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.1).timeout
