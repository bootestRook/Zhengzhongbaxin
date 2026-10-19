extends SceneTree

const Repack = preload("res://validation/defense/atlas_repack_fixture.gd")

var app
var view
var panels
var original: DefenseAtlas
var repacked: DefenseAtlas
var directory := "res://validation/defense/atlas_audit"

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
	original = view.atlas
	repacked = Repack.make(original, app._catalog.art())
	DirAccess.make_dir_recursive_absolute(directory)
	# Visual relocation audit uses the production intents/presentation interfaces.
	# Real pointer behavior is covered separately by scene tests and result capture.
	await shots("home")
	view.home_intent("levels", {})
	await shots("levels")
	view.get_node("LevelPanel/LevelClose").pressed.emit()
	view.get_node("Home").show_page("heroes")
	await shots("heroes")
	view.get_node("Home").show_page("battle")
	view.get_node("Home").panel_requested.emit("活动", "当前离线研究界面")
	await shots("home_info")
	view.get_node("HomeInfoPanel/HomeInfoClose").pressed.emit()
	view.intent_requested.emit("select_level", {"level": 3})
	await shots("home_level3")
	view.intent_requested.emit("start", {"seed": 889})
	await create_timer(0.8).timeout
	await shots("hero_choice")
	view.show_choice_skill(0)
	await shots("choice_skill_hero")
	view.get_node("SkillTooltip").dismiss()
	view.show_choice(1)
	await shots("hero_attributes")
	panels.get_node("Hero/Expand").pressed.emit()
	await shots("hero_attributes_expanded")
	panels.close_hero()
	view.show_gems()
	await shots("gems")
	panels.get_node("Gems/Close").pressed.emit()
	view.show_stats()
	await shots("contribution_empty")
	view.show_stats()
	view.intent_requested.emit("pause", {})
	await shots("pause")
	var boss = panels.get_node("Pause/Monster3")
	panels.show_monster(boss.monster, true)
	await shots("boss_details")
	panels.get_node("BossDetails/Close").pressed.emit()
	view.intent_requested.emit("pause", {})
	view.intent_requested.emit("choose", {"index": 1})
	for _i in range(75):
		app.session.step()
	view.render(app.battle_snapshot())
	await shots("battle_speed1")
	view.intent_requested.emit("speed", {})
	await shots("battle_speed2")
	view.intent_requested.emit("speed", {})
	await shots("battle_speed3")
	view.show_monsters()
	await shots("monsters")
	view.show_monsters()
	view.show_skill(0)
	await shots("skill_tooltip")
	view.get_node("SkillTooltip").dismiss()
	view.show_hero(0)
	await shots("owned_hero")
	panels.close_hero()
	app.session.factory.add_hero(11)
	var caster = app.session.units[app.session.heroes[0]]
	app.session.factory.create("enemy", 102, caster.pos + Vector2(0, -200), 2)
	for _i in range(600):
		if app.session.phase != "playing":
			break
		app.session.step()
	view.render(app.battle_snapshot())
	view.show_stats()
	await shots("contribution_live")
	view.show_stats()
	app.session.choices.offer("upgrade")
	view.render(app.battle_snapshot())
	await create_timer(0.8).timeout
	await shots("upgrade_choice")
	view.show_choice_skill(0)
	await shots("choice_skill_upgrade")
	view.get_node("SkillTooltip").dismiss()
	view.show_choice(0)
	await shots("upgrade_attributes")
	panels.close_hero()
	view.intent_requested.emit("quit", {})
	await create_timer(2.1).timeout
	await shots("result")
	print("[ATLAS AUDIT] complete")
	app.queue_free()
	await process_frame
	quit()

func bind(atlas: DefenseAtlas) -> void:
	for node in [view] + view.find_children("*", "", true, false):
		node.set_process(false)
		for property: Dictionary in node.get_property_list():
			if property.name == "atlas":
				node.set("atlas", atlas)
				break
		if node is DefenseAtlasSprite:
			node.configure(atlas)
		if node is DefenseSkillTooltip:
			node.paper_style.texture = atlas.texture("map:tips2")
			node.choice_style.texture = atlas.texture("map:tips2_paper")
		if node is CanvasItem:
			node.queue_redraw()

func shots(name: String) -> void:
	var panels_by_state = {"home": "Home", "home_level3": "Home", "levels": "LevelPanel", "heroes": "Home", "home_info": "HomeInfoPanel",
		"hero_choice": "ChoicePanel", "hero_attributes": "BattlePanels/Hero", "hero_attributes_expanded": "BattlePanels/Hero",
		"gems": "BattlePanels/Gems", "contribution_empty": "BattlePanels/Contribution", "contribution_live": "BattlePanels/Contribution",
		"pause": "BattlePanels/Pause", "boss_details": "BattlePanels/BossDetails", "monsters": "BattlePanels/Monsters",
		"skill_tooltip": "SkillTooltip", "owned_hero": "BattlePanels/Hero", "upgrade_choice": "ChoicePanel", "upgrade_attributes": "BattlePanels/Hero",
		"result": "ResultPanel",
		"choice_skill_hero": "SkillTooltip", "choice_skill_upgrade": "SkillTooltip"}
	if panels_by_state.has(name):
		assert(view.get_node(panels_by_state[name]).is_visible_in_tree(), "audit state must be visible: " + name)
	if name in ["pause", "boss_details"]:
		assert(app.session.paused and app.session.phase == "choice", "audit must preserve paused choice state")
	if OS.get_cmdline_user_args().has("--tooltip-only") and name != "skill_tooltip":
		return
	for width in [540, 720, 960]:
		DisplayServer.window_set_size(Vector2i(width, width * 2))
		await create_timer(0.1).timeout
		for version in ["original", "repacked"]:
			bind(original if version == "original" else repacked)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%d_%s.png" % [directory, name, width, version])
	bind(original)
	DisplayServer.window_set_size(Vector2i(720, 1440))
	await process_frame
	print("[ATLAS AUDIT] %s phase=%s" % [name, app.battle_snapshot().phase])

