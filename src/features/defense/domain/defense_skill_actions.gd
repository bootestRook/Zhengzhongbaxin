class_name DefenseSkillActions
extends RefCounted

const C = preload("res://src/features/defense/domain/defense_catalog.gd")
var w

func _init(world) -> void:
	w = world

func begin(unit: Dictionary, state: Dictionary, target: Dictionary, combat: bool, count: int) -> bool:
	var cast_range = float(state.data.get("cast_range", 0))
	if cast_range > 0 and w.targets.nearest(unit, cast_range).is_empty():
		return false
	var selected: Array = w.skills.thorns.targets(unit, state.data) if state.data.has("thorn_armor") else w.targets.select(unit, state.data, target)
	if selected.is_empty():
		return false
	var continued = int(state.data.get("isContinued", 0))
	var action = "attack" if combat or continued == 4 else "idle"
	if not combat and continued in [1, 2]:
		action = "skill"
	var frames: Array = unit.motion.get("frames", {}).get(action, [])
	var rate = w.ai.animation_rate(unit)
	var duration = 0
	var emit_at = 0
	for index in range(frames.size()):
		if (action == "attack" and unit.motion.get("valid", []).has(index + 1)) or (action == "skill" and index == frames.size() - 1):
			emit_at = duration
		duration += int(frames[index])
	duration = roundi(duration / rate)
	emit_at = roundi(emit_at / rate)
	unit.action = action
	unit.back_lock = false
	unit.action_at = w.time_ms
	unit.action_rate = rate
	unit.action_until = w.time_ms + duration
	if continued == 2:
		unit.channel_at = w.time_ms + (emit_at if combat else duration)
		unit.channel_skills = {int(state.data.__id__): true}
		unit.channel_deadline = -1
		unit.action_until = 2147483647
	unit.attack_events.clear()
	if combat:
		unit.attack_at = unit.action_until + w.ai.period(unit)
	state.next = w.time_ms + roundi(float(state.data.get("cd", 0)) * w.passives.cooldown(unit))
	if int(C.number(state.data.type)) == 3 and int(state.data.get("damage_num", 0)) <= 0:
		state.next = 2147483647
	w.skills.queue.append({"at": w.time_ms + emit_at, "owner": unit.id, "skill": state.data.__id__, "target": target.get("id", 0), "pos": Vector2.INF, "action": true, "combat": combat, "count": count})
	return true

func track(unit: Dictionary, skill: Dictionary) -> void:
	if int(skill.get("isContinued", 0)) != 2 or unit.channel_skills.is_empty():
		return
	unit.channel_skills[int(skill.__id__)] = true
	if skill.has("damage_num") and skill.has("damage_interval"):
		var interval = C.number(skill.get("parameters", []), 0, 0.1)
		if interval <= 0:
			interval = 0.1
		var span = float(skill.damage_interval) * int(skill.damage_num) + interval * maxi(0, int(C.number(skill.get("running_fire", 1))) - 1)
		unit.channel_deadline = maxi(unit.channel_deadline, maxi(w.time_ms, unit.channel_at) + roundi(span * 1000))

func advance(unit: Dictionary) -> void:
	if unit.channel_skills.is_empty() or w.time_ms < unit.channel_at:
		return
	if unit.action != "skill2":
		unit.action = "skill2"
		unit.action_at = unit.channel_at
		unit.action_rate = 1.0
	var active = false
	for p in w.missiles:
		if p.owner == unit.id and unit.channel_skills.has(int(p.skill.get("__id__", 0))):
			active = true
			break
	for entry in w.skills.queue:
		if entry.owner == unit.id and unit.channel_skills.has(entry.skill):
			active = true
			break
	var frames: Array = unit.motion.frames.get("skill2", unit.motion.frames.get("attack", []))
	var loop_ms = 0
	for frame in frames:
		loop_ms += int(frame)
	var finished = unit.channel_deadline >= 0 and w.time_ms >= maxi(unit.channel_deadline, unit.action_at + loop_ms)
	if active and not finished:
		return
	unit.channel_skills.clear()
	unit.channel_at = 0
	unit.channel_deadline = -1
	unit.action_until = w.time_ms
	unit.attack_at = w.time_ms + w.ai.period(unit)
	w.ai.set_action(unit, "idle")
