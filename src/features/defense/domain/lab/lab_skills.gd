extends "res://src/features/defense/domain/defense_skills.gd"

func ready_action(unit: Dictionary) -> bool:
	return super.ready_action(unit) if w.allowed(unit, "skill") else false

func pending_action(unit: Dictionary) -> bool:
	return super.pending_action(unit) if w.allowed(unit, "skill") else false

func trigger(unit: Dictionary, event: String, target: Dictionary, damage_taken: float = 0) -> bool:
	return super.trigger(unit, event, target, damage_taken) if w.allowed(unit, "skill") else false

func begin_action(unit: Dictionary, state: Dictionary, target: Dictionary, combat: bool, count: int = 1) -> bool:
	var ok = super.begin_action(unit, state, target, combat, count)
	if ok:
		w.record("windup", {"source": unit.id, "target": target.get("id", 0), "skill": state.data.__id__, "cooldown_until": state.next})
	return ok

func cast(owner: Dictionary, skill: Dictionary, target: Dictionary, origin: Vector2 = Vector2.INF, death_cast: bool = false) -> bool:
	var previous: int = w.active_skill
	w.active_skill = int(skill.__id__)
	var ok = super.cast(owner, skill, target, origin, death_cast)
	w.record("cast" if ok else "cast_rejected", {"source": owner.get("id", 0), "target": target.get("id", 0), "skill": skill.__id__})
	w.active_skill = previous
	return ok
