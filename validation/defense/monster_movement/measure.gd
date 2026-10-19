extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const OUT = "res://validation/defense/monster_movement/"

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var catalog = Catalog.new()
	assert(catalog.load_default().is_empty())
	var results = {"march": march(catalog), "profiles": [], "matches": []}
	for count in [100, 300]:
		results.profiles.append(profile(catalog, count))
		print("[PROFILE] ", JSON.stringify(results.profiles.back()))
	for level in [1, 2]:
		for run_seed in [6, 17, 53]:
			results.matches.append(match_run(catalog, level, run_seed))
			print("[MATCH] ", JSON.stringify(results.matches.back()))
	var file = FileAccess.open(OUT + args[0] + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "\t") + "\n")
	print("[MARCH] ", JSON.stringify(results.march))
	quit()

func march(catalog) -> Array:
	var rows: Array = []
	for start_x in [350, 575, 800, 1025, 1250]:
		var w = Session.new(catalog)
		w.start(71)
		w.spawn_wave = 1
		var enemy = w.factory.create("enemy", 101, Vector2(start_x, 10), 2)
		for frame in range(4000):
			w.time_ms += 16
			w.space.rebuild()
			w.navigation.rebuild()
			w.ai.tick()
			if enemy.pos.y >= w.combat.world.warning_y:
				break
		rows.append({"start_x": start_x, "x_at_warning": enemy.pos.x, "y": enemy.pos.y,
			"time_ms": w.time_ms, "target": enemy.target})
		w.dispose()
	return rows

func profile(catalog, count: int) -> Dictionary:
	var w = Session.new(catalog)
	w.start(71)
	w.spawn_wave = 1
	for i in range(count):
		var enemy = w.factory.create("enemy", 101, Vector2(370 + i % 20 * 44, 300 + i / 20 * 30), 2)
		enemy.skills.clear()
	var timings: Array = []
	for frame in range(500):
		var started = Time.get_ticks_usec()
		w.time_ms += 16
		w.space.rebuild()
		w.navigation.rebuild()
		w.ai.tick()
		w.snapshot()
		w.drain_events()
		timings.append((Time.get_ticks_usec() - started) / 1000.0)
	timings.sort()
	var result = {"count": count, "step_snapshot_mean_ms": timings.reduce(func(a, b): return a + b, 0.0) / timings.size(),
		"p95_ms": timings[int(timings.size() * 0.95)]}
	w.dispose()
	return result

func match_run(catalog, level: int, run_seed: int) -> Dictionary:
	var w = Session.new(catalog)
	w.submit("select_level", {"level": level})
	w.submit("start", {"seed": run_seed})
	var started = Time.get_ticks_msec()
	var samples: Array = []
	var sample_at = 0
	for frame in range(60000):
		advance_choice(w)
		if w.phase == "result":
			break
		w.step()
		w.drain_events()
		if w.time_ms >= sample_at:
			sample_at = w.time_ms + 4000
			var xs: Array = []
			for u: Dictionary in w.units.values():
				if u.side == 2 and not u.dead and u.pos.y < 800:
					xs.append(u.pos.x)
			if xs.size() >= 5:
				xs.sort()
				samples.append({"time_ms": w.time_ms, "count": xs.size(),
					"width": xs.back() - xs.front(), "middle_fraction": xs.filter(func(x): return absf(x - 800) < 150).size() / float(xs.size())})
	var result = {"level": level, "seed": run_seed, "finished": w.phase == "result", "won": w.won,
		"time_ms": w.time_ms, "wave": w.spawn_wave, "wall": w.wall_hp, "kills": w.kills,
		"deaths": w.deaths, "encounters": w.encounters_cleared.size(), "diagnostics": w.diagnostics.duplicate(),
		"elapsed_ms": Time.get_ticks_msec() - started, "samples": samples}
	w.dispose()
	return result

func advance_choice(w) -> void:
	if w.phase == "reward":
		assert(w.submit("reward_close", {"id": w.loot.current.id}).is_empty())
	if w.phase != "choice":
		return
	# Match the established legal full-run fixture, without peeking at future rolls.
	var preferred = [1, 10, 9, 5, 3, 11, 17, 2, 4, 14, 8, 6, 7, 15, 16, 12, 13]
	if w.choice_kind == "hero" and w.refresh_left > 0 and not w.offers.any(func(item): return item.id in [1, 10, 9, 5]):
		assert(w.submit("refresh").is_empty())
	var pick = 0
	var best = -100000
	for index in range(w.offers.size()):
		var item: Dictionary = w.offers[index]
		var hero_id = int(item.id) if item.kind == "hero" else int(w.units[item.owner].template)
		var score = 1000 - preferred.find(hero_id) * 40
		if item.kind == "hero":
			score += 2000
		else:
			score += int(str(w.catalog.record("options", int(item.id)).icon).split(":")[1])
		if score > best:
			best = score
			pick = index
	assert(w.submit("choose", {"index": pick}).is_empty())
