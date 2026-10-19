class_name DefenseStatus
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
const C = preload("res://src/features/defense/domain/defense_catalog.gd")
var w
var definitions: Dictionary
var regen_at: int = 5000

func _init(world) -> void:
	w = world
	definitions = w.catalog.records("statuses")

func has_status(u: Dictionary, id: int) -> bool:
	for state in u.statuses:
		if state.id == id:
			return true
	return false

func add(target: Dictionary, source: Dictionary, id: int, duration: float, speed_ratio: float = 0) -> void:
	if target.dead or not definitions.has(str(id)):
		return
	var d: Dictionary = definitions[str(id)]
	var max_stack = maxi(1, int(d.get("superposition", 1)))
	var previous: Dictionary = {}
	for state in target.statuses:
		if state.id == id and state.source == source.id:
			previous = state
			break
	var stacks = 1
	if not previous.is_empty():
		stacks = mini(max_stack, int(previous.stacks) + 1)
		remove(target, previous)
	var friendly: bool = source.side == target.side
	var length = duration * maxf(0.05, 1 + U.stat(source, 28 if friendly else 27) / 100.0)
	if not friendly:
		length *= maxf(0.05, 1 - U.stat(target, 31) / 100.0)
		length = w.damage.protection.control_duration(target, d, length)
	if d.get("taunt_bound", false):
		length = duration
	var state = {"id": id, "source": source.id, "stacks": stacks,
		"started": w.time_ms,
		"source_attack": U.stat(source, 4), "source_magic": U.stat(source, 12), "source_cure": U.stat(source, 22),
		"expires": 2147483647 if duration < 0 else w.time_ms + maxi(16, roundi(length)), "next": w.time_ms + 1000, "modifiers": [], "shield_type": 0, "shield_remaining": 0.0,
		"granted_skills": []}
	state["speed_ratio"] = speed_ratio
	if d.get("refresh_ticks", false) and not previous.is_empty():
		state.next = previous.next
	if d.get("keep_longer", false) and not previous.is_empty():
		state.expires = maxi(state.expires, previous.expires)
	for entry in d.get("attributeRev", []):
		var p = C.numbers(entry)
		if p.size() >= 2:
			var key = str(int(p[0]))
			var value = p[1] * stacks
			var mode = int(p[2]) if p.size() > 2 else 1
			if mode == 2:
				value = target.core.attributes.base_value(key) * value / 100.0
			state.modifiers.append(target.core.attributes.add_modifier(key, "final_add", value, "status.%d" % id))
	var shield = C.numbers(d.get("shield", ""))
	if shield.size() >= 2:
		state.shield_type = int(shield[0])
		if int(shield[0]) == 1:
			target.shield_hits += int(shield[1])
			state.shield_remaining = shield[1]
		else:
			state.shield_remaining = U.stat(target, 1 if int(shield[0]) == 2 else 4) * shield[1] / 100.0
			target.shield += state.shield_remaining
	target.statuses.append(state)
	if id == 20001:
		w.gems.guard_applied(target, state)
	for entry in d.get("skillChange", []):
		var skill_id = int(entry)
		w.skills.learn(target, skill_id, true)
		state.granted_skills.append(skill_id)

func remove(target: Dictionary, state: Dictionary, reason: String = "removed") -> void:
	if not target.statuses.has(state):
		return
	if state.shield_type == 1:
		target.shield_hits = maxi(0, target.shield_hits - int(state.shield_remaining))
	else:
		target.shield = maxf(0, target.shield - float(state.shield_remaining))
	for modifier in state.modifiers:
		target.core.attributes.remove_modifier(modifier)
	target.statuses.erase(state)
	if state.id == 20001:
		w.gems.guard_removed(target, state)
	w.skills.thorns.ended(target, state, reason)
	for skill_id in state.granted_skills:
		if target.skills.has(skill_id) and target.skills[skill_id].get("temporary", false):
			if not target.statuses.any(func(other): return other.granted_skills.has(skill_id)):
				target.skills.erase(skill_id)

func consume_shield(target: Dictionary, value: float, hit: bool = false) -> void:
	for state in target.statuses.duplicate():
		if (state.shield_type == 1) != hit or state.shield_remaining <= 0:
			continue
		var used = minf(value, state.shield_remaining)
		state.shield_remaining -= used
		value -= used
		if state.shield_remaining <= 0 and state.has("thorn"):
			remove(target, state, "broken")
		if value <= 0:
			return
	if not hit:
		target["overflow_shield"] = maxf(0, float(target.get("overflow_shield", 0)) - value)

func prevents(u: Dictionary, action: String) -> bool:
	for state in u.statuses:
		if action == "skill" and int(state.id) == 4: return true
		var d: Dictionary = definitions.get(str(state.id), {})
		if int(d.get("moveFor" if action == "move" else ("skillFor" if action == "skill" else "attackFor"), 0)) == 1:
			return true
	return false

func tick() -> void:
	if w.time_ms < regen_at - 5000:
		regen_at = 5000
	var regen = w.time_ms >= regen_at
	if regen:
		regen_at = w.time_ms + 5000
	for u: Dictionary in w.units.values():
		if u.dead:
			continue
		if regen and u.side == 1:
			var extra = float(u.get("overflow_regen", 0)) if w.time_ms < int(u.get("overflow_regen_until", 0)) else 0.0
			w.damage.heal(u, u, U.stat(u, 2) + extra, false)
		if int(u.get("overflow_shield_until", 0)) > 0 and w.time_ms >= int(u.overflow_shield_until):
			u.shield = maxf(0, u.shield - float(u.get("overflow_shield", 0)))
			u["overflow_shield"] = 0.0
			u.overflow_shield_until = 0
		for state in u.statuses.duplicate():
			var bound = definitions[str(state.id)].get("taunt_bound", false)
			var final_tick = definitions[str(state.id)].get("tick_at_expiry", false) and state.next <= state.expires
			if (w.time_ms >= state.expires and not final_tick) or (bound and w.damage.protection.taunt_ended(u, state)):
				remove(u, state, "expired")
				continue
			if w.time_ms < state.next:
				continue
			var d: Dictionary = definitions[str(state.id)]
			var hurt = C.numbers(d.get("hurtRev", ""))
			state.next += maxi(16, roundi(hurt[0] * 1000)) if hurt.size() >= 3 else 1000
			if hurt.size() < 3:
				continue
			var owner: Dictionary = w.units.get(state.source, {})
			var base = float(state.source_attack) if int(d.get("hpRev_type", 1)) == 1 else U.stat(u, 1)
			var amount = base * absf(hurt[2]) / 10000.0 * state.stacks
			amount *= 1 + (U.stat(owner, 6) * float(state.get("speed_ratio", 0)) if not owner.is_empty() else 0)
			if hurt[2] < 0:
				w.damage.hit(owner, u, amount * (1 + state.source_magic / 100.0), true, true, {"kind": "periodic", "tags": str(d.get("damage_type", "")).split(";")})
			else:
				w.damage.heal(owner, u, amount, true, 1 + state.source_cure / 100.0)
