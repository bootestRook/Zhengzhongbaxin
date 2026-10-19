extends SceneTree

const Lab = preload("res://src/features/defense/domain/lab/battle_lab.gd")
const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Files = preload("res://src/platform/lab_files.gd")
const Support = preload("res://tests/test_support.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test = Support.new()
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "current catalog loads")
	var input = Files.read_json("res://tests/lab_cases/04_ice.json")
	var rows: Array = []
	for seed in [1, 2, 3, 4, 5, 6, 7, 8, 53]:
		for combo in [false, true]:
			var config: Dictionary = input.value.config.duplicate(true)
			config.seed = seed
			config.units[0].terms = {"200403": 1, "200404": 1} if combo else {"200403": 1}
			var lab = Lab.new(catalog)
			test.assert_equal(lab.load_config(config), "", "legal ice setup")
			test.assert_equal(lab.submit("advance", {"ticks": 46}), "", "normal windup and actual skill emission")
			var arrows: Array = []
			for p in lab.world.missiles:
				arrows.append({"id": p.id, "start": p.start, "pos": [p.pos.x, p.pos.y], "direction": [p.direction.x, p.direction.y], "lane": p.skill.get("salvo_index", -1)})
			var same = 0
			for i in range(arrows.size()):
				for j in range(i):
					if arrows[i].pos == arrows[j].pos and arrows[i].direction == arrows[j].direction and arrows[i].start == arrows[j].start: same += 1
			test.assert_equal(arrows.size(), 4, "first volley is always four arrows")
			var pending = lab.world.skills.queue.any(func(e): return e.get("ice_combo", false))
			lab.submit("advance", {"ticks": 18})
			test.assert_true(lab.world.trace.filter(func(e): return e.type == "skill_combo").is_empty(), "no repeat before three hundred milliseconds")
			lab.submit("advance", {"ticks": 1})
			var extra = lab.world.missiles.filter(func(p): return p.start == 1040)
			test.assert_equal(extra.size(), 4 if pending else 0, "repeat volley arrives on first fixed step after three hundred ms")
			var repeat_events = lab.world.trace.filter(func(e): return e.type == "skill_combo")
			test.assert_equal(repeat_events.size(), 1 if pending else 0, "exactly one delayed repeat event")
			test.assert_equal(lab.submit("advance", {"ticks": 85}), "", "actual collision resolution")
			var data: Dictionary = lab.world.units[1].skills[20002].data.ice_arrows
			var hits = lab.world.trace.filter(func(e): return e.type == "damage" and e.get("source", 0) == 1 and e.get("actual", 0) > 0)
			var expected = (70.0 if combo else 60.0) * (2 if pending else 1)
			test.assert_equal(lab.inspect(1).stats.damage, expected, "each overlapping main arrow deals independent real damage")
			test.assert_equal(hits.size(), 2 if pending else 1, "independent primary hits")
			test.assert_equal(data.combo_chance, 50 if combo else 0, "source fifty-percent chance reaches skill instance")
			test.assert_true(lab.world.diagnostics.is_empty(), "no missing data")
			rows.append({"seed": seed, "combo_term": combo, "copies": data.copies, "chance": data.combo_chance, "first_cast_arrows": arrows,
				"overlapping_pairs": same, "extra_arrows": extra.size(), "repeat_events": repeat_events, "damage": lab.inspect(1).stats.damage, "hits": hits, "casts": lab.world.trace.filter(func(e): return e.type == "cast")})
			print("[ICE COMBO] seed=%d combo=%s first=%d extra=%d repeat=%s damage=%s" % [seed, combo, arrows.size(), extra.size(), repeat_events, lab.inspect(1).stats.damage])
			lab.dispose()
	var triggered = rows.filter(func(r): return r.combo_term and r.extra_arrows == 4)
	var missed = rows.filter(func(r): return r.combo_term and r.extra_arrows == 0)
	test.assert_true(not triggered.is_empty() and not missed.is_empty(), "natural chance produces both outcomes")
	for action in ["kill_owner", "kill_target", "clear", "reset"]:
		var config: Dictionary = input.value.config.duplicate(true)
		config.units[0].terms = {"200403": 1, "200404": 1}
		var lab = Lab.new(catalog)
		lab.load_config(config)
		lab.submit("advance", {"ticks": 46})
		test.assert_true(lab.world.skills.queue.any(func(e): return e.get("ice_combo", false)), "cancel fixture has a natural queued combo")
		match action:
			"kill_owner": lab.submit("kill", {"id": 1})
			"kill_target":
				lab.submit("survival", {"id": 2, "mode": "normal"})
				lab.submit("kill", {"id": 2})
			"clear": lab.submit("clear", {"scope": "all"})
			"reset": lab.submit("reset")
		lab.submit("advance", {"ticks": 20})
		test.assert_true(not lab.world.trace.any(func(e): return e.type == "skill_combo"), "canceled or invalid owner/target cannot emit delayed arrows: " + action)
		lab.dispose()
	var report = {"assertions": test.assertions, "failures": test.failures, "rows": rows, "runtime_fingerprint": Files.fingerprint(), "source_hashes": catalog._data.source_hashes}
	test.assert_equal(Files.write_json("res://validation/battle_lab/ice_combo/probe.json", report), "", "persist live evidence")
	for failure in test.failures: push_error("TEST FAILURE: " + failure)
	print("[ICE COMBO] assertions=%d failures=%d" % [test.assertions, test.failures.size()])
	quit(0 if test.failures.is_empty() else 1)
