class_name DefenseBattlePanels
extends Control

signal intent_requested(intent: String, payload: Dictionary)
signal damage_display_changed(enabled: bool)

const MonsterRow = preload("res://scenes/defense/monster_row.tscn")
const ContributionRow = preload("res://scenes/defense/contribution_row.tscn")
const EXTRA_ATTRIBUTES = [[2, 11, 15, 20, 30], [6, 25, 16, 21, 27], [7, 12, 17, 22, 32], [8, 13, 24, 23]]

var catalog
var atlas: DefenseAtlas
var current: Dictionary = {}
var hero: Dictionary = {}
var expanded: bool = false
var roster_count: int = -1
var monster_level: int = -1

func configure(definitions, resources: DefenseAtlas) -> void:
	catalog = definitions
	atlas = resources
	$Pause/Resume.pressed.connect(func(): intent_requested.emit("pause", {}))
	$Pause/Quit.pressed.connect(func(): intent_requested.emit("quit", {}))
	$Pause/Damage.toggled.connect(func(enabled): damage_display_changed.emit(enabled))
	$Gems/Close.pressed.connect(func(): $Gems.hide())
	$Monsters/Close.pressed.connect(func(): $Monsters.hide())
	$Hero/Close.pressed.connect(close_hero)
	$Hero/Expand.pressed.connect(func():
		expanded = not expanded
		$Hero/Expand.position.y = 632 if expanded else 292
		redraw())
	$BossDetails/Close.pressed.connect(func(): $BossDetails.hide())
	for i in range(6):
		var portrait = get_node("Pause/Monster%d" % i)
		portrait.pressed.connect(func(): show_monster(portrait.monster, portrait.kind))

func render(value: Dictionary) -> void:
	var entering_result: bool = value.phase == "result" and current.get("phase", "") != "result"
	current = value
	$Pause.visible = value.paused and value.phase != "result" and not $Hero.visible
	if value.phase == "home" or entering_result:
		$Gems.hide()
		$Hero.hide()
		$Contribution.hide()
		$Monsters.hide()
		$BossDetails.hide()
		$Pause.hide()
	if not value.paused:
		$BossDetails.hide()
	if monster_level != int(value.level):
		build_monsters()
	if roster_count != value.heroes.size():
		for row in $Contribution/Rows.get_children():
			row.free()
		roster_count = value.heroes.size()
		for _i in range(roster_count):
			$Contribution/Rows.add_child(ContributionRow.instantiate())
	var sorted: Array = value.heroes.duplicate()
	sorted.sort_custom(func(a, b): return a.stats.damage > b.stats.damage)
	var maximum = sorted[0].stats.damage if not sorted.is_empty() else 1.0
	for i in range(sorted.size()):
		$Contribution/Rows.get_child(i).render(sorted[i], atlas, maximum)
	if $Hero.visible:
		for owned in value.heroes:
			if owned.template == hero.template:
				hero = owned
		$Hero/Summary.text = "输出:%d    治疗:%d    承伤:%d" % [hero.stats.damage, hero.stats.heal, hero.stats.taken]
	redraw()

func build_monsters() -> void:
	monster_level = int(current.level)
	var level = catalog.record("levels", monster_level)
	var entries: Array = []
	var seen: Array = []
	for encounter in level.encounters:
		var record = catalog.record("monsters", int(encounter.id))
		seen.append(record.res)
		entries.append({"monster": record, "kind": encounter.kind})
	var normal: Array = []
	for wave in level.waves:
		for entry in wave.entries:
			var record = catalog.record("monsters", int(entry.monster_id))
			if not seen.has(record.res):
				seen.append(record.res)
				normal.append({"monster": record, "kind": "enemy" if entry.kind == "normal" else entry.kind})
	normal.sort_custom(func(a, b):
		var a_key = float(str(a.monster.get("atlas", a.monster.get("__id__", 0))).split(":")[0])
		var b_key = float(str(b.monster.get("atlas", b.monster.get("__id__", 0))).split(":")[0])
		return a_key < b_key)
	for row in $Monsters/Scroll/Rows.get_children():
		row.free()
	for entry in entries + normal:
		var row = MonsterRow.instantiate()
		$Monsters/Scroll/Rows.add_child(row)
		row.configure(atlas, entry.monster, entry.kind)
	for i in range(6):
		var collection: Array = normal if i < 3 or entries.is_empty() else entries
		var portrait = get_node("Pause/Monster%d" % i)
		portrait.visible = i % 3 < collection.size()
		if portrait.visible:
			var entry = collection[i % 3]
			portrait.configure(atlas, entry.monster, entry.kind)

func show_monster(monster: Dictionary, kind: String) -> void:
	$BossDetails/Paper/Portrait.configure(atlas, monster, kind)
	$BossDetails/Paper/Portrait.disabled = true
	$BossDetails/Paper/Name.text = monster.title
	$BossDetails/Paper/Description.text = monster.description
	$BossDetails.show()
	redraw()

func show_hero(value: Dictionary) -> void:
	hero = value
	$Hero/Summary.text = "输出:%d    治疗:%d    承伤:%d" % [hero.stats.damage, hero.stats.heal, hero.stats.taken]
	expanded = false
	$Hero/Expand.position.y = 292
	$Hero.show()
	$Gems.hide()
	redraw()

func close_hero() -> void:
	$Hero.hide()

func show_gems() -> void:
	$Gems.show()
	redraw()

func toggle_contribution() -> void:
	$Contribution.visible = not $Contribution.visible
	redraw()

func toggle_monsters() -> void:
	$Monsters.visible = not $Monsters.visible
	redraw()

func redraw() -> void:
	for name in ["Pause", "Gems", "Hero", "Contribution", "BossDetails"]:
		get_node(name + "/Paint").queue_redraw()

func draw_panel(canvas: CanvasItem, panel: String) -> void:
	if atlas == null:
		return
	match panel:
		"Pause":
			atlas.picture(canvas, "common:btnRed", Rect2(150, 910, 280, 100))
			atlas.picture(canvas, "common:btnRed", Rect2(520, 910, 280, 100))
			canvas.draw_rect(Rect2(331, 1127, 70, 72), Color.BLACK)
			canvas.draw_rect(Rect2(336, 1132, 60, 62), Color("719fda"))
			if $Pause/Damage.button_pressed:
				canvas.draw_line(Vector2(339, 1157), Vector2(357, 1180), Color.BLACK, 18, true)
				canvas.draw_line(Vector2(357, 1180), Vector2(389, 1139), Color.BLACK, 18, true)
				canvas.draw_line(Vector2(339, 1157), Vector2(357, 1180), Color.WHITE, 10, true)
				canvas.draw_line(Vector2(357, 1180), Vector2(389, 1139), Color.WHITE, 10, true)
		"BossDetails":
			atlas.picture(canvas, "common:panel2_variant2_face", Rect2(108, 758, 744, 369))
			canvas.draw_line(Vector2(150, 953), Vector2(785, 953), Color("aaaaaa"), 2)
		"Contribution":
			var height: float = $Contribution/Rows.position.y + $Contribution/Rows.size.y + 15 - 208
			var rect = Rect2(143, 208, 349, height)
			canvas.draw_rect(rect, Color(0, 0, 0, 0.66))
			canvas.draw_rect(rect, Color("333333"), false, 3)
		"Gems":
			draw_gems(canvas)
		"Hero":
			draw_hero(canvas)

func text(canvas: CanvasItem, pos: Vector2, content: String, font_size: int = 40, color: Color = Color.WHITE, outline: int = 4) -> void:
	canvas.draw_string_outline(atlas.font, pos, content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline, Color.BLACK)
	canvas.draw_string(atlas.font, pos, content, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func draw_gems(canvas: CanvasItem) -> void:
	atlas.draw(canvas, "statue:statue1", Vector2(235, 595), Vector2.ONE * 1.8, 0, Vector2(0.5, 1))
	for i in range(3):
		var label = ["生命", "攻击力", "防御力"][i]
		atlas.picture(canvas, "gameIcon:attr_%d" % [1, 4, 10][i], Rect2(407, 325 + i * 59, 53, 53))
		text(canvas, Vector2(470, 367 + i * 59), label, 36)
		text(canvas, Vector2(725, 367 + i * 59), str(roundi(current.wall_max)) if i == 0 else "0", 40)
	var bonuses = ["造成的黑暗伤害+0%", "[远程]攻击力+0%", "[法师]攻击力+0%", "[亡灵]防御力+0%", "[恶魔]防御力+0%", "[恶魔]攻击力+0%", "[刺客]生命值+0%"]
	var tags = [0, 0, 2, 8, 9, 9, 10]
	for i in range(bonuses.size()):
		var y = 630 + i * 92
		canvas.draw_rect(Rect2(65, y, 840, 87), Color(0, 0, 0, 0.63))
		var x = 96
		if tags[i] > 0:
			atlas.picture(canvas, "gameIcon:heroType%d" % tags[i], Rect2(x, y + 12, 52, 52))
			x += 73
		text(canvas, Vector2(x, y + 55), bonuses[i], 37)

func draw_hero(canvas: CanvasItem) -> void:
	if hero.is_empty():
		return
	var definition = catalog.record("heroes", int(hero.template))
	canvas.draw_rect(Rect2(0, 0, 960, 735 if expanded else 391), Color(0, 0, 0, 0.57))
	for i in range(definition.tags.size()):
		atlas.picture(canvas, definition.tags[i].res, Rect2(20 + i * 62, 20, 54, 54))
	text(canvas, Vector2(145, 66), hero.name, 40)
	text(canvas, Vector2(442, 64), "等级：%d" % int(catalog.baseline().hero_level), 38)
	var skills: Array = []
	for id in definition.initial_options:
		var option = catalog.record("options", int(id))
		if not option.icon_res.is_empty() and not skills.has(option.icon_res):
			skills.append(option.icon_res)
	for i in range(mini(4, skills.size())):
		canvas.draw_circle(Vector2(685 + i * 71, 48), 32, Color("999999"))
		atlas.picture(canvas, skills[i], Rect2(653 + i * 71, 16, 64, 64))
	for i in range(9):
		var x = 37 + i * 98
		atlas.picture(canvas, "gem:mpt", Rect2(x, 94, 94, 94))
		atlas.picture(canvas, "gem:5_0", Rect2(x + 20, 115, 54, 53))
	for i in range(3):
		var key = [1, 4, 10][i]
		var x = [35, 453, 696][i]
		canvas.draw_rect(Rect2(x, 216, [388, 209, 210][i], 53), Color(0, 0, 0, 0.6))
		atlas.picture(canvas, "gameIcon:attr_%d" % key, Rect2(x, 215, 61, 61))
		text(canvas, Vector2(x + 83, 260), str(roundi(hero.attributes[str(key)])), 44)
	if definition.has("element"):
		text(canvas, Vector2(35, 370), "%s · %s · %s · 动作后间隔%s秒" % [definition.element, "前排" if definition.front else "后排",
			"近战" if definition.front else "远程", str(definition.attack_delay_ms / 1000.0)], 28)
	if expanded:
		for col in range(EXTRA_ATTRIBUTES.size()):
			for row in range(EXTRA_ATTRIBUTES[col].size()):
				var id = EXTRA_ATTRIBUTES[col][row]
				var x = 63 + col * 212
				var y = 406 + row * 56
				atlas.picture(canvas, "gameIcon:attr_%d" % id, Rect2(x, y, 50, 50))
				text(canvas, Vector2(x + 58, y + 41), str(roundi(hero.attributes[str(id)])), 40)
	var rect = Rect2(835, 632 if expanded else 292, 80, 80)
	if expanded:
		canvas.draw_set_transform(rect.get_center(), PI)
		atlas.picture(canvas, "map:arrow2", Rect2(-40, -40, 80, 80))
		canvas.draw_set_transform(Vector2.ZERO)
	else:
		atlas.picture(canvas, "map:arrow2", rect)
