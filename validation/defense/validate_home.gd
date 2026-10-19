extends SceneTree

var app
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func click(path: String) -> void:
	var control: Control = app.get_node(path)
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size / 2)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://validation/defense/" + name + ".png")

func run() -> void:
	root.position = Vector2i(-3000, 40)
	root.size = Vector2i(720, 1440)
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	verify(app.battle_snapshot().phase == "home", "initial home")
	var home = app.get_node("DefenseView/Home")
	verify(home.final_boss.res == "enemyM1:boarKing", "level one final boss")
	var boss_display: Control = home.get_node("BattlePage/Boss")
	var base: Control = home.get_node("BattlePage/BossBase")
	verify(is_equal_approx(boss_display.position.x + boss_display.size.x / 2, base.position.x + base.size.x / 2), "boss centered on pedestal")
	verify(boss_display.size.x == 240 and boss_display.size.y == 200, "boss uses enlarged display area")
	await capture("home_reference_720")
	await click("DefenseView/Home/BattlePage/Next")
	await click("DefenseView/Home/BattlePage/Next")
	verify(app.battle_snapshot().level == 3, "mouse arrows change actual selected level")
	verify(home.final_boss.res == "enemyM1:snakeKing", "level three final boss")
	await capture("home_level3_720")
	await click("DefenseView/Home/BattlePage/Monster")
	verify(app.get_node("DefenseView/HomeInfoPanel").visible, "boss detail opens")
	verify(app.get_node("DefenseView/HomeInfoPanel/HomeInfoText").text.contains("王蛇"), "boss detail uses selected boss")
	await click("DefenseView/HomeInfoPanel/HomeInfoClose")
	await click("DefenseView/Home/BattlePage/LevelSelect")
	verify(app.get_node("DefenseView/LevelPanel").visible, "click level title opens fifty-level selector")
	await click("DefenseView/LevelPanel/LevelClose")
	await click("DefenseView/Home/Heroes")
	verify(home.get_node("HeroPage").visible, "bottom hero tab switches content")
	await click("DefenseView/Home/Battle")
	for level in range(1, 51):
		app.submit("select_level", {"level": level})
		var row: Dictionary = app._catalog.record("levels", level)
		var final = row.bosses[0]
		for boss in row.bosses:
			if int(boss[1]) > int(final[1]):
				final = boss
		verify(home.final_boss.res == app._catalog.record("monsters", int(final[0])).res, "final boss matches level %d" % level)
	verify(home.get_node("BattlePage/Next").disabled, "last level arrow disabled")
	app.submit("select_level", {"level": 1})
	verify(home.get_node("BattlePage/Previous").disabled, "first level arrow disabled")
	root.size = Vector2i(540, 1080)
	await capture("home_reference_540")
	await click("DefenseView/Home/BattlePage/Start")
	verify(app.battle_snapshot().phase == "choice", "mouse start reaches real hero selection")
	verify(not home.visible, "home hides in battle")
	await capture("home_start_choice")
	app.submit("choose", {"index": 0})
	verify(app.battle_snapshot().heroes.size() == 1, "actual hero recruited")
	app.submit("quit")
	app.submit("home")
	verify(home.visible, "result returns to home")
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("[OK] home rendering and input checks" if failures.is_empty() else "[FAIL] home validation")
	quit(0 if failures.is_empty() else 1)
