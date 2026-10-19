extends SceneTree

var app
var view
var panels

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.set_process(false)
	view = app.get_node("DefenseView")
	panels = view.get_node("BattlePanels")
	view.intent_requested.emit("select_level", {"level": 3})
	view.intent_requested.emit("start", {"seed": 889})
	await create_timer(0.75).timeout
	await click(view.get_node("ChoicePanel/Cards/Card1/Info"))
	await shot_sizes("hero_details_collapsed")
	await click(panels.get_node("Hero/Expand"))
	await shot_sizes("hero_details_expanded")
	await click(panels.get_node("Hero/Close"), Vector2(480, 1000))
	await click(view.get_node("HUD/GemStats"))
	await shot_sizes("gem_attributes")
	await click(panels.get_node("Gems/Close"), Vector2(480, 1450))
	await click(view.get_node("HUD/BattleStats"))
	view.render(app.battle_snapshot())
	await shot_sizes("contribution_empty")
	await click(view.get_node("HUD/BattleStats"))
	await click(view.get_node("HUD/Pause"))
	await shot_sizes("pause_reference")
	await click(panels.get_node("Pause/Monster3"))
	await shot_sizes("boss_details")
	await click(panels.get_node("BossDetails/Close"), Vector2(480, 1450))
	await click(panels.get_node("Pause/Resume"))
	await click(view.get_node("ChoicePanel/Cards/Card1"), Vector2(146, 315))
	await create_timer(0.2).timeout
	for _i in range(75):
		app.session.step()
	view.render(app.battle_snapshot())
	await shot("battle_reference_720")
	DisplayServer.window_set_size(Vector2i(960, 1920))
	await create_timer(0.2).timeout
	await shot("battle_reference_960")
	DisplayServer.window_set_size(Vector2i(540, 1080))
	await create_timer(0.2).timeout
	await shot("battle_reference_540")
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.2).timeout
	await click(view.get_node("HUD/MonsterInfo"))
	view.render(app.battle_snapshot())
	await shot_sizes("battle_monsters")
	await click(view.get_node("HUD/MonsterInfo"))
	app.session.factory.add_hero(11)
	var caster = app.session.units[app.session.heroes[0]]
	app.session.factory.create("enemy", 102, caster.pos + Vector2(0, -200), 2)
	for _i in range(600):
		if app.session.phase != "playing":
			break
		app.session.step()
	view.render(app.battle_snapshot())
	await click(view.get_node("HUD/BattleStats"))
	view.render(app.battle_snapshot())
	await shot_sizes("contribution_live")
	await click(view.get_node("HUD/BattleStats"))
	await click(view.get_node("HUD/Hero0"))
	view.render(app.battle_snapshot())
	await shot_sizes("owned_hero_details")
	print("[BATTLE UI CAPTURE] complete")
	app.queue_free()
	await process_frame
	quit()

func shot(name: String) -> void:
	print("[SHOT] %s phase=%s paused=%s hero=%s gem=%s pause=%s" % [name, app.session.phase, app.session.paused, panels.get_node("Hero").visible, panels.get_node("Gems").visible, panels.get_node("Pause").visible])
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/%s.png" % name)

func shot_sizes(name: String) -> void:
	await shot(name)
	for width in [960, 540]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.1).timeout
		await shot("%s_%d" % [name, width])
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await create_timer(0.1).timeout

func click(node: Control, local: Vector2 = Vector2.INF) -> void:
	var point = node.size / 2 if local == Vector2.INF else local
	var pos = node.get_global_transform_with_canvas() * point
	for down in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = pos
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		root.push_input(event, true)
		await process_frame
