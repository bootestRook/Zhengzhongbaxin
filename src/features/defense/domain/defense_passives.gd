class_name DefensePassives
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
const C = preload("res://src/features/defense/domain/defense_catalog.gd")
var w
var definitions: Dictionary
var healing_depth: int = 0

func _init(world) -> void:
	w = world
	definitions = w.catalog.records("passives")

func add(unit: Dictionary, entry: String) -> void:
	var parts = entry.split(":")
	var d: Dictionary = definitions.get(parts[0], {})
	if d.is_empty():
		w.note("missing_passive.%s" % parts[0])
		return
	var amount = maxf(1, float(parts[1])) if parts.size() > 1 else 1.0
	var values: Array = d.get("value1", [0])
	var value = float(values[0]) * (amount if d.get("merge", []).has(1) else 1)
	var second = float(d.get("value2", 0)) * (amount if d.get("merge", []).has(2) else 1)
	unit.passives.append({"type": int(d.type), "value": value, "second": second})

func value(unit: Dictionary, type: int) -> float:
	var total = 0.0
	for p in unit.get("passives", []):
		if p.type == type:
			total += p.value
	return total

func has_buff(unit: Dictionary, debuff: bool = false) -> bool:
	for status in unit.statuses:
		var d: Dictionary = w.statuses.definitions.get(str(status.id), {})
		if d.get("bufftype", []).has(2 if debuff else 1):
			return true
	return false

func attack_bonus(unit: Dictionary) -> float:
	var result = U.stat(unit, 10) * value(unit, 8) / 100.0
	result += float(unit.get("next_damage", 0))
	unit["next_damage"] = 0.0
	if value(unit, 10) > 0:
		result += U.hp(unit) * value(unit, 10) / 100.0
		unit.core.attributes.set_value("hp", maxf(1, U.hp(unit) * (1 - value(unit, 10) / 100.0)))
	return result

func damage_multiplier(source: Dictionary, target: Dictionary, magical: bool) -> float:
	var bonus = value(source, 46 if magical else 45) if float(source.get("shield", 0)) > 0 else 0.0
	var reduction = value(target, 48) if has_buff(target) else 0.0
	if not source.is_empty() and has_buff(source, true):
		reduction += value(target, 55)
	return maxf(0, (1 + bonus / 100.0) * (1 - reduction / 100.0))

func cooldown(unit: Dictionary) -> float:
	var reduction = U.stat(unit, 9) + (value(unit, 47) if has_buff(unit) else 0.0)
	return maxf(0.6, 1 - reduction / 100.0)

func on_heal(target: Dictionary, actual: float, overflow: float) -> void:
	if healing_depth > 0:
		return
	healing_depth += 1
	var share = value(target, 51)
	if share > 0:
		for u in w.units.values():
			if u.owner == target.id and not u.dead:
				w.damage.heal(target, u, actual * share / 100.0)
	if overflow > 0:
		target["next_damage"] = float(target.get("next_damage", 0)) + overflow * value(target, 52) / 100.0
		if value(target, 50) > 0:
			target.shield += overflow * value(target, 50) / 100.0
			target["overflow_shield"] = float(target.get("overflow_shield", 0)) + overflow * value(target, 50) / 100.0
			target["overflow_shield_until"] = w.time_ms + 10000
		if value(target, 49) > 0:
			target["overflow_regen"] = float(target.get("overflow_regen", 0)) + overflow * value(target, 49) / 100.0
			target["overflow_regen_until"] = w.time_ms + 10000
		if value(target, 53) > 0:
			var candidates: Array = []
			for id in w.heroes:
				var ally: Dictionary = w.units[id]
				if ally.id != target.id and not ally.dead and U.hp(ally) < U.stat(ally, 1):
					candidates.append(ally)
			if not candidates.is_empty():
				w.damage.heal(target, candidates[w.rng.stream("defense.combat").next_int(candidates.size())], overflow / 2)
	healing_depth -= 1

func redirect(source: Dictionary, target: Dictionary, amount: float) -> float:
	var percent = value(target, 54)
	if percent <= 0:
		return amount
	var summons: Array = []
	for u in w.units.values():
		if u.owner == target.id and not u.dead:
			summons.append(u)
	if summons.is_empty():
		return amount
	var redirected = amount * minf(100, percent) / 100.0
	for u in summons:
		w.damage.hit(source, u, redirected / summons.size(), true, false)
	return amount - redirected

func shield_broken(target: Dictionary, amount: float) -> void:
	var percent = value(target, 56)
	if percent <= 0:
		return
	for enemy in w.targets.area(target, target.pos, 400):
		w.damage.hit(target, enemy, amount * 4, true, false)
	w.cue("effect", target.pos, {"res": "bullet:boom", "scale": 1.3})
