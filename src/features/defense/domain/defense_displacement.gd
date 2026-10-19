class_name DefenseDisplacement
extends RefCounted

static func throw_unit(w, owner: Dictionary, impact: Dictionary, skill: Dictionary, rule_id: int) -> void:
	var source: Dictionary = owner.duplicate()
	source.pos = impact.pos
	var candidates: Array = w.targets.select_rule(source, {"attack_range": 500}, w.targets.definitions.get(str(rule_id), {}), impact, [impact.id])
	if candidates.is_empty():
		return
	var u: Dictionary = w.units.get(candidates[0].id, {})
	if u.is_empty() or w.damage.protection.blocks_displacement(u):
		return
	var from: Vector2 = u.pos
	var to: Vector2 = impact.pos
	var half = (to - from) / 2
	var control = from + Vector2(half.x if absf(half.x) > absf(half.y) else half.x / 2, -absf(half.x))
	u["forced_motion"] = {"type": "throw", "from": from, "to": to, "control": control,
		"start": w.time_ms, "duration": maxi(1, floori(from.distance_to(to) / maxf(1, float(skill.get("speed", 1))) * 1000))}
	u.attack_events.clear()
	u.action_until = w.time_ms
	u.action = "idle"
	u.action_at = w.time_ms
	w.space.release(u)

static func tick(w, u: Dictionary) -> bool:
	if not u.has("forced_motion"):
		return false
	if w.damage.protection.blocks_displacement(u):
		u.erase("forced_motion")
		return false
	var motion: Dictionary = u.forced_motion
	if motion.get("type", "hook") == "push":
		var progress = clampf(float(w.time_ms - motion.start) / motion.duration, 0, 1)
		u.pos = motion.from.lerp(motion.to, progress)
		if progress >= 1:
			u.erase("forced_motion")
		return true
	if motion.get("type", "hook") == "throw":
		var t = clampf(float(w.time_ms - motion.start) / motion.duration, 0, 1)
		u.pos = bezier(motion.from, motion.control, motion.to, t)
		if t >= 1:
			u.erase("forced_motion")
		return true
	var owner: Dictionary = w.units.get(motion.owner, {})
	if owner.is_empty() or owner.dead or w.statuses.prevents(u, "move") or u.pos.distance_to(owner.pos) <= 60:
		u.erase("forced_motion")
		return false
	u.pos = u.pos.move_toward(owner.pos, motion.speed * 0.016)
	if u.action != "walk":
		u.action = "walk"
		u.action_at = w.time_ms
	return true

static func bezier(from: Vector2, control: Vector2, to: Vector2, t: float) -> Vector2:
	return from * (1 - t) * (1 - t) + control * 2 * t * (1 - t) + to * t * t
