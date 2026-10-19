extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
const Flow = preload("res://tests/test_defense_assassin_terms.gd")
const Copy = "刺杀无视目标护甲,若目标生命值低于20%则立即斩杀目标; 若目标为精英或首领则造成3倍伤害"

func _initialize() -> void:
	call_deferred("run")

func prepare(app) -> void:
	app.session.start(53)
	assert(app.session.factory.add_hero(17))
	for term in [501, 502, 506]:
		Flow.new().choose(app.session, term)
	assert(app.session.choices.eligible(app._catalog.record("options", 200508), app.session.units[app.session.heroes[0]]))

func run() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ChoicePanel")
	var mouse = Mouse.new()
	prepare(app)
	var index = preload("res://tests/test_defense_assassin_ui.gd").new().term_offer(app.session, 508)
	view.render(app.battle_snapshot())
	await create_timer(0.75).timeout
	var card = panel.get_node("Cards").get_child(index)
	assert(card.get_node("Description/Text").text == Copy)
	await sizes("upgrade")
	await mouse.click(self, card, Vector2(146, 315))
	await create_timer(0.2).timeout
	assert(app.session.selected.get("200508", 0) == 1)
	prepare(app)
	app.session.phase = "playing"
	app.session.loot.place(app.session.choices.card(app._catalog.record("options", 200508), app.session.heroes[0]), Vector2(800, 900))
	assert(app.session.loot.open(app.session.boxes[0].id).is_empty())
	view.render(app.battle_snapshot())
	await create_timer(0.75).timeout
	card = panel.get_node("Cards").get_child(1)
	assert(card.get_node("Description/Text").text == Copy)
	await sizes("chest")
	await mouse.click(self, card, Vector2(146, 315))
	await create_timer(0.2).timeout
	assert(app.session.selected.get("200508", 0) == 1)
	assert(app.session.units[app.session.heroes[0]].skills[1435].data.assassination.execute)
	app.queue_free()
	await process_frame
	print("[OK] unchanged user copy in upgrade and chest; real input grants upgraded effect")
	quit(0)

func sizes(label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://validation/defense/assassin_final_multiplier/%s_%d.png" % [label, width]) == OK)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.08).timeout
