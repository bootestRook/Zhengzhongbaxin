extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	var load_error = catalog.load_default()
	if not load_error.is_empty():
		printerr(load_error)
		quit(1)
		return
	var rows: Array = []
	for run_seed in [6, 17]:
		var w = Session.new(catalog)
		w.start(run_seed)
		# Controlled five-hero roster; health, damage, waves and upgrades are real.
		for hid in [4, 17, 1, 2, 13]:
			w.factory.add_hero(hid)
		w.offers.clear()
		w.phase = "playing"
		var heroes: Dictionary = {}
		for id in w.heroes:
			var hero: Dictionary = w.units[id]
			if hero.front:
				heroes[hero.template] = {"ticks": 0, "above_middle_ticks": 0, "min_y": 1600.0,
					"min_attack_y": 1600.0, "max_advance": 0.0, "attacks": 0, "damage": 0.0}
		for tick in range(7500):
			for pick in range(25):
				if w.phase == "choice":
					w.submit("choose", {"index": 0})
				elif w.phase == "reward":
					w.submit("reward_close", {"id": w.loot.current.id})
				else:
					break
			if w.phase in ["choice", "reward"]:
				printerr("Choice chain did not resolve")
				quit(1)
				return
			if w.phase != "playing":
				break
			w.step()
			w.drain_events()
			for id in w.heroes:
				var hero: Dictionary = w.units[id]
				if not hero.front or hero.dead:
					continue
				var row: Dictionary = heroes[hero.template]
				row.ticks += 1
				row.above_middle_ticks += int(hero.pos.y < 850)
				row.min_y = minf(row.min_y, hero.pos.y)
				row.max_advance = maxf(row.max_advance, hero.home.y - hero.pos.y)
				if hero.action == "attack":
					row.min_attack_y = minf(row.min_attack_y, hero.pos.y)
				row.attacks = hero.attacks
				row.damage = hero.stats.damage
		rows.append({"seed": run_seed, "time": w.time_ms, "wave": w.spawn_wave, "phase": w.phase,
			"wall_hp": w.wall_hp, "front_heroes": heroes})
		print("[GUARD PROBE] ", JSON.stringify(rows.back()))
		w.dispose()
	var args = OS.get_cmdline_user_args()
	var label: String = args[0] if not args.is_empty() else "after"
	assert(label in ["before", "after"])
	var file = FileAccess.open("res://validation/defense/guard_line/%s.json" % label, FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t") + "\n")
	quit()
