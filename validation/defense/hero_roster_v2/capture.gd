extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
var app
var view
var mouse = Mouse.new()

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	view.intent_requested.emit("start", {"seed": 53})
	await create_timer(0.75).timeout
	await sizes("recruit")
	await mouse.click(self, view.get_node("ChoicePanel/Cards/Card0/Skill"))
	await sizes("recruit_skill")
	await mouse.click(self, view.get_node("SkillTooltip/Paper"))
	await mouse.click(self, view.get_node("ChoicePanel/Cards/Card0"), Vector2(146, 315))
	await create_timer(0.2).timeout
	# Visual fixture; legal recruitment and complete runs have separate tests.
	for hid in [1, 2, 4, 13, 17]:
		app.session.factory.add_hero(hid)
	app.session.phase = "playing"
	app.session.spawn_wave = 20
	app.session.stage = 19
	for i in range(6):
		var target = app.session.factory.create("enemy", 101, Vector2(420 + i * 130, 900), 2)
		for key in ["1", "hp"]:
			target.core.attributes.set_value(key, 100000)
		target.core.attributes.set_value("4", 0)
	for i in range(800):
		app.session.step()
	view.render(app.battle_snapshot())
	await sizes("battle")
	for i in range(5):
		await mouse.click(self, view.get_node("HUD/Hero%d/Skill" % i))
		assert(view.get_node("SkillTooltip").visible)
		await sizes("skill_%d" % app.battle_snapshot().heroes[i].template)
	await mouse.click(self, view.get_node("SkillTooltip/Paper"))
	await mouse.click(self, view.get_node("HUD/Hero0/Portrait"))
	await sizes("attributes")
	await mouse.click(self, view.get_node("BattlePanels/Hero/Expand"))
	await sizes("attributes_expanded")
	await mouse.click(self, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1460))
	view.intent_requested.emit("home", {})
	view.get_node("Home").show_page("heroes")
	await sizes("heroes")
	view.get_node("Home/HeroPage/Scroll").scroll_vertical = 10000
	await sizes("gallery_lower")
	print("[HERO ROSTER CAPTURE] complete; diagnostics=", app.session.diagnostics)
	app.queue_free()
	await process_frame
	quit()

func sizes(label: String) -> void:
	for width in [960, 720, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		var screenshot = root.get_texture().get_image()
		assert(screenshot.save_png("res://validation/defense/hero_roster_v2/%s_%d.png" % [label, width]) == OK)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.1).timeout
