class_name DefenseDamage
extends RefCounted
const Statue = preload("res://src/features/defense/domain/defense_statue.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const C = preload("res://src/features/defense/domain/defense_catalog.gd")
const Mitigation = preload("res://src/features/defense/domain/defense_mitigation.gd")
const Traits = preload("res://src/features/defense/domain/defense_traits.gd")
const Protection = preload("res://src/features/defense/domain/defense_protection.gd")
var w
var depth: int = 0
var mitigation
var traits
var protection
func _init(world) -> void:
	w = world
	mitigation = Mitigation.new(world)
	traits = Traits.new(world)
	protection = Protection.new(world)
func basic_hit(source: Dictionary, target: Dictionary, amount: float) -> float:
	var tags: PackedStringArray = str(source.damage_type).split(";")
	var magical = "0" in tags
	var value = amount * maxf(0, 1 + U.stat(source, 12 if magical else 25) / 100.0)
	var before = int(source.hits)
	var actual = hit(source, target, value, magical, true, {"kind": "attack", "tags": tags})
	if int(source.hits) > before:
		w.skills.assassination.basic_hit(source, target)
		w.gems.on_basic_hit(source)
		w.gems.guard_burst(source, target)
	return actual
func hit(source: Dictionary, target: Dictionary, value: float, magical: bool = true, allow_trigger: bool = true, context: Dictionary = {}) -> float:
	if target.is_empty() or target.dead or value <= 0 or protection.immune(target):
		return 0
	if target.kind == "hero" and source.get("kind", "") == "boss":
		target.force_boss = source.id
	var critical = false
	var periodic = context.get("kind", "attack") == "periodic"
	if not source.is_empty() and not periodic and not context.get("true_damage", false):
		var debuff_bonus: float = w.passives.value(source, 44) if w.passives.has_buff(target, true) else 0.0
		if traits.missed(source, target, magical, context) or w.rng.stream("defense.combat").next_int(10000) < maxf(0, U.stat(target, 16) - U.stat(source, 15)) * 100:
			w.cue("number", target.pos, {"text": "闪避"})
			w.skills.trigger(target, "miss", source)
			return 0
		critical = source.kind == "hero" and w.rng.stream("defense.combat").next_int(10000) < (U.stat(source, 7) + debuff_bonus) * 100
		if source.kind == "hero" and context.get("guaranteed_crit", false):
			critical = true
		if critical:
			value *= 1 + U.stat(source, 8) / (100.0 if magical else maxf(0.001, 100 + U.stat(source, 25)))
		if target.kind == "hero" and source.side != target.side and w.gems.hero_block_hit(target, context):
			w.cue("number", target.pos, {"text": "格挡", "color": "blue"})
			return 0
	var armors: Array = w.skills.thorns.direct_armors(source, target, context) if allow_trigger else []
	value *= w.gems.damage_multiplier(source, target, context)
	value = mitigation.apply(source, target, value, magical, context)
	value *= maxf(0, float(context.get("final_multiplier", 1.0)))
	value = protection.protect_lethal(target, value)
	var actual = apply_health_damage(target, value)
	protection.hurt(target, actual)
	w.gems.low_hp_trigger(target)
	w.skills.thorns.retaliate(source, armors)
	target.stats.taken += actual
	if not source.is_empty():
		var credited = source if source.owner == 0 else w.units.get(source.owner, source)
		credited.stats.damage += actual
		source.hits += 1
		var leech = 0.0 if periodic else U.stat(source, 20 if magical else 19)
		if leech > 0:
			heal(source, source, actual * leech / 100.0)
	w.cue("number", target.pos, {"text": str(roundi(value)), "critical": critical, "color": "yellow" if critical else "white"})
	if allow_trigger and depth < 4:
		depth += 1
		w.skills.trigger(target, "hurt", source, actual)
		if critical and not source.is_empty():
			w.skills.trigger(source, "critical", target)
		depth -= 1
	if U.hp(target) <= 0:
		defeat(target, source)
	return actual
func true_damage(source: Dictionary, target: Dictionary, value: float, context: Dictionary = {}) -> float:
	var data = context.duplicate(true)
	data["true_damage"] = true
	data["kind"] = data.get("kind", "true")
	return hit(source, target, value, true, true, data)
func apply_health_damage(target: Dictionary, value: float) -> float:
	var actual = minf(U.hp(target), value)
	target.core.attributes.set_value("hp", maxf(0, U.hp(target) - value))
	return actual
func heal(source: Dictionary, target: Dictionary, value: float, triggers: bool = true, source_scale: float = -1) -> void:
	if target.is_empty() or target.dead:
		return
	value *= (1 + U.stat(source, 22) / 100.0 if source_scale < 0 else source_scale) * maxf(0.1, 1 + U.stat(target, 21) / 100.0)
	var actual = minf(maxf(0, U.stat(target, 1) - U.hp(target)), value)
	target.core.attributes.set_value("hp", U.hp(target) + actual)
	if not source.is_empty():
		source.stats.heal += actual
	if actual >= 1:
		w.cue("number", target.pos, {"text": "+%d" % actual, "color": "green"})
	if triggers:
		w.passives.on_heal(target, actual, maxf(0, value - actual))
		if depth < 4 and actual > 0:
			depth += 1
			w.skills.trigger(source, "heal", target)
			w.skills.trigger(target, "be_healed", source)
			depth -= 1
func execute(source: Dictionary, target: Dictionary) -> void:
	if target.dead:
		return
	var remaining = U.hp(target)
	target.stats.taken += remaining
	var credited: Dictionary = source if source.owner == 0 else w.units.get(source.owner, source)
	credited.stats.damage += remaining
	w.cue("number", target.pos, {"text": "斩杀", "color": "yellow"})
	defeat(target, source)
func defeat(target: Dictionary, source: Dictionary) -> void:
	if target.dead:
		return
	target.core.attributes.set_value("hp", 0)
	for state in target.statuses.duplicate():
		w.statuses.remove(target, state, "death")
	w.skills.trigger(target, "death_begin", target)
	if U.hp(target) > 0:
		return
	target.dead = true
	w.space.release(target)
	target.attack_events.clear()
	target.pending_actions.clear()
	target["channel_at"] = 0
	target.channel_skills.clear()
	target.channel_deadline = -1
	target.core.lifecycle = "dead"
	target.death_count += 1
	target["death_pose"] = {"action": target.action, "elapsed": roundi((w.time_ms - target.action_at) * target.action_rate)}
	target.action = "death"
	target.action_at = w.time_ms
	target.action_rate = 1.0
	var death_duration = target.corpse_ms
	for frame in target.motion.frames.get("die", []):
		death_duration += int(frame)
	target.death_finished = false
	target.death_finish_at = w.time_ms + death_duration
	target.remove_at = target.death_finish_at + 16
	if target.kind == "hero":
		w.deaths += 1
		target.revive_at = w.time_ms + roundi(maxf(1, U.stat(target, 23) - w.gems.revive_reduction(target)) * 1000)
		w.gems.on_hero_death(target)
		for id in w.heroes:
			if id != target.id:
				w.skills.trigger(w.units[id], "ally_death", target)
		if w.gems.try_instant_revive():
			w.factory.revive_hero(target)
	elif target.owner > 0 and target.side == 1:
		w.skills.trigger(w.units.get(target.owner, {}), "summon_death", target)
	elif target.side == 2:
		if not str(target.get("encounter_id", "")).is_empty():
			w.spawn.on_encounter_defeat(target)
		elif target.kind != "boss":
			w.kills += 1
		w.loot.drop(target)
	if not source.is_empty():
		source.kills += 1
		if depth < 4:
			depth += 1
			w.skills.trigger(source, "kill", target)
			depth -= 1
	w.events.append({"type": "unit_died", "unit": target.id, "kind": target.kind})
func apply_skill(source: Dictionary, target: Dictionary, skill: Dictionary) -> void:
	var amount = 0.0
	var percent = 0.0
	var healing = false
	var no_damage = false
	for entry in skill.get("damage", []):
		var p = C.numbers(entry)
		if p.size() < 2:
			continue
		var mode = int(p[2]) if p.size() > 2 else 0
		var related = correlation(source, target, int(p[0]))
		if mode == 4:
			percent += related * p[1] / 100.0
		elif mode == 2:
			no_damage = true
		elif mode in [5, 6]:
			target.shield += related * p[1] / 100.0
		else:
			amount += related * p[1] / 100.0
			healing = mode == 1
	amount *= 1 + percent / 100.0
	if healing:
		heal(source, target, amount)
	elif not no_damage:
		var tags = str(skill.get("damage_type", "")).split(";")
		var bonus: float = float(skill.get("bonus_damage", 0)) / 100.0
		if "0" in tags:
			bonus += U.stat(source, 12) / 100.0
		if "1" in tags:
			bonus += U.stat(source, 25) / 100.0
		if "5" in tags and not "0" in tags and not "1" in tags:
			bonus = 0
		hit(source, target, amount * (1 + bonus) * float(skill.get("damage_scale", 1)), true, true, {"kind": "periodic" if skill.get("periodic", false) else "skill", "tags": tags})
		if "6" in tags:
			w.skills.trigger(source, "attack", target)
			w.skills.trigger(target, "physical_hurt", source)
	for status in skill.get("statusChange", []):
		if status.size() >= 2:
			var probability = float(status[2]) if status.size() > 2 else 100.0
			if w.rng.stream("defense.combat").next_int(100) < probability:
				w.statuses.add(target, source, int(status[0]), float(status[1]) * 1000, float(skill.get("periodic_speed_ratio", 0)))
func correlation(source: Dictionary, target: Dictionary, kind: int) -> float:
	match kind:
		0: return U.stat(source, 4)
		1: return U.stat(source, 1)
		2: return U.stat(source, 10)
		3: return U.stat(source, 2)
		4: return U.stat(source, 6)
		5: return U.stat(source, 17)
		6: return U.hp(source)
		7: return U.stat(source, 1) - U.hp(source)
		8: return U.stat(target, 1)
	return 0
func apply_wall(source: Dictionary, skill: Dictionary) -> void:
	if skill.get("periodic", false) and not skill.get("affects_statue", false):
		return
	var amount = 0.0
	var healing = false
	for entry in skill.get("damage", []):
		var parts = C.numbers(entry)
		if parts.size() < 2:
			continue
		var mode = int(parts[2]) if parts.size() > 2 else 0
		if mode == 2:
			continue
		healing = mode == 1
		var base = w.wall_max if int(parts[0]) == 8 else correlation(source, source, int(parts[0]))
		amount += base * parts[1] / 100.0
	if healing:
		amount *= 1 + U.stat(source, 22) / 100.0
		var actual = minf(amount, maxf(0, w.wall_max - w.wall_hp))
		w.wall_hp += actual
		source.stats.heal += actual
	else:
		hit_wall(amount, {"direct": true, "source": source, "skill": skill})
func hit_wall(amount: float, context: Dictionary = {}) -> void:
	if not context.get("direct", true) and not context.get("affects_statue", false):
		return
	if w.statue_immune_until > w.time_ms:
		return
	if w.statue_protection_left > 0:
		w.statue_protection_left -= 1
		return
	var actual = minf(w.wall_hp, maxf(0, amount - w.statue_damage_reduction))
	if actual <= 0:
		return
	w.wall_hp -= actual
	w.gems.on_statue_damage(actual)
	w.cue("wall_hit", Statue.BODY_CENTER, {"text": "-%d" % actual})
	if not w.statue_grace_used and w.wall_hp < w.wall_max * 0.25:
		for definition: Dictionary in w.gems.active:
			if definition.effect.get("type", "") == "statue_grace":
				w.statue_grace_used = true
				w.statue_immune_until = w.time_ms + int(definition.effect.duration_ms)
				break
