extends SceneTree

const Mouse = preload("res://tests/test_defense_choice_ui.gd")
var app
var view

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	view.intent_requested.emit("start", {"seed": 889})
	await create_timer(0.75).timeout
	await Mouse.new().click(self, view.get_node("ChoicePanel/Cards/Card2"), Vector2(146, 315))
	await create_timer(0.2).timeout
	for id in [12, 5, 11]:
		app.session.factory.add_hero(id)
	for _i in range(100):
		app.session.step()
	view.render(app.battle_snapshot())
	await Mouse.new().click(self, view.get_node("HUD/Hero0/Skill"))
	await sizes("skill_tooltip_battle")
	await Mouse.new().click(self, view.get_node("HUD/Hero3/Skill"))
	await sizes("skill_tooltip_right")
	app.session.choices.offer("upgrade")
	view.render(app.battle_snapshot())
	await create_timer(0.7).timeout
	await Mouse.new().click(self, view.get_node("HUD/Hero3/Skill"))
	if not view.get_node("SkillTooltip").visible:
		await Mouse.new().click(self, view.get_node("HUD/Hero3/Skill"))
	await sizes("skill_tooltip_choice")
	print("[SKILL TOOLTIP CAPTURE] complete")
	app.queue_free()
	await process_frame
	quit()

func sizes(name: String) -> void:
	for width in [720, 960, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.12).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://validation/defense/%s_%d.png" % [name, width])
		print("[SHOT] %s_%d phase=%s paused=%s" % [name, width, app.session.phase, app.session.paused])
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.1).timeout
