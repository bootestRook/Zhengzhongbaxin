extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	var error = catalog.load_default()
	if not error.is_empty():
		printerr(error)
		quit(1)
		return
	var w = preload("res://src/features/defense/domain/defense_session.gd").new(catalog)
	w.start(53)
	var minimum_y: Dictionary = {}
	for tick in range(60000):
		if w.phase == "result":
			break
		if w.phase == "reward":
			w.submit("reward_close", {"id": w.loot.current.id})
		if w.phase == "choice":
			choose(w)
		w.step()
		w.drain_events()
		for id in w.heroes:
			var hero: Dictionary = w.units[id]
			if hero.front and not hero.dead:
				minimum_y[hero.template] = minf(float(minimum_y.get(hero.template, 1600)), hero.pos.y)
	var result = {"seed": 53, "phase": w.phase, "won": w.won, "wave": w.spawn_wave,
		"time": w.time_ms, "encounters": w.encounters_cleared.duplicate(), "kills": w.kills, "wall_hp": w.wall_hp,
		"heroes": w.heroes.map(func(id): return {"hero": w.units[id].template, "stats": w.units[id].stats}),
		"front_minimum_y": minimum_y, "history": w.history.duplicate(true)}
	var file = FileAccess.open("res://validation/defense/range_targeting/legal_run.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	print("[LEGAL RANGE RUN] ", JSON.stringify(result))
	var passed: bool = w.won and w.spawn_wave == 20 and w.encounters_cleared.size() == 3 and w.heroes.size() == 5
	w.dispose()
	quit(0 if passed else 1)

func choose(w) -> void:
	var preferred = [1, 10, 9, 5, 3, 11, 17, 2, 4, 14, 8, 6, 7, 15, 16, 12, 13]
	if w.choice_kind == "hero" and w.refresh_left > 0 and not w.offers.any(func(item): return item.id in [1, 10, 9, 5]):
		w.submit("refresh")
	var pick = 0
	var best = -100000
	for index in range(w.offers.size()):
		var item: Dictionary = w.offers[index]
		var hid: int = int(item.id) if item.kind == "hero" else int(w.units[item.owner].template)
		var score = 1000 - preferred.find(hid) * 40
		if item.kind == "hero":
			score += 2000
		else:
			score += int(str(w.catalog.record("options", item.id).icon).split(":")[1])
		if score > best:
			best = score
			pick = index
	w.submit("choose", {"index": pick})
