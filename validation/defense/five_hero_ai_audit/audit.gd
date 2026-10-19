extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Test = preload("res://tests/test_support.gd")
const HEROES = [1, 2, 4, 13, 17]
const MONSTERS = [106, 112, 103, 107, 113]
const OUT = "res://validation/defense/five_hero_ai_audit/"
var catalog
var test = Test.new()
var report = {"contracts": [], "duels": [], "battles": [], "assertions": 0, "failures": []}

func _initialize() -> void:
	catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "load current definitions")
	for hid in HEROES:
		contracts(hid)
		for template in MONSTERS:
			for x in [600, 1000]:
				duel(hid, template, x)
		print("[DUELS DONE] ", hid)
		save_report()
	for hid in HEROES:
		for seed_value in [6, 81]:
			battle([hid], seed_value)
	for seed_value in [1, 6, 81]:
		battle(HEROES, seed_value)
	save_report()
	print("[AUDIT COMPLETE] assertions=", test.assertions, " failures=", test.failures)
	quit(0 if test.failures.is_empty() else 1)

func fixture(hid: int):
	var w = Session.new(catalog)
	w.level_id = 5
	w.start(81)
	w.spawn_wave = 20
	w.stage = 19
	w.phase = "playing"
	w.factory.add_hero(hid)
	return w

func contracts(hid: int) -> void:
	var w = fixture(hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	for i in range(2200):
		w.step()
		if not hero.entering:
			break
	test.assert_true(hero.back_lock and not hero.entering, "hero %d settles into formation" % hid)
	var row = {"hero": hid, "name": hero.name, "front": hero.front, "speed": U.stat(hero, 17), "range": U.stat(hero, 26), "formation_ms": w.time_ms}
	var first: Dictionary = w.factory.create("enemy", 106, hero.pos + Vector2(-40, -40), 2)
	w.space.rebuild()
	test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), first.id, "hero %d acquires nearby enemy" % hid)
	first.hidden_until = w.time_ms + 100000
	w.targets.score_cache.clear()
	test.assert_true(w.ai.choose_enemy(hero).is_empty(), "hero %d ignores hidden enemy" % hid)
	first.hidden_until = 0
	w.damage.defeat(first, {})
	w.targets.score_cache.clear()
	test.assert_true(w.ai.choose_enemy(hero).is_empty(), "hero %d ignores dead enemy" % hid)
	w.dispose()

	w = fixture(hid)
	hero = w.units[w.heroes[0]]
	var enemy = w.factory.create("enemy", 106, hero.pos + Vector2(0, -40), 2)
	enemy.busy_until = 100000
	enemy.core.attributes.set_value("1", 1000000)
	enemy.core.attributes.set_value("hp", 1000000)
	for i in range(500):
		w.step()
	row.entry_damage = hero.stats.damage
	row.entry_still_entering = hero.entering
	test.assert_true(hero.stats.damage > 0 and hero.entering, "hero %d deals damage while entering" % hid)
	w.damage.defeat(enemy, {})
	for i in range(2400):
		w.step()
		if hero.back_lock and not hero.entering:
			break
	row.returned = hero.back_lock and not hero.entering
	row.released_target = hero.target == 0
	test.assert_true(row.returned and row.released_target, "hero %d releases dead target and returns" % hid)
	w.dispose()

	if not row.front:
		w = fixture(hid)
		hero = w.units[w.heroes[0]]
		hero.entering = false
		hero.skills.clear()
		hero.pos = Vector2(800, 850)
		hero.attack_at = 1000
		enemy = w.factory.create("enemy", 106, Vector2(800, 800), 2)
		enemy.busy_until = 100000
		w.space.rebuild()
		var before: Vector2 = hero.pos
		w.ai.tick()
		row.cooldown_returns = hero.pos.y > before.y
		test.assert_true(row.cooldown_returns, "hero %d returns between shots when home covers enemy" % hid)
		enemy.pos = Vector2(800, 450)
		before = hero.pos
		w.targets.score_cache.clear()
		w.ai.recover_firing_position(hero, enemy)
		row.holds_when_home_out_of_range = hero.pos == before
		test.assert_true(row.holds_when_home_out_of_range, "hero %d does not retreat beyond firing range" % hid)
		w.dispose()
	report.contracts.append(row)
	print("[CONTRACT] ", JSON.stringify(row))

func tracker() -> Dictionary:
	return {"action_change": -1000, "facing_change": -1000, "last_rapid": -1000, "rapid_chain": 0,
		"rapid_idle": 0, "rapid_bursts": 0, "rapid_flips": 0, "locked_moves": 0, "walk_restarts": 0,
		"movement": 0.0, "samples": []}

func before(hero: Dictionary) -> Dictionary:
	return {"pos": hero.pos, "action": hero.action, "action_at": hero.action_at, "until": hero.action_until,
		"target": hero.target, "dead": hero.dead, "facing": hero.facing, "forced": hero.has("forced_motion")}

func observe(w, hero: Dictionary, old: Dictionary, m: Dictionary) -> void:
	if old.dead or hero.dead:
		m.rapid_chain = 0
		return
	var delta: Vector2 = hero.pos - old.pos
	m.movement += delta.length()
	if old.action in ["attack", "skill", "skill2"] and w.time_ms < old.until and delta.length() > 0.01 and not old.forced and not hero.has("forced_motion"):
		m.locked_moves += 1
	if hero.action == old.action and hero.action == "walk" and hero.action_at != old.action_at and hero.target == old.target:
		m.walk_restarts += 1
	if hero.action != old.action:
		var arrived = w.navigation.cell(hero.pos) == w.navigation.cell(hero.home)
		if old.action == "walk" and hero.action == "idle" and hero.target == old.target and hero.target > 0 and not arrived and w.time_ms - m.action_change <= 32:
			m.rapid_idle += 1
			m.rapid_chain = m.rapid_chain + 1 if w.time_ms - m.last_rapid <= 500 else 1
			m.last_rapid = w.time_ms
			if m.rapid_chain >= 3:
				m.rapid_bursts += 1
			if m.samples.size() < 12:
				var target: Dictionary = w.units.get(hero.target, {})
				m.samples.append({"time": w.time_ms, "pos": str(hero.pos), "target": hero.target, "target_pos": str(target.get("pos", Vector2.ZERO)), "cooldown": hero.attack_at - w.time_ms})
		m.action_change = w.time_ms
	if hero.facing != old.facing:
		if hero.target > 0 and hero.target == old.target and w.time_ms - m.facing_change <= 48:
			m.rapid_flips += 1
		m.facing_change = w.time_ms

func duel(hid: int, template: int, x: int) -> void:
	var w = fixture(hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.pos = hero.home
	var enemy = w.factory.create("enemy", template, Vector2(x, 800), 2)
	for u in [hero, enemy]:
		u.core.attributes.set_value("1", 1000000)
		u.core.attributes.set_value("hp", 1000000)
	var m = tracker()
	for tick in range(1500):
		var old = before(hero)
		w.step()
		observe(w, hero, old, m)
	var row = {"hero": hid, "template": template, "x": x, "damage": hero.stats.damage, "hits": hero.hits,
		"attacks": hero.attacks, "metrics": m, "diagnostics": w.diagnostics.duplicate(true)}
	row.summon_hits = 0
	row.summon_blocks = 0
	for unit: Dictionary in w.units.values():
		if unit.owner == hero.id:
			row.summon_hits += unit.hits
			if U.stat(unit, 3) > 0:
				row.summon_blocks += 1
	test.assert_true(hero.stats.damage > 0, "hero %d damages moving monster %d at X%d" % [hid, template, x])
	test.assert_equal(m.locked_moves, 0, "hero %d has no movement during locked attack/cast" % hid)
	test.assert_true(w.diagnostics.is_empty(), "hero %d duel has no skill diagnostic" % hid)
	report.duels.append(row)
	w.dispose()

func battle(heroes: Array, seed_value: int) -> void:
	var w = Session.new(catalog)
	w.level_id = 5
	w.start(seed_value)
	for hid in heroes:
		w.factory.add_hero(hid)
	w.phase = "playing"
	var metrics: Dictionary = {}
	for tick in range(7500):
		if w.phase == "choice":
			w.submit("choose", {"index": 0})
		if w.phase != "playing":
			break
		var old: Dictionary = {}
		for id in w.heroes:
			var hero: Dictionary = w.units[id]
			if not HEROES.has(hero.template):
				continue
			if not metrics.has(hero.template):
				metrics[hero.template] = tracker()
			old[id] = before(hero)
		w.step()
		for id in old:
			var hero: Dictionary = w.units[id]
			observe(w, hero, old[id], metrics[hero.template])
	var roster: Array = []
	for id in w.heroes:
		var hero: Dictionary = w.units[id]
		roster.append({"hero": hero.template, "damage": hero.stats.damage, "hits": hero.hits, "deaths": hero.death_count})
	var row = {"initial": heroes, "seed": seed_value, "time": w.time_ms, "wave": w.spawn_wave, "roster": roster, "metrics": metrics, "diagnostics": w.diagnostics.duplicate(true)}
	report.battles.append(row)
	print("[BATTLE DONE] initial=", heroes, " seed=", seed_value, " time=", w.time_ms)
	save_report()
	w.dispose()

func save_report() -> void:
	report.assertions = test.assertions
	report.failures = test.failures
	FileAccess.open(OUT + "audit.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
