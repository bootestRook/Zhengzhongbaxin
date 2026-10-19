extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var w = Session.new(catalog)
	w.level_id = 5
	var is_fire = not OS.get_cmdline_user_args().is_empty()
	w.start(81 if is_fire else 6)
	for hid in ([1, 2, 4, 13, 17] if is_fire else [4]):
		w.factory.add_hero(hid)
	w.phase = "playing"
	var hero: Dictionary = w.units[w.heroes[0]]
	var last_flip: Dictionary = {"at": -1000}
	var rows: Array = []
	for tick in range(7500):
		if w.phase == "choice":
			w.submit("choose", {"index": 0})
		if w.phase != "playing":
			break
		var old = {"pos": hero.pos, "facing": hero.facing, "target": hero.target, "dead": hero.dead,
			"charge": w.missiles.any(func(p): return p.owner == hero.id and p.kind in [29, 30])}
		var old_target: Dictionary = w.units.get(hero.target, {})
		old.target_pos = old_target.get("pos", Vector2.ZERO)
		w.step()
		if old.dead or hero.dead or hero.facing == old.facing:
			continue
		var target: Dictionary = w.units.get(hero.target, {})
		var row = {"at": w.time_ms, "from": str(old.pos), "pos": str(hero.pos), "target": hero.target,
			"old_target": old.target, "target_from": str(old.target_pos), "target_pos": str(target.get("pos", Vector2.ZERO)),
			"facing": hero.facing, "charge": old.charge, "action": hero.action}
		row.charge_skills = w.missiles.filter(func(p): return p.owner == hero.id and p.kind in [29, 30]).map(func(p): return {"skill": p.skill.__id__, "start": p.start, "end": p.charge_end})
		if hero.target > 0 and hero.target == old.target and w.time_ms - last_flip.at <= 48:
			rows.append({"previous": last_flip, "current": row})
		last_flip = row
	var path = "facing_fire_probe.json" if is_fire else "facing_probe.json"
	FileAccess.open("res://validation/defense/five_hero_ai_audit/" + path, FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("[FACING] ", JSON.stringify(rows))
	w.dispose()
	quit()
