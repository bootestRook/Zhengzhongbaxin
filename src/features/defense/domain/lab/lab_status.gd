extends "res://src/features/defense/domain/defense_status.gd"

func add(target: Dictionary, source: Dictionary, id: int, duration: float, speed_ratio: float = 0) -> void:
	super.add(target, source, id, duration, speed_ratio)
	for state in target.statuses:
		if state.id == id and state.source == source.id:
			w.record("status_added", {"source": source.id, "target": target.id, "status": id, "stacks": state.stacks, "expires": state.expires})
			break

func remove(target: Dictionary, state: Dictionary, reason: String = "removed") -> void:
	var existed = target.statuses.has(state)
	super.remove(target, state, reason)
	if existed:
		w.record("status_removed", {"source": state.source, "target": target.id, "status": state.id, "reason": reason})

func consume_shield(target: Dictionary, value: float, hit: bool = false) -> void:
	var status_capacity = 0.0
	for state in target.statuses:
		if state.shield_type != 1: status_capacity += state.shield_remaining
	super.consume_shield(target, value, hit)
	if not hit:
		target["lab_shield"] = maxf(0, float(target.get("lab_shield", 0)) - maxf(0, value - status_capacity))
