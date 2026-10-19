class_name DefenseSkills
extends RefCounted
const C = preload("res://src/features/defense/domain/defense_catalog.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Graph = preload("res://src/features/defense/domain/defense_cast_graph.gd")
const Fire = preload("res://src/features/defense/domain/defense_fire_patterns.gd")
const Actions = preload("res://src/features/defense/domain/defense_skill_actions.gd")
const Fireball = preload("res://src/features/defense/domain/defense_fireball.gd")
const Thorns = preload("res://src/features/defense/domain/defense_thorns.gd")
const Ice = preload("res://src/features/defense/domain/defense_ice_arrows.gd")
const Assassination = preload("res://src/features/defense/domain/defense_assassination.gd")
var w
var definitions: Dictionary
var queue: Array = []
var depth: int = 0
var graph
var fire
var actions
var fireball
var thorns
var ice
var assassination
var chain_counts: Dictionary = {}
func _init(world) -> void:
	w = world
	definitions = w.catalog.records("skills")
	graph = Graph.new()
	fire = Fire.new(world)
	actions = Actions.new(world)
	fireball = Fireball.new(world)
	thorns = Thorns.new(world)
	ice = Ice.new(world)
	assassination = Assassination.new(world)
func reset() -> void:
	queue.clear()
	depth = 0
	chain_counts.clear()
	fireball.charges.clear()
	thorns.reset()
func learn(unit: Dictionary, id: int, temporary: bool = false) -> void:
	if unit.skills.has(id):
		if not temporary:
			unit.skills[id]["temporary"] = false
		return
	var data: Dictionary = definitions.get(str(id), {})
	if not data.has("type"):
		w.note("missing_skill.%d" % id)
		return
	data = data.duplicate(true)
	for field in ["statusChange", "actionOth", "skillGroupType"]:
		if not data.has(field):
			data[field] = []
	for option_id in unit.upgrades:
		var option = w.catalog.record("options", int(option_id))
		if w.upgrades.matches(data, option):
			w.upgrades.modify(data, option)
	unit.skill_order += 1
	unit.skills[id] = {"data": data, "next": w.time_ms, "count": 0, "summons": [], "order": unit.skill_order, "temporary": temporary}
func trigger(unit: Dictionary, event: String, target: Dictionary, damage_taken: float = 0) -> bool:
	if unit.is_empty() or depth > 6:
		return false
	var fired = false
	for sid in unit.skills.keys():
		if not unit.skills.has(sid):
			continue
		var state: Dictionary = unit.skills[sid]
		for trigger_value in state.data.get("triggerOpp", []):
			var parts = C.numbers(trigger_value)
			if parts.is_empty() or not event_matches(int(parts[0]), event):
				continue
			var type = int(parts[0])
			var value: float = parts[1] if parts.size() > 1 else 1
			if w.time_ms < state.next:
				continue
			var repetitions = 1
			if type == 7:
				state["damage_total"] = float(state.get("damage_total", 0)) + damage_taken
				var threshold = maxf(1, U.stat(unit, 1) * value / 100.0)
				if state.damage_total <= threshold:
					continue
				repetitions = int(state.damage_total / threshold)
				state.damage_total -= repetitions * threshold
			if type == 8:
				if state.get("threshold_used", false) or U.hp(unit) >= U.stat(unit, 1) * value / 100.0:
					continue
				state["threshold_used"] = int(state.data.get("cd", 0)) <= 0
			state.count += 1
			var count = int(state.count)
			if type == 6:
				var counts: Dictionary = state.get("target_counts", {})
				counts[target.get("id", 0)] = int(counts.get(target.get("id", 0), 0)) + 1
				state["target_counts"] = counts
				count = counts[target.get("id", 0)]
			if type in [2, 4, 6, 26] and count % maxi(1, int(value)) != 0:
				continue
			if type in [3, 5, 9, 10, 15, 27, 28] and value < 100 and w.rng.stream("defense.combat").next_int(100) >= value:
				continue
			var trigger_target: Dictionary = {} if type == 4 else target
			if int(state.data.get("isContinued", 0)) in [1, 2, 4] and event not in ["death_begin", "death_after"]:
				unit.pending_actions.append({"skill": sid, "target": trigger_target.get("id", 0), "count": repetitions})
				fired = true
			else:
				for i in range(repetitions):
					fired = cast(unit, state.data, trigger_target, Vector2.INF, type in [9, 10]) or fired
			state.next = w.time_ms + roundi(float(state.data.get("cd", 0)) * w.passives.cooldown(unit))
	return fired
func event_matches(type: int, event: String) -> bool:
	match event:
		"combat": return type == 18
		"attack_begin": return type == 4
		"attack": return type in [5, 6]
		"attack_emit": return type in [15, 26]
		"hurt": return type in [7, 8]
		"physical_hurt": return type in [2, 3]
		"kill": return type == 11
		"critical": return type == 12
		"revive": return type == 19
		"ally_revive": return type == 23
		"ally_death": return type == 20
		"ally_enter": return type == 24
		"death_begin": return type == 9
		"death_after": return type == 10
		"miss": return type == 13
		"heal": return type in [14, 16]
		"be_healed": return type == 17
		"summon_death": return type == 31
		"cooldown_fire": return type in [27, 28]
		"wave": return type == 25
		"enter": return type == 21
	return false
func tick() -> void:
	var due: Array = []
	for i in range(queue.size() - 1, -1, -1):
		if queue[i].at <= w.time_ms:
			due.push_front(queue[i])
			queue.remove_at(i)
	for entry in due:
		var owner: Dictionary = w.units.get(entry.owner, {})
		if owner.is_empty() or (owner.dead and not entry.get("death_cast", false)) or not owner.skills.has(entry.skill):
			continue
		if entry.get("action", false) and w.statuses.prevents(owner, "attack"):
			continue
		if entry.get("ice_combo", false): ice.repeat_attack(owner, entry.data, w.units.get(entry.target, {}), entry.group); continue
		if entry.get("burst", false):
			var burst_skill: Dictionary = owner.skills[entry.skill].data.duplicate(true)
			burst_skill["death_cast"] = entry.get("death_cast", false)
			fire.wave(owner, burst_skill, w.units.get(entry.target, {}), entry.pos, entry.copies, false, [], entry.fire_index)
			continue
		for i in range(int(entry.get("count", 1))):
			cast(owner, owner.skills[entry.skill].data, w.units.get(entry.target, {}), entry.pos, entry.get("death_cast", false))
		if entry.get("combat", false):
			trigger(owner, "attack_begin", w.units.get(entry.target, {}))
			trigger(owner, "attack_emit", w.units.get(entry.target, {}))
			if not owner.channel_skills.is_empty() and owner.channel_at <= w.time_ms:
				owner.action = "skill2"
				owner.action_at = owner.channel_at
				owner.action_rate = 1.0
func ready_action(unit: Dictionary) -> bool:
	if w.statuses.prevents(unit, "attack"):
		return false
	var states: Array = unit.skills.values()
	states.sort_custom(func(a, b):
		var ap = C.number(a.data.type, 2)
		var bp = C.number(b.data.type, 2)
		return ap > bp if ap != bp else int(a.get("order", 0)) < int(b.get("order", 0)))
	for state: Dictionary in states:
		for entry in state.data.get("triggerOpp", []):
			if int(C.number(entry)) == 1 and w.time_ms >= state.next:
				if begin_action(unit, state, {}, false):
					return true
	return false
func combat_action(unit: Dictionary, target: Dictionary) -> bool:
	for state: Dictionary in unit.skills.values():
		if w.targets.has_combat_trigger(state.data) and w.time_ms >= state.next:
			if begin_action(unit, state, target, true):
				unit.attacks += 1
				return true
	return false
func pending_action(unit: Dictionary) -> bool:
	if unit.pending_actions.is_empty() or w.statuses.prevents(unit, "attack"):
		return false
	var entry: Dictionary = unit.pending_actions.pop_front()
	if not unit.skills.has(entry.skill):
		return false
	return begin_action(unit, unit.skills[entry.skill], w.units.get(entry.target, {}), false, entry.count)
func begin_action(unit: Dictionary, state: Dictionary, target: Dictionary, combat: bool, count: int = 1) -> bool:
	return actions.begin(unit, state, target, combat, count)
func cast(owner: Dictionary, skill: Dictionary, target: Dictionary, origin: Vector2 = Vector2.INF, death_cast: bool = false) -> bool:
	if depth > 6 or ((owner.dead or w.statuses.prevents(owner, "skill")) and not death_cast):
		return false
	skill = w.gems.modify_skill(owner, skill)
	if skill.has("assassination"):
		return assassination.cast(owner, skill, target)
	if skill.has("fireball"):
		return fireball.cast(owner, skill)
	if skill.has("thorn_armor"):
		return thorns.cast(owner, skill)
	if skill.has("ice_arrows"):
		return ice.cast(owner, skill, target)
	if death_cast:
		skill = skill.duplicate(true)
		skill["death_cast"] = true
	var kind = int(C.number(skill.type))
	var selected: Array = w.targets.select(owner, skill, target, 0, origin)
	if selected.is_empty() and skill.get("aim", []).is_empty():
		selected = [{"id": 0, "pos": w.targets.attack_point(owner) if origin == Vector2.INF else origin, "dead": false} if target.is_empty() else target]
	if selected.is_empty():
		return false
	actions.track(owner, skill)
	if skill.get("actionOth", []).any(func(effect): return not effect.is_empty() and str(effect[0]) == "ridicule"):
		w.cue("skill_text", owner.pos, {"source_id": owner.id, "text": "嘲讽", "duration": 900})
	var copies = maxi(1, 1 + int(C.number(skill.get("salvo", 0))))
	if not skill.get("sound", []).is_empty():
		w.events.append({"type": "sound", "name": str(skill.sound[0])})
	if w.rng.stream("defense.combat").next_int(100) < w.passives.value(owner, 35):
		copies += 1
	var repeats = maxi(1, int(C.number(skill.get("running_fire", 1))))
	fire.wave(owner, skill, target, origin, copies, true, selected)
	var interval = roundi(C.number(skill.get("parameters", []), 0, 0.1) * 1000)
	if interval <= 0:
		interval = 100
	for j in range(1, repeats):
		queue.append({"at": w.time_ms + j * interval, "owner": owner.id, "skill": int(skill.__id__),
			"target": target.get("id", 0), "pos": origin, "burst": true, "copies": copies, "fire_index": j, "death_cast": death_cast})
	depth += 1
	if int(skill.get("cd", 0)) > 0:
		trigger(owner, "cooldown_fire", target, float(skill.cd))
	chain(owner, skill, 5, target, owner.pos)
	depth -= 1
	return true
func chain(owner: Dictionary, skill: Dictionary, event: int, target: Dictionary, pos: Vector2, projectile: int = 0) -> void:
	for group in skill.get("skillGroupType", []):
		if group.size() < 2 or int(group[0]) != event or not owner.skills.has(int(group[1])):
			continue
		if group.size() > 3 and w.rng.stream("defense.combat").next_int(100) >= float(group[3]):
			continue
		if group.size() > 2 and int(group[2]) > 0:
			var frequency = int(group[2])
			var key = "%d_%d" % [int(group[1]), frequency]
			if event in [8, 11]:
				key += "_%d" % projectile
			if not chain_counts.has(key):
				chain_counts[key] = 1
				continue
			if int(chain_counts[key]) < frequency - 1:
				chain_counts[key] += 1
				continue
			chain_counts[key] = 0
		queue.append({"at": w.time_ms + 16, "owner": owner.id, "skill": int(group[1]), "target": target.get("id", 0), "pos": pos, "death_cast": skill.get("death_cast", false)})
