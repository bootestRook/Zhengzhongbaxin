extends "res://src/features/defense/domain/defense_damage.gd"

func hit(source: Dictionary, target: Dictionary, value: float, magical: bool = true, allow_trigger: bool = true, context: Dictionary = {}) -> float:
	if target.is_empty():
		return 0
	if target.get("lab_survival", "normal") == "invulnerable":
		w.record("immune", {"source": source.get("id", 0), "target": target.id, "input": value})
		return 0
	var before = U.hp(target)
	var shield: float = target.shield
	var actual = super.hit(source, target, value, magical, allow_trigger, context)
	w.record("damage", {"source": source.get("id", 0), "target": target.id, "skill": w.active_skill,
		"kind": context.get("kind", "attack"), "input": value, "actual": actual, "hp_before": before,
		"hp_after": U.hp(target), "shield_used": maxf(0, shield - target.shield), "survival": target.get("lab_survival", "normal")})
	return actual

func apply_health_damage(target: Dictionary, value: float) -> float:
	if target.get("lab_survival", "normal") == "immortal":
		target.core.attributes.set_value("hp", U.stat(target, 1))
		return value
	return super.apply_health_damage(target, value)

func heal(source: Dictionary, target: Dictionary, value: float, triggers: bool = true, source_scale: float = -1) -> void:
	var before = U.hp(target)
	super.heal(source, target, value, triggers, source_scale)
	if not target.is_empty() and U.hp(target) != before:
		w.record("heal", {"source": source.get("id", 0), "target": target.id, "actual": U.hp(target) - before})

func execute(source: Dictionary, target: Dictionary) -> void:
	if target.get("lab_survival", "normal") != "normal":
		w.record("execution_blocked", {"source": source.id, "target": target.id})
		return
	super.execute(source, target)

func defeat(target: Dictionary, source: Dictionary) -> void:
	if target.get("lab_survival", "normal") != "normal":
		return
	var was_dead: bool = target.dead
	super.defeat(target, source)
	if not was_dead and target.dead:
		w.record("death", {"source": source.get("id", 0), "target": target.id, "skill": w.active_skill})
		if w.settings.respawn and target.side == 2 and target.has("lab_spec"):
			w.replacements.append({"at": w.time_ms + 1000, "spec": target.lab_spec.duplicate(true)})

func apply_skill(source: Dictionary, target: Dictionary, skill: Dictionary) -> void:
	var previous: int = w.active_skill
	w.active_skill = int(skill.get("__id__", 0))
	super.apply_skill(source, target, skill)
	w.active_skill = previous
