class_name DefenseAssassination
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
var w

func _init(world) -> void:
	w = world

func basic_hit(owner: Dictionary, target: Dictionary) -> void:
	if target.dead:
		return
	for state in owner.skills.values():
		if state.data.has("assassination") and state.data.assassination.shock:
			var config: Dictionary = state.data.assassination
			w.statuses.add(target, owner, int(config.shock_status), float(config.shock_ms))

func cast(owner: Dictionary, skill: Dictionary, target: Dictionary) -> bool:
	var selected: Array = w.targets.select(owner, skill, target)
	if selected.is_empty():
		return false
	target = selected[0]
	var config: Dictionary = skill.assassination
	var state: Dictionary = owner.skills[int(skill.__id__)]
	var percent = float(config.damage_percent) + (float(config.hunt_bonus) if state.get("hunt_ready", false) else 0.0)
	state["hunt_ready"] = false
	owner.pos = target.pos
	owner.back_lock = false
	var tint := str(skill.get("visual_tint", "#ffe45b"))
	if "109" in str(skill.get("damage_type", "")).split(";"):
		tint = "#ffe45b"
	w.cue("effect", target.pos, {"res": "hero17:kill", "duration": 500, "loop": false, "scale": 2.0,
		"visual_tint": tint, "assassin_visual": "strike"})
	for i in range(2 if config.combo else 1):
		if target.dead or owner.dead:
			break
		var before = int(owner.hits)
		var multiplier = float(config.elite_multiplier) if config.execute and target.kind in ["elite", "boss"] else 1.0
		damage(owner, target, skill, percent, config.execute, multiplier)
		var landed = int(owner.hits) > before
		if landed and not target.dead:
			if config.paralyze:
				w.statuses.add(target, owner, int(config.paralyze_status), float(config.paralyze_ms))
			if config.execute and target.kind == "enemy" and U.hp(target) < U.stat(target, 1) * float(config.execute_threshold) / 100.0:
				w.damage.execute(owner, target)
		if target.dead and config.hunt:
			state.next = w.time_ms
			state["hunt_ready"] = true
	if not owner.dead and config.smoke:
		area(owner, skill, float(config.smoke_radius), float(config.smoke_damage), int(config.smoke_status), float(config.smoke_ms), "hero17:smokeBoom", "smoke")
	if not owner.dead and config.fan:
		area(owner, skill, float(config.fan_radius), float(config.fan_damage), int(config.paralyze_status), float(config.fan_ms), "bullet2:lightRing3", "fan")
	var shield_pct = w.gems.assassination_shield_pct(owner)
	if shield_pct > 0 and not owner.dead:
		owner.shield += U.stat(owner, 1) * shield_pct / 100.0
		owner["gem_assassination_shield"] = U.stat(owner, 1) * shield_pct / 100.0
		owner["gem_assassination_shield_until"] = w.time_ms + w.gems.assassination_shield_duration(owner)
	return true

func damage(owner: Dictionary, target: Dictionary, skill: Dictionary, percent: float, ignore_defense: bool = false, final_multiplier: float = 1.0) -> void:
	var value = U.stat(owner, 4) * percent / 100.0 * maxf(0, 1 + U.stat(owner, 12) / 100.0)
	w.damage.hit(owner, target, value, true, true, {"kind": "skill", "tags": str(skill.damage_type).split(";"), "ignore_defense": ignore_defense, "final_multiplier": final_multiplier,
		"guaranteed_crit": w.gems.guaranteed_crit(owner)})

func area(owner: Dictionary, skill: Dictionary, radius: float, percent: float, status: int, duration: float, res: String, visual: String) -> void:
	w.cue("effect", owner.pos, {"res": res, "duration": 500, "loop": false, "scale": radius / 200.0,
		"visual_tint": skill.visual_tint, "assassin_visual": visual, "layer": -1 if visual == "smoke" else 0})
	for target in w.targets.area(owner, owner.pos, radius):
		if w.targets.hidden_enemy(owner, target):
			continue
		var before = int(owner.hits)
		damage(owner, target, skill, percent)
		if int(owner.hits) > before and not target.dead:
			w.statuses.add(target, owner, status, duration)
