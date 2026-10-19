class_name DefenseGems
extends RefCounted
const U = preload("res://src/features/defense/domain/defense_units.gd"); const Statue = preload("res://src/features/defense/domain/defense_statue.gd")
const Area = preload("res://src/features/defense/domain/defense_area.gd")
var w
var active: Array = []
var instant_revive_ready_at: int = 0
var statue_protection_left: int = 0
var low_hp_states: Dictionary = {}
var timed_modifiers: Array = []
var statue_loss: float = 0.0
var statue_punishment_marks: Dictionary = {}
func _init(world) -> void:
	w = world
func reset() -> void:
	active = w.equipment.active_gems()
	instant_revive_ready_at = 0
	statue_protection_left = int(_sum("statue_hit_immunity", "hits"))
	low_hp_states.clear()
	timed_modifiers.clear()
	statue_loss = 0.0
	statue_punishment_marks.clear()
func _applies(definition: Dictionary, unit: Dictionary) -> bool:
	if unit.is_empty() or unit.get("kind", "") != "hero": return false
	var owners: Array = definition.get("owner_ids", []); return owners.is_empty() or owners.has(int(unit.get("template", 0)))
func _sum(kind: String, field: String = "value", unit: Dictionary = {}) -> float:
	var total := 0.0
	for definition: Dictionary in active:
		var effect: Dictionary = definition.get("effect", {}); if effect.get("type", "") == kind and (unit.is_empty() or _applies(definition, unit)): total += float(effect.get(field, 0))
	return total
func apply_hero_base(source: Dictionary, base: Dictionary) -> void:
	var percentages: Dictionary = {}
	var additions: Dictionary = {}
	var unit = {"kind": "hero", "template": int(source.get("id", 0))}
	for definition: Dictionary in active:
		if not _applies(definition, unit):
			continue
		var effect: Dictionary = definition.get("effect", {})
		match effect.get("type", ""):
			"attribute_pct": percentages[effect.attribute] = float(percentages.get(effect.attribute, 0)) + float(effect.value)
			"attribute_pct_bundle":
				for attribute in effect.attributes:
					percentages[attribute] = float(percentages.get(attribute, 0)) + float(effect.value)
			"attribute_add": additions[effect.attribute] = float(additions.get(effect.attribute, 0)) + float(effect.value)
	for attribute in percentages:
		base[attribute] = float(base.get(attribute, 0)) * (1.0 + float(percentages[attribute]) / 100.0)
	for attribute in additions:
		base[attribute] = float(base.get(attribute, 0)) + float(additions[attribute])
func modify_skill(owner: Dictionary, original: Dictionary) -> Dictionary:
	var skill = original.duplicate(true)
	if skill.has("fireball"):
		var fireball: Dictionary = skill.fireball
		fireball["blast_bonus"] = float(fireball.get("blast_bonus", 0)) + _sum_skill(owner, "skill_damage_pct", "fireball")
		fireball["radius_bonus"] = float(fireball.get("radius_bonus", 0)) + _sum_skill(owner, "skill_radius_pct", "fireball")
		var charge := _sum_skill(owner, "skill_charge_pct", "fireball")
		fireball["charge_ms"] = maxi(1, roundi(float(fireball.get("charge_ms", 1)) * maxf(0, 1.0 - charge / 100.0)))
		fireball["copies"] = int(fireball.get("copies", 1)) + int(_sum_skill(owner, "skill_copies_add", "fireball"))
		fireball["pierce"] = int(fireball.get("pierce", 0)) + int(_sum_skill(owner, "skill_pierce_add", "fireball"))
	if skill.has("thorn_armor"):
		var thorn: Dictionary = skill.thorn_armor
		thorn["shield_percent"] = float(thorn.get("shield_percent", 0)) * (1.0 + _sum_field(owner, "thorn", "shield_percent") / 100.0)
		thorn["heal_percent"] = float(thorn.get("heal_percent", 0)) * (1.0 + _sum_field(owner, "thorn", "heal_percent") / 100.0)
		thorn["retaliate_percent"] = float(thorn.get("retaliate_percent", 0)) * (1.0 + _sum_field(owner, "thorn", "retaliate_percent") / 100.0)
		thorn["targets"] = int(thorn.get("targets", 1)) + int(_sum_field(owner, "thorn", "targets"))
	if skill.has("ice_arrows"):
		var ice: Dictionary = skill.ice_arrows
		ice["bonus"] = float(ice.get("bonus", 0)) + _sum_skill(owner, "skill_damage_pct", "ice")
		ice["pierce"] = int(ice.get("pierce", 0)) + int(_sum_field(owner, "ice", "pierce"))
		ice["copies"] = int(ice.get("copies", 1)) + int(_sum_field(owner, "ice", "copies"))
		if _has(owner, "ice_fixed_combo"):
			ice["combo_chance"] = 100.0
	if skill.has("assassination"):
		var assassination: Dictionary = skill.assassination
		assassination["damage_percent"] = float(assassination.get("damage_percent", 0)) * (1.0 + _sum_field(owner, "assassination", "damage_percent") / 100.0)
		assassination["smoke_radius"] = Area.radius(float(assassination.get("smoke_radius", 0)), _sum_field(owner, "assassination", "smoke_radius"))
		if _has(owner, "skill_field_bool", "combo"):
			assassination["combo"] = true
	var guard_add := _sum("guard_duration_add_ms", "value", owner)
	for status in skill.get("statusChange", []):
		if status.size() >= 2 and str(status[0]) == "20001": status[1] = str(float(status[1]) + guard_add / 1000.0)
	return skill
func _sum_skill(owner: Dictionary, kind: String, skill_name: String) -> float:
	var total := 0.0
	for definition: Dictionary in active:
		if not _applies(definition, owner): continue
		var effect: Dictionary = definition.effect
		if effect.get("type", "") == kind and effect.get("skill", "") == skill_name:
			total += float(effect.get("value", 0))
	return total
func _sum_field(owner: Dictionary, skill_name: String, field: String) -> float:
	var total := 0.0
	for definition: Dictionary in active:
		if not _applies(definition, owner): continue
		var effect: Dictionary = definition.effect
		if effect.get("skill", "") == skill_name and effect.get("field", "") == field:
			total += float(effect.get("value", 0))
	return total
func _has(owner: Dictionary, kind: String, field: String = "") -> bool:
	for definition: Dictionary in active:
		if not _applies(definition, owner): continue
		var effect: Dictionary = definition.effect
		if effect.get("type", "") == kind and (field.is_empty() or effect.get("field", "") == field):
			return true
	return false
func damage_multiplier(source: Dictionary, target: Dictionary, context: Dictionary) -> float:
	if source.is_empty() or source.get("kind", "") != "hero" or context.get("true_damage", false): return 1.0
	var value := 0.0
	var element_key = {"火": "fire", "冰": "ice", "电": "electric", "自然": "nature", "物理": "physical"}.get(str(source.get("element", "")), "")
	for definition: Dictionary in active:
		if not _applies(definition, source):
			continue
		var effect: Dictionary = definition.effect
		match effect.get("type", ""):
			"element_damage_pct":
				if effect.element == element_key: value += float(effect.value)
			"range_damage_pct":
				if (effect.range == "melee") == bool(source.get("front", false)): value += float(effect.value)
			"profession_damage_taken_pct":
				if int(source.get("profession", 0)) == int(effect.profession): value += float(effect.damage)
			"elite_damage_taken_pct":
				if target.get("kind", "") in ["elite", "boss"]: value += float(effect.damage)
			"stage_damage_pct":
				if w.spawn_wave > 0 and w.spawn_wave <= int(effect.before_wave): value += float(effect.value)
			"attack_damage_pct":
				if context.get("kind", "") == "attack": value += float(effect.value)
	return 1.0 + value / 100.0
func damage_taken_multiplier(target: Dictionary, source: Dictionary, context: Dictionary) -> float:
	if target.is_empty() or target.get("kind", "") != "hero" or context.get("true_damage", false): return 1.0
	var reduction := 0.0
	for definition: Dictionary in active:
		if not _applies(definition, target):
			continue
		var effect: Dictionary = definition.effect
		if effect.get("type", "") == "profession_damage_taken_pct" and int(target.get("profession", 0)) == int(effect.profession):
			reduction += float(effect.taken)
		elif effect.get("type", "") == "elite_damage_taken_pct" and source.get("kind", "") in ["elite", "boss"]:
			reduction += float(effect.taken)
	return maxf(0, 1.0 - reduction / 100.0)
func statue_max_bonus() -> float: return _sum("statue_strength", "max_hp")
func extra_choice_count() -> int:
	var count := 0
	for definition: Dictionary in active:
		if definition.effect.get("type", "") == "extra_choice": count += int(definition.effect.get("count", 0))
	return count
func revive_reduction(unit: Dictionary) -> float: return _sum("revive_time_reduction", "value", unit)
func try_instant_revive() -> bool:
	if w.time_ms < instant_revive_ready_at: return false
	for definition: Dictionary in active:
		if definition.effect.get("type", "") == "instant_revive":
			instant_revive_ready_at = w.time_ms + int(definition.effect.cooldown_ms)
			return true
	return false
func on_hero_death(_unit: Dictionary) -> void:
	var amount: float = w.wall_max * _sum("statue_on_death_pct") / 100.0; if amount > 0: w.wall_hp = minf(w.wall_max, w.wall_hp + amount)
func on_wave_started() -> void:
	var amount: float = w.wall_max * _sum("statue_wave_heal_pct") / 100.0; if amount > 0: w.wall_hp = minf(w.wall_max, w.wall_hp + amount)
func on_statue_damage(amount: float) -> void:
	statue_loss += amount
	for definition: Dictionary in active:
		var effect: Dictionary = definition.effect; if effect.get("type", "") != "statue_punishment": continue
		var threshold: float = w.wall_max * float(effect.threshold_pct) / 100.0; var key := str(definition.effect_id); var marks := int(statue_punishment_marks.get(key, 0))
		while threshold > 0 and statue_loss >= threshold * (marks + 1):
			marks += 1; if w.heroes.is_empty(): continue
			var caster: Dictionary = w.units.get(w.heroes[0], {})
			for enemy: Dictionary in w.targets.area({"side": 1}, Statue.BODY_CENTER, float(effect.radius)): w.statuses.add(enemy, caster, 4, float(effect.duration_ms))
			w.cue("effect", Statue.BODY_CENTER, {"res": "bulletStatus:stun3", "duration": 600, "scale": 0.18, "visual_tint": "#ffd35a"})
		statue_punishment_marks[key] = marks
func on_hero_revive(unit: Dictionary) -> void:
	for definition: Dictionary in active:
		if not _applies(definition, unit): continue
		var effect: Dictionary = definition.effect
		if effect.get("type", "") == "revive_buff":
			var handles = [unit.core.attributes.add_modifier("4", "final_add", U.stat(unit, 4), "gem.revenge"), unit.core.attributes.add_modifier("17", "final_add", U.stat(unit, 17), "gem.revenge")]
			timed_modifiers.append({"unit": unit.id, "until": w.time_ms + int(effect.duration_ms), "handles": handles})
func on_basic_hit(source: Dictionary) -> void:
	if source.get("kind", "") != "hero": return
	for definition: Dictionary in active:
		if not _applies(definition, source) or definition.effect.get("type", "") != "basic_reduce_skill_cd" or w.rng.stream("defense.combat").next_int(100) >= float(definition.effect.chance): continue
		for state in source.skills.values():
			if state.data.has("assassination"): state.next = maxi(w.time_ms, int(state.next) - int(definition.effect.reduce_ms))
func guaranteed_crit(source: Dictionary) -> bool: return _has(source, "assassination_guaranteed_crit")
func assassination_shield_pct(source: Dictionary) -> float: return _sum("assassination_shield_pct", "value", source)
func assassination_shield_duration(source: Dictionary) -> int:
	for definition: Dictionary in active:
		if _applies(definition, source) and definition.effect.get("type", "") == "assassination_shield_pct": return int(definition.effect.duration_ms)
	return 0
func fireball_true_burn(owner: Dictionary, target: Dictionary) -> float:
	for definition: Dictionary in active:
		if _applies(definition, owner) and definition.effect.get("type", "") == "fireball_true_burn_pct":
			return minf(U.stat(target, 1) * 0.02, U.stat(owner, 4) * float(definition.effect.cap_attack_multiplier))
	return 0.0
func thorn_cast_heal_max_pct(owner: Dictionary, target: Dictionary) -> float:
	var total := 0.0
	for definition: Dictionary in active:
		if _applies(definition, owner) and definition.effect.get("type", "") == "thorn_cast_heal_max_pct":
			total += float(definition.effect.value)
	return U.stat(target, 1) * total / 100.0
func guard_attack_burst(owner: Dictionary) -> Dictionary:
	for definition: Dictionary in active:
		if _applies(definition, owner) and definition.effect.get("type", "") == "guard_attack_burst": return definition.effect
	return {}
func guard_applied(owner: Dictionary, state: Dictionary) -> void:
	var burst = guard_attack_burst(owner)
	if not burst.is_empty():
		state["gem_guard_burst_until"] = w.time_ms + int(burst.duration_ms)
		state["gem_guard_burst_damage_pct"] = float(burst.damage_pct)
	var stun := _sum("guard_expire_stun_ms", "value", owner)
	if stun > 0: state["gem_guard_expire_stun_ms"] = int(stun)
func guard_removed(owner: Dictionary, state: Dictionary) -> void:
	var duration := int(state.get("gem_guard_expire_stun_ms", 0))
	if duration <= 0: return
	for enemy: Dictionary in w.targets.area(owner, owner.pos, 300): w.statuses.add(enemy, owner, 4, duration)
func guard_burst(owner: Dictionary, target: Dictionary) -> void:
	for state in owner.statuses:
		if w.time_ms > int(state.get("gem_guard_burst_until", 0)): continue
		var amount := U.stat(owner, 4) * float(state.get("gem_guard_burst_damage_pct", 0)) / 100.0
		for enemy: Dictionary in w.targets.area(owner, target.pos, 200): w.damage.hit(owner, enemy, amount, false, false, {"kind": "guard_burst", "tags": ["1", "6"]})
		return
func low_hp_trigger(unit: Dictionary) -> void:
	if unit.get("kind", "") != "hero" or U.hp(unit) >= U.stat(unit, 1) * 0.3: return
	if low_hp_states.has(unit.id) and w.time_ms < int(low_hp_states[unit.id].cooldown_until): return
	var duration := 0
	var cooldown := 0
	for definition: Dictionary in active:
		if _applies(definition, unit) and definition.effect.get("type", "") == "low_hp_regen":
			duration = int(definition.effect.duration_ms)
			cooldown = int(definition.effect.cooldown_ms)
	if duration > 0: low_hp_states[unit.id] = {"until": w.time_ms + duration, "cooldown_until": w.time_ms + cooldown, "heal_pct": 50.0, "next": w.time_ms}
func hero_block_hit(target: Dictionary, context: Dictionary) -> bool:
	if target.get("kind", "") != "hero" or context.get("kind", "attack") == "periodic": return false
	var state = target.get("gem_block", {})
	if state.is_empty():
		var hits := 0
		for definition: Dictionary in active:
			if _applies(definition, target) and definition.effect.get("type", "") == "hero_block": hits = maxi(hits, int(definition.effect.hits))
		if hits <= 0: return false
		state = {"hits": hits, "count": 0}
	state.count += 1
	if state.count >= state.hits:
		state.count = 0
		target["gem_block"] = state
		return true
	target["gem_block"] = state
	return false
func tick() -> void:
	for unit: Dictionary in w.units.values():
		if int(unit.get("gem_assassination_shield_until", 0)) > 0 and w.time_ms >= int(unit.gem_assassination_shield_until):
			unit.shield = maxf(0, unit.shield - float(unit.get("gem_assassination_shield", 0))); unit["gem_assassination_shield"] = 0.0; unit["gem_assassination_shield_until"] = 0
	for state in timed_modifiers.duplicate():
		if w.time_ms < int(state.until): continue
		var unit = w.units.get(state.unit, {})
		if not unit.is_empty():
			for handle in state.handles: unit.core.attributes.remove_modifier(handle)
		timed_modifiers.erase(state)
	for id in low_hp_states:
		var unit = w.units.get(id, {})
		var state = low_hp_states[id]
		if unit.is_empty() or unit.dead or w.time_ms >= int(state.until): continue
		if w.time_ms >= int(state.next):
			state.next += 1000; w.damage.heal(unit, unit, U.stat(unit, 1) * float(state.heal_pct) / 1000.0)
