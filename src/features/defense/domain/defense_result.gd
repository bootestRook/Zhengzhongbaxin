class_name DefenseResult
extends RefCounted

const REWARD_ICONS = {"resource:1": "homeReference:coin", "resource:2": "homeReference:diamond"}

static func make(w, snapshot: Dictionary, success: bool) -> Dictionary:
	var progress: float = 1.0 if success else clampf((w.stage + snapshot.progress) / float(w.level.waves.size()), 0, 1)
	var best: float = maxf(progress, float(w.best_progress.get(w.level_id, 0)))
	w.best_progress[w.level_id] = best
	var totals = {"damage": 0.0, "taken": 0.0, "heal": 0.0}
	var heroes: Array = snapshot.heroes.duplicate(true)
	var mvp: int = -1
	var maximum: float = -1
	for i in range(heroes.size()):
		for key in totals:
			totals[key] += heroes[i].stats[key]
		if heroes[i].stats.damage > maximum:
			maximum = heroes[i].stats.damage
			mvp = i
	var rewards: Dictionary = {}
	for entry in w.level.raw.get("reward", []):
		add_reward(rewards, entry)
	var items: Array = []
	for key in rewards:
		var parts = str(key).split(":")
		items.append({"kind": parts[0], "id": int(parts[1]), "count": rewards[key],
			"res": REWARD_ICONS[key]})
	return {"level": w.level_id, "won": success, "progress": progress, "best": best,
		"encounters": w.level.encounters.duplicate(true), "encounters_cleared": w.encounters_cleared.duplicate(),
		"encounter_rows_cleared": w.spawn.cleared_rows(), "wave_count": w.rules.wave_count,
		"heroes": heroes, "mvp": mvp, "totals": totals, "rewards": items}

static func add_reward(items: Dictionary, entry: String) -> void:
	var parts = entry.split(":")
	if parts.size() != 3 or int(parts[2]) <= 0:
		return
	var key: String = parts[0] + ":" + parts[1]
	items[key] = int(items.get(key, 0)) + int(parts[2])
