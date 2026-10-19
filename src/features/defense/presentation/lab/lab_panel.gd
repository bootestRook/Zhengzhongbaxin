extends RefCounted

const Inspector = preload("res://src/features/defense/domain/lab/lab_inspector.gd")
const Files = preload("res://src/platform/lab_files.gd")
const Text = preload("res://src/features/defense/presentation/lab/lab_text.gd")
var app
var preset_paths: Array = []
var last_selected: int = -1
var roster_ids: Array = []
var term_owner: int = -1
var term_ids: Array = []

func _init(owner) -> void: app = owner
func n(name: String): return app.get_node("%" + name)
func press(name: String, action: Callable) -> void: n(name).pressed.connect(action)
func send(action: String, payload: Dictionary = {}) -> void: app.dispatch(action, payload)
func pick(name: String) -> int: return n(name).get_selected_id()

func configure() -> void:
	var catalog = app.lab.catalog
	for id in catalog.available_heroes(): n("HeroChoice").add_item(catalog.record("heroes", id).name, id)
	for key in catalog.records("attributes"):
		n("AttributeChoice").add_item(catalog.record("attributes", int(key)).title, int(key))
	for key in catalog.records("statuses"):
		var d = catalog.record("statuses", int(key))
		n("StatusChoice").add_item("#%s  %s" % [key, Text.status_name(d)], int(key))
	n("MonsterSearch").text_changed.connect(func(_text): monsters())
	n("TermSearch").text_changed.connect(func(_text): terms())
	n("Units").item_selected.connect(func(index): send("select", {"id": int(n("Units").get_item_metadata(index))}))
	n("Terms").item_selected.connect(func(_index): term_detail())
	n("AttributeChoice").item_selected.connect(func(_index): attribute_value())
	press("AddHero", func(): send("add", {"kind": "hero", "template": pick("HeroChoice"), "pos": position()}))
	press("AddMonster", add_monsters)
	press("ClearEnemies", func(): send("clear", {"scope": "enemies"}))
	press("ClearSelected", func(): send("clear", {"scope": "selected"}))
	press("ClearAll", func(): send("clear", {"scope": "all"}))
	press("MoveSelected", func(): send("position", {"pos": position()}))
	press("AddTerm", func(): set_term(false))
	press("Prerequisites", func(): set_term(true))
	press("RemoveTerm", func(): set_term(false, true))
	press("ClearTerms", func(): send("term", {"clear": true}))
	press("ApplyMode", func(): send("configure", {"legal_terms": n("Legal").button_pressed}))
	press("ApplyAttribute", func(): send("attribute", scope({"attribute": str(pick("AttributeChoice")), "value": n("AttributeValue").value})))
	press("ApplyHP", func(): send("health", scope({"ratio": n("HPPercent").value / 100.0})))
	press("FullHP", func(): send("health", scope({"ratio": 1.0})))
	press("ApplySurvival", func(): send("survival", scope({"mode": ["normal", "immortal", "invulnerable"][n("Survival").selected]})))
	press("ApplyActions", func(): send("actions", scope({"move": n("Move").button_pressed, "attack": n("Attack").button_pressed, "skill": n("Skill").button_pressed})))
	press("Ready", func(): send("ready", scope()))
	press("Weaken", func(): send("weaken", scope()))
	press("Kill", func(): send("kill", scope({"source": pick("Killer")})))
	press("Revive", func(): send("revive"))
	press("ApplyShield", func(): send("shield", scope({"value": n("Shield").value})))
	press("AddStatus", func(): send("status", scope({"status": pick("StatusChoice"), "duration_ms": n("StatusDuration").value * 1000, "stacks": int(n("Stacks").value)})))
	press("ClearStatus", func(): send("clear_status", scope()))
	press("ApplyWall", func(): send("wall", {"hp": n("WallHP").value}))
	press("ApplyEnvironment", func(): send("configure", {"seed": int(n("Seed").value), "level": int(n("Level").value), "wave": int(n("Wave").value),
		"settings": {"spawn": n("AutoSpawn").button_pressed, "progression": n("Progression").button_pressed, "respawn": n("Respawn").button_pressed}}))
	for pair in [["LoadConfig", "config_load"], ["SaveConfig", "config_save"], ["SaveReplay", "replay_save"], ["Replay", "replay"], ["Report", "report"]]:
		press(pair[0], func(): app.open_file(pair[1]))
	preset_paths = Files.presets()
	for index in range(preset_paths.size()):
		var item = Files.read_json(preset_paths[index])
		n("Preset").add_item(item.get("value", {}).get("title", preset_paths[index].get_file()), index)
	press("LoadPreset", load_preset)
	monsters()

func position() -> Array: return [n("PosX").value, n("PosY").value]

func scope(value: Dictionary = {}) -> Dictionary:
	value["scope"] = ["selected", "enemies", "template"][n("Scope").selected]
	value["template"] = int(app.lab.inspect().get("template", 0))
	return value

func add_monsters() -> void:
	send("add", {"kind": ["enemy", "elite", "boss"][n("MonsterKind").selected], "template": pick("MonsterChoice"),
		"pos": position(), "count": int(n("Count").value), "layout": ["point", "row", "column", "circle", "grid", "random"][n("Layout").selected],
		"spacing": n("Spacing").value, "survival": ["normal", "immortal", "invulnerable"][n("SpawnSurvival").selected],
		"actions": {"move": not n("StaticTarget").button_pressed, "attack": not n("StaticTarget").button_pressed, "skill": not n("StaticTarget").button_pressed}})

func monsters() -> void:
	var previous = pick("MonsterChoice")
	n("MonsterChoice").clear()
	var index = 0
	var query: String = n("MonsterSearch").text.strip_edges()
	for key in app.lab.catalog.records("monsters"):
		var monster: Dictionary = app.lab.catalog.record("monsters", int(key))
		var title = str(monster.get("title", ""))
		if title.is_empty(): title = "未命名 " + str(monster.get("res", ""))
		var label = "%s  #%s  · %d技能" % [title, key, monster.get("skill", []).size()]
		if not query.is_empty() and not label.containsn(query): continue
		n("MonsterChoice").add_item(label, int(key))
		if int(key) == previous: n("MonsterChoice").select(index)
		index += 1
	n("AddMonster").disabled = index == 0

func terms() -> void:
	n("Terms").clear()
	term_ids.clear()
	var actor: Dictionary = app.lab.inspect()
	if actor.is_empty() or actor.kind != "hero":
		n("TermDescription").text = "请从战场或上方列表选择英雄。"
		return
	var query: String = n("TermSearch").text.strip_edges()
	for key in app.lab.catalog.records("options"):
		var term = app.lab.catalog.record("options", int(key))
		if not term.get("type", []).has(actor.template): continue
		if not query.is_empty() and not (term.title + " " + key + " " + term.description).containsn(query): continue
		var owned: int = actor.terms.count(int(key))
		var index: int = n("Terms").add_item("%s  %d/%d" % [term.title, owned, int(term.options_num)])
		n("Terms").set_item_metadata(index, int(key))
		term_ids.append(int(key))
	if not term_ids.is_empty(): n("Terms").select(0); term_detail()

func term_detail() -> void:
	var selection = n("Terms").get_selected_items()
	if selection.is_empty(): return
	var term = app.lab.catalog.record("options", int(n("Terms").get_item_metadata(selection[0])))
	n("TermDescription").text = "%s\n%s\n前置（全部）：%s  前置（任一）：%s\n运行编号：%d" % [term.title, term.description, str(term.get("premise1", [])), str(term.get("premise2", [])), term.id]

func set_term(prerequisites: bool, remove: bool = false) -> void:
	var selection = n("Terms").get_selected_items()
	if selection.is_empty(): return
	send("term", {"term": int(n("Terms").get_item_metadata(selection[0])), "count": 0 if remove else int(n("TermCount").value), "prerequisites": prerequisites})
	terms()

func attribute_value() -> void:
	for entry in app.lab.inspect().get("attributes", []):
		if int(entry.id) == pick("AttributeChoice"):
			n("AttributeValue").value = entry.base
			return

func load_preset() -> void:
	if not preset_paths.is_empty(): app.load_path(preset_paths[n("Preset").selected], false)

func reset_view() -> void:
	last_selected = -1
	roster_ids = [-1]
	var config: Dictionary = app.lab.recipe
	for pair in [["Seed", "seed"], ["Level", "level"], ["Wave", "wave"]]: n(pair[0]).value = config[pair[1]]
	n("Legal").set_pressed_no_signal(config.legal_terms)
	for pair in [["AutoSpawn", "spawn"], ["Progression", "progression"], ["Respawn", "respawn"]]:
		n(pair[0]).set_pressed_no_signal(config.settings[pair[1]])

func render() -> void:
	var rows = Inspector.roster(app.lab.world)
	var ids: Array = rows.map(func(row): return row.id)
	if ids != roster_ids:
		n("Units").clear()
		var previous = pick("Killer")
		n("Killer").clear()
		n("Killer").add_item("无归属（仅死亡触发）", 0)
		for row in rows:
			var index: int = n("Units").add_item("")
			n("Units").set_item_metadata(index, row.id)
			if row.kind == "hero":
				n("Killer").add_item(row.name + " #%d" % row.id, row.id)
				if row.id == previous: n("Killer").select(n("Killer").item_count - 1)
		roster_ids = ids
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		n("Units").set_item_text(index, Text.roster(row))
		if row.id == app.lab.selected_id: n("Units").select(index)
	var actor: Dictionary = app.lab.inspect()
	n("Selection").text = Text.summary(actor)
	if last_selected != app.lab.selected_id:
		last_selected = app.lab.selected_id
		terms()
		attribute_value()
		if not actor.is_empty():
			n("HPPercent").value = actor.hp / maxf(1, actor.max_hp) * 100
			n("PosX").value = actor.pos[0]
			n("PosY").value = actor.pos[1]
			n("Survival").select(["normal", "immortal", "invulnerable"].find(actor.survival))
			for pair in [["Move", "move"], ["Attack", "attack"], ["Skill", "skill"]]: n(pair[0]).set_pressed_no_signal(actor.actions[pair[1]])
	if n("Tabs").current_tab == 3: n("Details").text = Text.details(actor)
	if n("Tabs").current_tab == 4:
		n("Log").text = Text.log_text(app.lab.world.trace, n("LogFilter").text, app.lab.selected_id if n("OnlySelected").button_pressed else 0)
		n("LogInfo").text = "保留最近2000条，已丢弃%d条；最近逻辑步 %.2fms，峰值 %.2fms" % [app.lab.world.trace_dropped, app.lab.world.step_us / 1000.0, app.lab.world.peak_step_us / 1000.0]
	for entry in actor.get("attributes", []):
		if int(entry.id) == pick("AttributeChoice"): n("AttributeReadback").text = "基础 %s  →  最终 %s（包含现有词条与状态）" % [entry.base, entry.value]
