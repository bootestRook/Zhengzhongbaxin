extends SceneTree

func _initialize() -> void:
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	catalog.load_default()
	var rows: Array = []
	for hid in catalog.available_heroes():
		var w = preload("res://src/features/defense/domain/defense_session.gd").new(catalog)
		w.start(89)
		w.factory.add_hero(hid)
		var hero: Dictionary = w.units[w.heroes[0]]
		var skills: Dictionary = {}
		for sid in hero.skills:
			skills[str(sid)] = hero.skills[sid].data.duplicate(true)
		rows.append({"hero": hid, "attributes": w.snapshot().heroes[0].attributes,
			"skills": skills, "passives": hero.passives.duplicate(true), "pending_bonus_choice": not w.pending.is_empty()})
		w.dispose()
	var file = FileAccess.open("res://validation/defense/battle_reaudit/hero_initial_values.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t") + "\n")
	print("[OK] initial runtime attributes and skill values: %d heroes" % rows.size())
	quit()
