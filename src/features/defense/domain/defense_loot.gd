class_name DefenseLoot
extends RefCounted

var w
var serial: int = 0
var queue: Array = []
var current: Dictionary = {}

func _init(world) -> void:
	w = world

func reset() -> void:
	serial = 0
	queue.clear()
	current.clear()

func pool(excluded: Array = []) -> Array:
	return w.choices.upgrade_pool(excluded)

func roll(excluded: Array = []) -> Dictionary:
	return w.choices.roll_upgrade(w.rng.stream("defense.loot"), excluded)

func enqueue(source: String) -> void:
	if source not in ["elite", "boss"] or w.phase in ["home", "result"]:
		return
	serial += 1
	queue.append({"id": serial, "source": source})
	w.events.append({"type": "reward_queued", "reward": serial, "source": source})

func drop(target: Dictionary) -> void:
	enqueue(target.kind)

func advance() -> void:
	if w.phase != "playing" or w.paused or not current.is_empty():
		return
	while not queue.is_empty():
		var ticket: Dictionary = queue.pop_front()
		var candidates = pool()
		var counts: Array = []
		for i in range(4):
			counts.append({"count": i + 1, "weight": w.rules.chest_reward_weights[i]})
		var requested: int = 0 if candidates.is_empty() else w.rng.stream("defense.loot").choose_weighted(counts).count
		var items: Array = []
		var excluded: Array = []
		w.phase = "reward"
		for _i in range(requested):
			var item = roll(excluded)
			if item.is_empty():
				break
			items.append(item)
			excluded.append(item.id)
			w.upgrades.apply(w.units[item.owner], item.id)
			w.choices.balance(item.owner)
			w.history.append({"stage": w.stage, "kind": "chest", "id": item.id, "owner": item.owner})
		current = {"id": ticket.id, "source": ticket.source, "requested": requested, "items": items, "candidates": candidates}
		w.events.append({"type": "reward_granted", "reward": ticket.id, "source": ticket.source, "count": items.size()})
		return

func close(id: int) -> String:
	if w.phase != "reward" or current.is_empty() or id != current.id:
		return "奖励已关闭"
	current.clear()
	w.phase = "playing"
	advance()
	if w.phase == "playing":
		if w.can_win():
			w.finish(true)
		elif not w.pending.is_empty():
			w.choices.offer("bonus")
		else:
			w.choices.advance()
	return ""

func snapshot() -> Dictionary:
	return current.duplicate(true)
