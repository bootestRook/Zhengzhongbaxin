extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Rng = preload("res://src/foundation/rng_set.gd")

func world(seed_value: int = 17, heroes: Array = [1, 2, 4, 13, 17]):
	var c = Catalog.new()
	assert(c.load_default().is_empty())
	var w = Session.new(c)
	w.start(seed_value)
	for hero_id in heroes:
		w.factory.add_hero(hero_id)
	w.phase = "playing"
	w.offers.clear()
	w.pending.clear()
	return w

func run(test) -> void:
	for count in range(1, 5):
		var w = world()
		w.rules.chest_reward_weights = [0, 0, 0, 0]
		w.rules.chest_reward_weights[count - 1] = 1
		var before: Dictionary = w.selected.duplicate()
		var time: int = w.time_ms
		w.loot.enqueue("elite")
		w.loot.advance()
		test.assert_equal(w.phase, "reward", "automatic opening uses its own phase")
		test.assert_equal(w.loot.current.requested, count, "configured count is decided before the terms")
		test.assert_equal(w.loot.current.items.size(), count, "all four nonzero reward counts are supported")
		var ids: Array = []
		for item in w.loot.current.items:
			ids.append(item.id)
			test.assert_equal(w.selected[str(item.id)], int(before.get(str(item.id), 0)) + 1, "reward modifies the real upgrade state exactly once")
			test.assert_true(w.units[item.owner].upgrades.has(item.id), "reward reaches its recruited owner's real ability")
			test.assert_equal(item.description, w.catalog.record("options", item.id).description, "awards retain exact original copy")
		test.assert_equal(ids.size(), _unique(ids).size(), "one chest never repeats the same term")
		w.step()
		test.assert_equal(w.time_ms, time, "reward animation freezes the logical battle clock")
		var random_state: Dictionary = w.rng.snapshot()
		var history: Array = w.history.duplicate(true)
		test.assert_equal(w.submit("choose", {"index": 0}), "当前无法选择", "old card confirmation cannot apply a reward again")
		w.submit("refresh")
		test.assert_equal(w.rng.snapshot(), random_state, "irrelevant input cannot reroll the rewards")
		test.assert_equal(w.history, history, "reward history is committed once before presentation")
		var id: int = w.loot.current.id
		test.assert_equal(w.submit("reward_close", {"id": id}), "", "matching completion resumes battle")
		test.assert_equal(w.submit("reward_close", {"id": id}), "奖励已关闭", "repeated completion cannot award twice")
		test.assert_equal(w.history, history, "closing does not apply the terms again")
		w.dispose()
	_counts_and_replay(test)
	_pool_edges(test)
	_queue_and_deaths(test)
	_final_boss(test)

func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if not result.has(value):
			result.append(value)
	return result

func _counts_and_replay(test) -> void:
	var a = world(53)
	var b = world(53)
	var reference = Rng.new(53)
	var rows: Array = []
	for i in range(4):
		rows.append({"count": i + 1, "weight": a.rules.chest_reward_weights[i]})
	var expected: int = reference.stream("defense.loot").choose_weighted(rows).count
	a.loot.enqueue("elite")
	a.loot.advance()
	test.assert_equal(a.loot.current.requested, expected, "the first loot RNG operation determines count")
	b.loot.enqueue("elite")
	b.loot.advance()
	test.assert_equal(a.loot.snapshot(), b.loot.snapshot(), "same seed reproduces count, terms and owners")
	test.assert_equal(a.rng.snapshot(), b.rng.snapshot(), "presentation does not enter the gameplay random sequence")
	a.dispose()
	b.dispose()
	var counts = [0, 0, 0, 0]
	var rng = reference.stream("count.distribution")
	for i in range(20000):
		counts[int(rng.choose_weighted(rows).count) - 1] += 1
	for i in range(4):
		test.assert_true(absf(float(counts[i]) / 20000 - [0.5, 0.3, 0.15, 0.05][i]) < 0.02, "count weights produce the intended distribution")
	print("[ROULETTE COUNTS] ", counts)

func _pool_edges(test) -> void:
	var w = world(81, [1])
	w.rules.chest_reward_weights = [0, 0, 0, 1]
	w.choices.options = {"201": w.catalog.record("options", 201)}
	w.loot.enqueue("elite")
	w.loot.advance()
	test.assert_equal(w.loot.current.requested, 4, "count still rolls before pool exhaustion")
	test.assert_equal(w.loot.current.items.size(), 1, "small pool awards every available unique term")
	w.loot.close(w.loot.current.id)
	var before: Dictionary = w.rng.snapshot()
	w.loot.enqueue("elite")
	w.loot.advance()
	test.assert_equal(w.phase, "reward", "exhausted library still pauses for the guaranteed drop")
	test.assert_true(w.loot.current.items.is_empty() and w.loot.current.source == "elite", "exhausted library retains its real drop source without fabricating terms")
	test.assert_equal(w.rng.snapshot(), before, "empty pool does not consume an unreachable award roll")
	w.loot.close(w.loot.current.id)
	test.assert_equal(w.phase, "playing", "empty-library notice closes normally")
	w.dispose()
	w = world(17, [2])
	w.rules.chest_reward_weights = [0, 0, 0, 1]
	w.choices.options = {}
	for id in [200302, 200303, 200308]:
		w.choices.options[str(id)] = w.catalog.record("options", id)
	w.loot.enqueue("elite")
	w.loot.advance()
	var terms: Array = w.loot.current.items.map(func(item): return item.id)
	test.assert_equal(terms.size(), 3, "sequential grants can unlock a remaining prerequisite term")
	test.assert_equal(terms.back(), 200308, "both parents are applied before the dependent term")
	w.loot.close(w.loot.current.id)
	w.loot.enqueue("elite")
	w.loot.advance()
	test.assert_equal(w.loot.current.items.size(), 1, "a two-rank term remains available in a later chest")
	test.assert_equal(w.selected["200302"], 2, "a later chest respects the exact repeat cap")
	w.loot.close(w.loot.current.id)
	w.loot.enqueue("elite")
	w.loot.advance()
	test.assert_true(w.loot.current.items.is_empty(), "maxed terms produce a truthful exhausted-library notice")
	w.dispose()

func _queue_and_deaths(test) -> void:
	var w = world()
	w.rules.chest_reward_weights = [1, 0, 0, 0]
	w.loot.enqueue("elite")
	w.loot.enqueue("elite")
	w.paused = true
	w.loot.advance()
	test.assert_equal(w.phase, "playing", "user pause defers the automatic reward")
	w.paused = false
	w.loot.advance()
	var first: int = w.loot.current.id
	w.loot.close(first)
	test.assert_true(w.phase == "reward" and w.loot.current.id != first, "multiple simultaneous drops are processed in order")
	var second: int = w.loot.current.id
	test.assert_equal(w.loot.close(first), "奖励已关闭", "late completion of the previous reward cannot close the next one")
	test.assert_equal(w.loot.current.id, second, "next queued reward remains visible")
	w.loot.close(second)
	test.assert_equal(w.phase, "playing", "last reward resumes the normal run")
	var enemy = w.factory.create("enemy", 101, Vector2(800, 690), 2)
	var rng_before: Dictionary = w.rng.snapshot()
	w.damage.defeat(enemy, {})
	test.assert_true(w.loot.queue.is_empty(), "ordinary monster deaths never trigger roulette")
	test.assert_equal(w.rng.snapshot(), rng_before, "ordinary deaths consume no loot probability roll")
	var elite = w.factory.create("elite", 101, Vector2(800, 690), 2)
	w.damage.defeat(elite, {})
	w.damage.defeat(elite, {})
	test.assert_equal(w.loot.queue.size(), 1, "one real elite death guarantees exactly one reward")
	w.step()
	test.assert_equal(w.phase, "reward", "the next safe battle boundary opens the reward without pickup input")
	test.assert_equal(w.loot.current.source, "elite", "elite source survives the queue and snapshot")
	w.finish(false)
	test.assert_true(w.loot.current.is_empty() and w.loot.queue.is_empty(), "ending clears queued and current rewards")
	w.start(53)
	test.assert_true(w.loot.current.is_empty() and w.loot.queue.is_empty(), "new run cannot inherit old rewards")
	w.factory.add_hero(1)
	w.phase = "playing"
	w.loot.drop({"kind": "elite"})
	test.assert_equal(w.loot.queue.size(), 1, "elite drops are guaranteed without a probability setting")
	for entry in w.level.encounters:
		w.loot.drop({"kind": entry.kind})
	test.assert_equal(w.loot.queue.size(), 1 + w.level.encounters.size(), "configured special rows guarantee their rewards")
	if not w.level.encounters.is_empty():
		test.assert_equal(w.loot.queue.back().source, w.level.encounters.back().kind, "special source is recorded in its ticket")
	w.dispose()

func _final_boss(test) -> void:
	var w = world()
	var entry = {"id": 114, "row_id": 900, "kind": "boss", "wave": 14, "hp_multiplier": 1.0, "atk_multiplier": 1.0, "health_bars": 1}
	var boss = w.factory.create("boss", 114, Vector2(800, 690), 2, 0, entry)
	boss.encounter_id = "test:900:0"
	boss.encounter_row_id = 900
	w.damage.defeat(boss, {})
	w.step()
	test.assert_true(w.phase == "reward" and w.loot.current.source == "boss", "configured boss death opens a boss reward")
	test.assert_true(w.result.is_empty() and not w.won, "reward is not committed underneath the reward")
	var time: int = w.time_ms
	w.step()
	test.assert_equal(w.time_ms, time, "special reward pauses the battle too")
	w.loot.close(w.loot.current.id)
	test.assert_true(w.phase == "playing", "closing a configured reward resumes the battle")
	test.assert_true(w.loot.queue.is_empty() and w.loot.current.is_empty(), "closing clears the completed reward state")
	w.dispose()
