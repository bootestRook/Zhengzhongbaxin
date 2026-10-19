extends RefCounted

const Mouse = preload("res://tests/test_defense_choice_ui.gd")

func run(test: TestSupport, tree: SceneTree) -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(app)
	await tree.process_frame
	app.set_process(false)
	var view = app.get_node("DefenseView")
	var panel = view.get_node("ResultPanel")
	var mouse = Mouse.new()
	view.intent_requested.emit("start", {"seed": 889})
	await tree.create_timer(0.75).timeout
	await mouse.click(tree, view.get_node("ChoicePanel/Cards/Card1"), Vector2(146, 315))
	await tree.create_timer(0.2).timeout
	var hero = app.session.units[app.session.heroes[0]]
	var enemy = app.session.factory.create("enemy", 101, hero.pos + Vector2(0, -100), 2)
	app.session.damage.hit(hero, enemy, 30, false)
	await mouse.click(tree, view.get_node("HUD/Pause"))
	await mouse.click(tree, view.get_node("BattlePanels/Pause/Quit"))
	test.assert_true(panel.visible, "quit opens named-art result surface")
	test.assert_equal(panel.get_node("Header/Title").text, "关卡结束", "quit uses source blue ending title")
	test.assert_equal(panel.get_node("Heroes").get_child_count(), 1, "result has only actually recruited heroes")
	test.assert_equal(panel.current.heroes[0].stats.damage, hero.stats.damage, "result reads real credited damage")
	test.assert_equal(panel.current.mvp, 0, "single hero receives actual MVP")
	test.assert_equal(panel.get_node("Rewards/Title").text, "未获得奖励", "no configured ordinary reward is not fabricated")
	var entrances: int = panel.entrances
	for _i in range(5):
		view.render(app.battle_snapshot())
	test.assert_equal(panel.entrances, entrances, "repeated snapshots do not restart result motion")
	test.assert_true(not view.get_node("BattlePanels/Pause").visible, "paused quit cannot reopen pause overlay on repeated result snapshots")
	var copy: Dictionary = app.battle_snapshot()
	copy.result.heroes[0].stats.damage = 999999
	test.assert_equal(app.battle_snapshot().result.heroes[0].stats.damage, hero.stats.damage, "result snapshot cannot change domain receipt")
	var clock: int = app.session.time_ms
	for _i in range(5):
		app.session.step()
	test.assert_equal(app.session.time_ms, clock, "ending motion cannot advance battle")
	await tree.create_timer(1.7).timeout
	test.assert_equal(panel.get_node("Heroes").get_child(0).reveal, 1.0, "result count-up reaches final statistics")
	await mouse.click(tree, panel.get_node("Heroes").get_child(0).get_node("Info"))
	view.render(app.battle_snapshot())
	test.assert_true(view.get_node("BattlePanels/Hero").visible, "result hero details survive subsequent result rendering")
	await mouse.click(tree, view.get_node("BattlePanels/Hero/Close"), Vector2(480, 1200))
	test.assert_true(not view.get_node("BattlePanels/Hero").visible, "result details close receives blank-area input above result shield")
	await mouse.click(tree, panel.get_node("Confirm"))
	test.assert_equal(app.battle_snapshot().phase, "home", "result confirmation returns to home once")
	test.assert_true(panel.entrance == null and not panel.visible, "leaving result cancels its Tween")
	view.intent_requested.emit("start", {"seed": 890})
	view.intent_requested.emit("quit", {})
	test.assert_equal(panel.get_node("Heroes").get_child_count(), 0, "early quit has no fabricated roster")
	test.assert_true(panel.get_node("EmptyTeam").visible, "zero-hero result remains understandable")
	test.assert_equal(panel.current.mvp, -1, "empty roster has no MVP")
	view.intent_requested.emit("home", {})
	view.intent_requested.emit("start", {"seed": 891})
	app.session.finish(true)
	view.render(app.battle_snapshot())
	test.assert_equal(panel.current.progress, 1.0, "victory final progress is complete")
	test.assert_equal(panel.get_node("Header/Title").text, "关卡胜利", "victory uses gold title state")
	test.assert_equal(panel.current.best, 1.0, "best progress follows real local result")
	view.intent_requested.emit("home", {})
	view.intent_requested.emit("start", {"seed": 892})
	app.session.stage = 10
	var kills: int = 0
	for i in range(10):
		kills += int(app.session.level.waves[i].count)
	app.session.kills = kills + roundi(app.session.level.waves[10].count / 2.0)
	var partial: Dictionary = app.battle_snapshot()
	view.intent_requested.emit("quit", {})
	test.assert_equal(panel.current.progress, (10 + partial.progress) / 20.0, "ending progress combines completed waves and current real kills")
	test.assert_equal(panel.current.best, 1.0, "later partial run cannot replace better history")
	var receipt: Dictionary = app.session.result.duplicate(true)
	app.session.finish(true)
	test.assert_equal(app.session.result, receipt, "repeated finish cannot change the frozen receipt")
	view.intent_requested.emit("home", {})
	view.intent_requested.emit("select_level", {"level": 2})
	view.intent_requested.emit("start", {"seed": 893})
	app.session.level.raw.reward = ["resource:1:3", "resource:1:4", "resource:2:0", "resource:2:2"]
	view.intent_requested.emit("quit", {})
	test.assert_equal(panel.current.best, 0.0, "best progress belongs to the selected level")
	test.assert_equal(panel.current.rewards.size(), 2, "receipt combines duplicate configured currencies and omits zero counts")
	test.assert_equal(panel.current.rewards[0].count, 7, "configured reward totals are preserved")
	test.assert_equal(panel.current.rewards[0].res, "homeReference:coin", "coin id has its named icon")
	test.assert_equal(panel.current.rewards[1].res, "homeReference:diamond", "diamond id has its named icon")
	app.queue_free()
	await tree.process_frame
