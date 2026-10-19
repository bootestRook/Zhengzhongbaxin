extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Effects = preload("res://src/features/defense/domain/defense_skill_effects.gd")

class TracedEffects extends Effects:
	var moves: Array = []
	func apply(owner: Dictionary, target: Dictionary, skill: Dictionary, phase: String = "begin", damage: float = 0) -> void:
		var from = owner.get("pos", Vector2.ZERO)
		var target_from = target.get("pos", Vector2.ZERO)
		super.apply(owner, target, skill, phase, damage)
		if owner.get("pos", Vector2.ZERO) != from or target.get("pos", Vector2.ZERO) != target_from:
			moves.append({"at": w.time_ms, "owner": owner.id, "target": target.get("id", 0), "skill": skill.__id__, "actions": skill.get("actionOth", [])})

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var audit = JSON.parse_string(FileAccess.get_file_as_string("res://validation/defense/five_hero_ai_audit/audit.json"))
	var results: Array = []
	for record in audit.battles:
		if not record.metrics.values().any(func(m): return m.locked_moves > 0 or m.rapid_flips > 0):
			continue
		var w = Session.new(catalog)
		w.level_id = 5
		w.start(int(record.seed))
		for hid in record.initial:
			w.factory.add_hero(int(hid))
		w.phase = "playing"
		var effects = TracedEffects.new(w)
		w.projectiles.effects = effects
		var counts: Dictionary = {}
		var samples: Array = []
		for tick in range(7500):
			if w.phase == "choice":
				w.submit("choose", {"index": 0})
			if w.phase != "playing":
				break
			var old: Dictionary = {}
			for id in w.heroes:
				var hero: Dictionary = w.units[id]
				old[id] = {"pos": hero.pos, "action": hero.action, "until": hero.action_until, "dead": hero.dead, "forced": hero.has("forced_motion"),
					"charge": w.missiles.any(func(p): return p.owner == id and p.kind in [29, 30])}
			effects.moves.clear()
			w.step()
			for id in old:
				var hero: Dictionary = w.units[id]
				var previous: Dictionary = old[id]
				if previous.dead or hero.dead or previous.forced or hero.has("forced_motion"):
					continue
				if previous.action not in ["attack", "skill", "skill2"] or w.time_ms >= previous.until or hero.pos.distance_to(previous.pos) <= 0.01:
					continue
				var reason = "unexplained"
				var teleports = effects.moves.filter(func(move): return move.owner == id or move.target == id)
				if not teleports.is_empty():
					reason = "skill_teleport"
				elif previous.charge or w.missiles.any(func(p): return p.owner == id and p.kind in [29, 30]):
					reason = "skill_charge"
				elif hero.action_until <= w.time_ms:
					reason = "action_completed_before_move"
				var key = "%d:%s" % [hero.template, reason]
				counts[key] = int(counts.get(key, 0)) + 1
				if samples.size() < 24:
					samples.append({"hero": hero.template, "at": w.time_ms, "reason": reason, "from": str(previous.pos), "to": str(hero.pos), "old_action": previous.action, "action": hero.action, "teleports": teleports})
		var result = {"initial": record.initial, "seed": record.seed, "counts": counts, "samples": samples}
		results.append(result)
		print("[MOVEMENT CLASSIFIED] ", JSON.stringify({"initial": record.initial, "seed": record.seed, "counts": counts}))
		w.dispose()
	FileAccess.open("res://validation/defense/five_hero_ai_audit/movement_probe.json", FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	quit()
