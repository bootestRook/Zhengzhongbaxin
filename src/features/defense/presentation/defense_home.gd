class_name DefenseHome
extends Control

signal intent_requested(intent: String, payload: Dictionary)
signal panel_requested(title: String, text: String)

var catalog
var current_level: int = 0
var final_boss: Dictionary = {}
var level_ids: Array = []
var current_page: String = "battle"
var art: DefenseAtlas

func configure(definitions, atlas: DefenseAtlas) -> void:
	catalog = definitions
	level_ids = catalog.level_ids()
	art = atlas
	$BattlePage/Boss.atlas = atlas
	for sprite in find_children("*", "TextureRect"):
		if sprite is DefenseAtlasSprite:
			sprite.configure(atlas)
	$HeroPage.configure(catalog, atlas)
	$HeroDetails.configure(catalog, atlas)
	$HeroPage.hero_requested.connect($HeroDetails.open_hero)
	$HeroDetails.hero_selected.connect(func(id):
		$HeroPage.select_hero(id)
		$HeroPage/Actor.set_process(false))
	$HeroDetails.closed.connect(func(): $HeroPage/Actor.set_process($HeroPage.is_visible_in_tree()))
	$StatuePage.configure(catalog, atlas)
	$StatuePage.intent_requested.connect(func(intent, payload): intent_requested.emit(intent, payload))
	$BattlePage/Start.pressed.connect(func(): intent_requested.emit("start", {}))
	$BattlePage/Previous.pressed.connect(func(): intent_requested.emit("select_level", {"level": current_level - 1}))
	$BattlePage/Next.pressed.connect(func(): intent_requested.emit("select_level", {"level": current_level + 1}))
	$BattlePage/LevelSelect.pressed.connect(func(): intent_requested.emit("levels", {}))
	$Heroes.pressed.connect(func(): show_page("heroes"))
	$Battle.pressed.connect(func(): show_page("battle"))
	$BattlePage/Monster.pressed.connect(show_monster)
	$BattlePage/Activity.pressed.connect(func(): panel_requested.emit("活动", "主线挑战\n\n当前开放第 1～5 关，守住城墙并完成表格中配置的全部波次。\n\n局内招募最多五名英雄、选择强化；精英和首领的数量、波次与出现时间按刷怪表执行。"))
	$BattlePage/FirstGift.pressed.connect(func(): panel_requested.emit("首充礼包", "当前是本地离线演示，未接入充值与礼包领取。"))
	$BattlePage/More.pressed.connect(func(): panel_requested.emit("更多", "点击关卡名称选择关卡，底部战斗按钮返回选关主页。\n点击英雄切换英雄展示页。\n点击右侧放大镜查看本关最终首领。\n\n战斗内支持暂停、倍速、音效开关与英雄技能详情。"))
	$BattlePage/Ranking.pressed.connect(func(): panel_requested.emit("排行榜", "当前未连接服务器，排名与通关人数暂无在线数据。"))
	$BattlePage/Sweep.pressed.connect(func(): panel_requested.emit("扫荡", "当前离线版本保留完整战斗流程，尚未接入扫荡结算。"))
	$BattlePage/Territory.pressed.connect(func(): panel_requested.emit("领地", "当前统一使用固定局外养成：\n\n城墙基础生命 3900\n英雄等级 1\n正式宝石进入关卡后生效；攻速、攻击范围和天罚暂缓\n\n局内成长和英雄自身基础差异仍然生效。"))
	$Shop.pressed.connect(func(): panel_requested.emit("商店", "当前未接入商城与付费购买。\n\n所有可用英雄均可在对局中招募。"))
	$Statue.pressed.connect(func(): show_page("statue"))
	for i in range(3):
		get_node("BattlePage/Reward%d" % i).pressed.connect(func(): show_reward(i))
	for button in find_children("*", "Button"):
		button.pivot_offset = button.size / 2
		button.button_down.connect(func(): button.modulate = Color(0.76, 0.76, 0.76))
		button.button_up.connect(func(): button.modulate = Color.WHITE)
		button.mouse_exited.connect(func(): button.modulate = Color.WHITE)
	show_page("battle")

func show_page(page: String) -> void:
	if $HeroDetails.visible:
		$HeroDetails.close()
	current_page = page
	$BattlePage.visible = page == "battle"
	$HeroPage.visible = page == "heroes"
	$StatuePage.visible = page == "statue"
	set_tab($Heroes, page == "heroes", 1, "home:yx2_up", "home:yx2")
	set_tab($Battle, page == "battle", 2, "home:equip_up", "home:equip")
	set_tab($Statue, page == "statue", 3, "home:tz2_up", "home:tz2")

func set_tab(button: Button, selected: bool, slot: int, icon: String, active_icon: String) -> void:
	button.position = Vector2(slot * 192 - 3 if selected else slot * 192, 1706 if selected else 1745)
	button.size = Vector2(198, 214) if selected else Vector2(192, 175)
	button.get_node("Paper").visible = selected
	var image = button.get_node("Icon")
	image.position = Vector2(5, -35) if selected else Vector2(21, 6)
	image.size = Vector2(188, 188) if selected else Vector2(150, 126)
	image.resource_key = active_icon if selected else icon
	image.configure(art)
	var label: Label = button.get_node("Label")
	label.position = Vector2(0, 123) if selected else Vector2(0, 111)
	label.size = Vector2(button.size.x, 60 if selected else 53)
	label.add_theme_color_override("font_color", Color.BLACK if selected else Color.WHITE)
	label.add_theme_constant_override("outline_size", 0 if selected else 7)
	button.pivot_offset = button.size / 2

func render(value: Dictionary) -> void:
	$HeroDetails.set_equipment(value.get("equipment", {}))
	$StatuePage.render(value.equipment)
	if current_level != int(value.level):
		current_level = int(value.level)
		$BattlePage/LevelSelect/LevelTitle.text = "第%d关" % current_level
		var level_index := level_ids.find(current_level)
		$BattlePage/Previous.disabled = level_index <= 0
		$BattlePage/Next.disabled = level_index < 0 or level_index >= level_ids.size() - 1
		$BattlePage/Previous.modulate = Color(0.7, 0.7, 0.7) if $BattlePage/Previous.disabled else Color.WHITE
		$BattlePage/Next.modulate = Color(0.7, 0.7, 0.7) if $BattlePage/Next.disabled else Color.WHITE
		var level: Dictionary = catalog.record("levels", current_level)
		var final_wave: int = -1
		final_boss = {}
		for entry in level.encounters:
			if entry.kind == "boss" and int(entry.wave) > final_wave:
				final_wave = int(entry.wave)
				final_boss = catalog.record("monsters", int(entry.id))
		$BattlePage/Monster.disabled = final_boss.is_empty()
		$BattlePage/Boss.visible = not final_boss.is_empty()
		if not final_boss.is_empty():
			$BattlePage/Boss.resource_key = final_boss.res
	var cleared: bool = value.won and int(value.level) == int(value.result_level)
	$BattlePage/ClearStatus.text = ("完美通关" if value.wall_hp == value.wall_max and value.deaths == 0 else "已通关") if cleared else "等待挑战"
	$BattlePage/Rank.text = "排名:暂无"
	$BattlePage/ClearCount.text = "1" if value.won and int(value.level) == int(value.get("result_level", 0)) else "0"
	for i in range(3):
		get_node("BattlePage/Reward%d/Claimed" % i).visible = value.won and int(value.level) == int(value.get("result_level", 0))

func show_monster() -> void:
	if final_boss.is_empty():
		panel_requested.emit("第%d关 · 首领" % current_level, "本关刷怪表未配置首领。")
		return
	var level: Dictionary = catalog.record("levels", current_level)
	var boss_wave := 0
	for entry in level.encounters:
		if entry.kind == "boss" and int(entry.id) == int(final_boss.get("__id__", -1)):
			boss_wave = int(entry.wave)
	panel_requested.emit("第%d关 · 首领" % current_level,
			"%s\n\n第 %d 波出现\n\n首领数量、出现时间和属性按当前刷怪表执行。" % [final_boss.title, boss_wave])

func show_reward(index: int) -> void:
	var level: Dictionary = catalog.record("levels", current_level)
	var rewards: Array = level.raw.get("rewardFirst%d" % (index + 1), [])
	var lines: String = ""
	var names: Dictionary = {1: "金币", 2: "钻石", 3: "体力"}
	for reward in rewards:
		var parts: PackedStringArray = str(reward).split(":")
		lines += "%s ×%s\n" % [names.get(int(parts[1]), "资源"), parts[2]]
	panel_requested.emit("第%d关 · 宝箱%d" % [current_level, index + 1], lines + "\n以上为本关配置中的首通奖励，当前版本尚未接入局外发放。")
