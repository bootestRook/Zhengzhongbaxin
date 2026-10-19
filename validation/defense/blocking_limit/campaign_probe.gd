extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var rows: Array = []
	for run_seed in [1, 81]:
		var w = Session.new(catalog)
		w.start(run_seed)
		for id in [4, 2, 17, 5, 13]:
			w.factory.add_hero(id)
		w.phase = "playing"
		w.offers.clear()
		var overflow_ticks := 0
		var stale_ticks := 0
		var peaks: Dictionary = {}
		for tick in range(7500):
			if w.phase == "choice":
				w.choices.choose(0)
			if w.phase != "playing":
				break
			w.step()
			var targets: Dictionary = {}
			for enemy: Dictionary in w.units.values():
				if enemy.side != 2 or enemy.dead or enemy.kind == "boss":
					continue
				if w.time_ms < enemy.taunt_until and enemy.target == enemy.taunt:
					continue
				if enemy.target > 0:
					targets[enemy.target] = int(targets.get(enemy.target, 0)) + 1
					stale_ticks += int(enemy.target != enemy.blocked_by)
			for id in targets:
				var blocker: Dictionary = w.units[id]
				var capacity := int(U.stat(blocker, 3))
				overflow_ticks += int(targets[id] > capacity)
				peaks[blocker.template] = maxi(int(peaks.get(blocker.template, 0)), targets[id])
		rows.append({"seed":run_seed,"time":w.time_ms,"wave":w.spawn_wave,"overflow_ticks":overflow_ticks,"stale_ticks":stale_ticks,"peaks":peaks,"wall_hp":w.wall_hp})
		print("[CAMPAIGN BLOCKING] ",JSON.stringify(rows.back()))
		w.dispose()
	var file = FileAccess.open("res://validation/defense/blocking_limit/campaign_probe.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"\t"))
	quit()
