class_name DefenseProtection
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
var w

func _init(world) -> void:
	w = world

func configure(unit: Dictionary, rules: Dictionary) -> void:
	if rules.is_empty():
		return
	if not unit.has("protection"):
		unit["protection"] = {"rules": {}, "immune_until": 0, "lethal_ready": 0}
	unit.protection.rules.merge(rules, true)

func active(unit: Dictionary) -> Dictionary:
	var rules: Dictionary = unit.get("protection", {}).get("rules", {})
	for state in unit.statuses:
		if state.id == int(rules.get("status", 0)) and w.time_ms < state.expires:
			return state
	return {}

func immune(unit: Dictionary) -> bool:
	return w.time_ms < int(unit.get("protection", {}).get("immune_until", 0))

func protect_lethal(unit: Dictionary, value: float) -> float:
	var protection: Dictionary = unit.get("protection", {})
	var rules: Dictionary = protection.get("rules", {})
	if value < U.hp(unit) or not rules.has("lethal_cooldown_ms") or active(unit).is_empty() or w.time_ms < int(protection.lethal_ready):
		return value
	protection.lethal_ready = w.time_ms + int(rules.lethal_cooldown_ms)
	protection.immune_until = w.time_ms + int(rules.immunity_ms)
	w.events.append({"type": "lethal_prevented", "unit": unit.id})
	w.cue("number", unit.pos, {"text": "不屈", "color": "blue"})
	return maxf(0, U.hp(unit) - 1)

func hurt(unit: Dictionary, actual: float) -> void:
	var rules: Dictionary = unit.get("protection", {}).get("rules", {})
	if actual <= 0 or not rules.has("hurt_step"):
		return
	var state = active(unit)
	if state.is_empty() or w.time_ms < int(state.get("guard_next", 0)):
		return
	var amount = mini(int(rules.hurt_cap), int(state.get("guard_reduction", 0)) + int(rules.hurt_step))
	if amount == int(state.get("guard_reduction", 0)):
		return
	if state.has("guard_modifier"):
		unit.core.attributes.remove_modifier(state.guard_modifier)
		state.modifiers.erase(state.guard_modifier)
	state["guard_modifier"] = unit.core.attributes.add_modifier("11", "final_add", amount, "guard.hurt")
	state.modifiers.append(state.guard_modifier)
	state["guard_reduction"] = amount
	state["guard_next"] = w.time_ms + int(rules.hurt_interval_ms)

func blocks_displacement(unit: Dictionary) -> bool:
	return bool(unit.get("protection", {}).get("rules", {}).get("knockback_immune", false)) and not active(unit).is_empty()

func control_duration(unit: Dictionary, status: Dictionary, duration: float) -> float:
	var controls = int(status.get("moveFor", 0)) == 1 or int(status.get("attackFor", 0)) == 1
	if controls and not active(unit).is_empty():
		return duration * float(unit.get("protection", {}).get("rules", {}).get("control_multiplier", 1.0))
	return duration

func taunt(owner: Dictionary, target: Dictionary, duration: int) -> void:
	target.taunt = owner.id
	target["taunt_started"] = w.time_ms
	target.taunt_until = w.time_ms + duration
	target.ai_at = w.time_ms
	var rules: Dictionary = owner.get("protection", {}).get("rules", {})
	var shield = active(owner)
	if not shield.is_empty():
		target.taunt_until = mini(target.taunt_until, int(shield.expires))
	if rules.has("taunt_debuff_status"):
		w.statuses.add(target, owner, int(rules.taunt_debuff_status), target.taunt_until - w.time_ms)

func taunt_ended(target: Dictionary, state: Dictionary) -> bool:
	var owner: Dictionary = w.units.get(state.source, {})
	return target.taunt != state.source or w.time_ms >= target.taunt_until or owner.is_empty() or owner.dead
