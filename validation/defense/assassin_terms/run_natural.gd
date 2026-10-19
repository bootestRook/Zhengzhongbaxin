extends SceneTree

func _initialize() -> void:
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	assert(catalog.load_default().is_empty())
	var w = preload("res://src/features/defense/domain/defense_session.gd").new(catalog)
	var run_seed = 1
	while true:
		w.start(run_seed)
		if w.offers.any(func(item): return item.kind == "hero" and item.id == 17):
			break
		run_seed += 1
	for step in range(40000):
		if w.phase == "result":
			break
		if w.phase == "choice":
			var best = -1
			var score = -1
			for i in range(w.offers.size()):
				var item: Dictionary = w.offers[i]
				var value = 10
				if item.kind == "hero":
					value = 1000 if item.id == 17 else 500
				elif item.id in range(200501, 200509):
					value = 100 - [200502, 200506, 200501, 200508, 200503, 200505, 200504, 200507].find(item.id)
				if value > score:
					score = value
					best = i
			assert(w.submit("choose", {"index": best}).is_empty())
		else:
			for box in w.boxes.duplicate():
				if w.loot.open(box.id).is_empty():
					break
			w.step()
	var owner: Dictionary = {}
	for id in w.heroes:
		if w.units[id].template == 17:
			owner = w.units[id]
	var result = {"seed": run_seed, "phase": w.phase, "won": w.won, "wave": w.spawn_wave, "bosses": w.bosses_dead, "time_ms": w.time_ms, "wall_hp": w.wall_hp, "assassin_stats": owner.stats, "assassin_upgrades": owner.upgrades, "history": w.history}
	print("[ASSASSIN NATURAL] ", JSON.stringify(result))
	var valid = w.phase == "result" and owner.stats.damage > 0 and owner.upgrades.size() > 1
	w.dispose()
	quit(0 if valid else 1)
