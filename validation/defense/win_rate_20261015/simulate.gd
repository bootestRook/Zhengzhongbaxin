extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Rng = preload("res://src/foundation/rng_set.gd")
const HERO_ORDER = [1, 4, 2, 13, 17]

func _initialize() -> void:
	var args = OS.get_cmdline_user_args()
	assert(args.size() == 5, "levels_csv count first_seed policy output_path")
	var catalog = Catalog.new()
	assert(catalog.load_default().is_empty())
	var output = FileAccess.open(args[4], FileAccess.WRITE)
	assert(output != null)
	for part in args[0].split(","):
		var level_id = int(part)
		for offset in range(int(args[1])):
			var started = Time.get_ticks_msec()
			var result = run_match(catalog, level_id, int(args[2]) + offset, args[3])
			result["elapsed_ms"] = Time.get_ticks_msec() - started
			output.store_line(JSON.stringify(result))
			output.flush()
			print("[RUN] ", JSON.stringify(result))
	output.close()
	quit()

func run_match(catalog, level_id: int, run_seed: int, policy: String) -> Dictionary:
	assert(policy in ["recruit_quality", "random"])
	var policy_rng = Rng.new(run_seed).stream("balance.policy")
	var world = Session.new(catalog)
	assert(world.submit("select_level", {"level": level_id}).is_empty())
	assert(world.submit("start", {"seed": run_seed}).is_empty())
	var initial_refreshes: int = world.refresh_left
	var opened = 0
	var iterations = 0
	while iterations < 60000 and world.phase != "result":
		iterations += 1
		if world.phase == "choice":
			choose(world, catalog, policy, policy_rng)
		if world.phase != "playing":
			continue
		if not world.boxes.is_empty():
			assert(world.submit("box", {"id": world.boxes[0].id}).is_empty())
			opened += 1
			continue
		world.step()
		world.drain_events()
	var heroes: Array = []
	for id in world.heroes:
		var hero: Dictionary = world.units[id]
		heroes.append({"id": hero.template, "upgrades": hero.upgrades.duplicate(), "stats": hero.stats.duplicate()})
	var result = {"level": level_id, "seed": run_seed, "policy": policy, "finished": world.phase == "result",
		"won": world.won, "time_ms": world.time_ms, "wave": world.spawn_wave, "stage": world.stage,
		"wall": world.wall_hp, "kills": world.kills, "bosses": world.bosses_dead, "deaths": world.deaths,
		"heroes": heroes, "history": world.history.duplicate(true), "boxes_opened": opened,
		"refreshes_used": initial_refreshes - world.refresh_left, "diagnostics": world.diagnostics.duplicate()}
	world.dispose()
	return result

func choose(world, catalog, policy: String, policy_rng) -> void:
	if policy == "random":
		assert(world.submit("choose", {"index": policy_rng.next_int(world.offers.size())}).is_empty())
		return
	# A fixed, reproducible recruitment-first policy; no inspection of future rolls.
	while world.choice_kind == "upgrade" and world.heroes.size() < world.rules.hero_limit and world.refresh_left > 0:
		if world.offers.any(func(item): return item.kind == "hero"):
			break
		assert(world.submit("refresh").is_empty())
	var pick = 0
	var best = -100000
	for index in range(world.offers.size()):
		var item: Dictionary = world.offers[index]
		var score: int
		if item.kind == "hero":
			score = 10000 - HERO_ORDER.find(int(item.id)) * 100
		else:
			var option = catalog.record("options", int(item.id))
			score = int(str(option.icon).split(":")[1]) * 100
		if score > best:
			best = score
			pick = index
	assert(world.submit("choose", {"index": pick}).is_empty())
