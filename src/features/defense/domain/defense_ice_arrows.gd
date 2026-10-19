class_name DefenseIceArrows
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
const C = preload("res://src/features/defense/domain/defense_catalog.gd")
const COMBO_DELAY_MS = 300
var w

func _init(world) -> void:
	w = world

func chance(value: float) -> bool:
	return value > 0 and w.rng.stream("defense.combat").next_int(10000) < value * 100

func cast(owner: Dictionary, skill: Dictionary, target: Dictionary) -> bool:
	var selected: Array = w.targets.select(owner, skill, target)
	if selected.is_empty():
		return false
	var group = {"knocked": []}
	if skill.ice_arrows.focus:
		gain_focus(owner, skill)
	fire(owner, skill, selected[0], group)
	after_attack(owner, skill, selected[0], group)
	return true

func fire(owner: Dictionary, skill: Dictionary, target: Dictionary, group: Dictionary) -> void:
	var count = int(skill.ice_arrows.copies)
	for i in range(count):
		arrow(owner, skill, target, false, group, Vector2.INF, i)
	w.events.append({"type": "sound", "name": "arrow2"})

func after_attack(owner: Dictionary, skill: Dictionary, target: Dictionary, group: Dictionary) -> void:
	var config: Dictionary = skill.ice_arrows
	if chance(config.rain_chance):
		rain(owner, skill, target.pos)
	if chance(config.combo_chance):
		w.skills.queue.append({"at": w.time_ms + COMBO_DELAY_MS, "owner": owner.id, "target": target.id,
			"skill": int(skill.__id__), "pos": Vector2.INF, "ice_combo": true, "data": skill.duplicate(true), "group": group})

func repeat_attack(owner: Dictionary, skill: Dictionary, target: Dictionary, group: Dictionary) -> void:
	if w.statuses.prevents(owner, "skill") or w.statuses.prevents(owner, "attack"):
		return
	var selected: Array = w.targets.select(owner, skill, target)
	if selected.is_empty():
		return
	# The delayed volley shares knockback limits and never rolls cast procs again.
	fire(owner, skill, selected[0], group)
	w.events.append({"type": "skill_combo", "source": owner.id, "target": selected[0].id, "skill": int(skill.__id__), "delay_ms": COMBO_DELAY_MS})

func arrow(owner: Dictionary, skill: Dictionary, target: Dictionary, bounced: bool, group: Dictionary, origin: Vector2, salvo_index: int = 0) -> Dictionary:
	var data: Dictionary = skill.duplicate(true)
	data.erase("ice_arrows")
	data["ice_shot"] = {"config": skill.ice_arrows.duplicate(true), "bounced": bounced}
	data["type"] = "9:1:10"
	data["damage_num"] = 1 if bounced else 1 + int(skill.ice_arrows.pierce)
	data["salvo_index"] = salvo_index
	data["parameters"] = [0, skill.ice_arrows.spread_degrees]
	data["triggerOpp"] = []
	data["skillGroupType"] = []
	data["visual_tint"] = "#c9eeff" if skill.ice_arrows.upgraded else "#72d8ff"
	w.projectiles.launch(owner, target, data, origin, 0)
	var p: Dictionary = w.missiles[-1]
	p["ice_group"] = group
	return p

func impact(p: Dictionary, owner: Dictionary, target: Dictionary) -> void:
	if target.dead:
		return
	var shot: Dictionary = p.skill.ice_shot
	var config: Dictionary = shot.config
	damage(owner, target, p.skill, int(p.skill.__id__), float(config.bonus))
	if config.chill and not target.dead:
		chill(owner, target, config)
	if not target.dead and not p.ice_group.knocked.has(target.id) and chance(config.knock_chance):
		push(p, owner, target, config)
	if not shot.bounced and config.upgraded:
		var candidates: Array = w.targets.area(owner, p.pos, float(config.bounce_radius))
		candidates = candidates.filter(func(u): return u.id != target.id and not w.targets.hidden_enemy(owner, u))
		candidates.sort_custom(func(a, b):
			var da: float = p.pos.distance_squared_to(a.pos)
			var db: float = p.pos.distance_squared_to(b.pos)
			return a.id < b.id if da == db else da < db)
		if not candidates.is_empty():
			var skill: Dictionary = p.skill.duplicate(true)
			skill["ice_arrows"] = config
			var child = arrow(owner, skill, candidates[0], true, p.ice_group, p.pos)
			child.ignored.append(target.id)

func focus_stacks(owner: Dictionary, skill_id: int) -> int:
	var state: Dictionary = owner.skills.get(skill_id, {})
	var focus: Dictionary = state.get("ice_focus", {})
	if focus.is_empty():
		return 0
	if owner.dead or w.time_ms >= int(focus.until) or int(focus.life) != int(owner.death_count):
		state.erase("ice_focus")
		return 0
	return int(focus.stacks)

func gain_focus(owner: Dictionary, skill: Dictionary) -> void:
	var stacks = focus_stacks(owner, int(skill.__id__))
	owner.skills[int(skill.__id__)]["ice_focus"] = {"stacks": mini(int(skill.ice_arrows.focus_cap), stacks + 1),
		"until": w.time_ms + int(skill.ice_arrows.focus_ms), "life": owner.death_count}

func damage(owner: Dictionary, target: Dictionary, skill: Dictionary, root: int, bonus: float = 0, periodic: bool = false) -> void:
	var stacks = focus_stacks(owner, root)
	var attack = U.stat(owner, 4) + owner.core.attributes.base_value("4") * stacks / 100.0
	var value: float = attack * C.number(skill.damage[0], 1) / 100.0
	value *= 1 + bonus / 100.0 + (U.stat(owner, 12) + stacks) / 100.0
	w.damage.hit(owner, target, value, true, true, {"kind": "periodic" if periodic else "skill", "tags": str(skill.damage_type).split(";")})

func chill(owner: Dictionary, target: Dictionary, config: Dictionary) -> void:
	if w.statuses.has_status(target, int(config.freeze_status)):
		return
	w.statuses.add(target, owner, int(config.chill_status), float(config.chill_ms))
	for state in target.statuses.duplicate():
		if state.id == int(config.chill_status) and state.source == owner.id and state.stacks >= 5:
			w.statuses.remove(target, state)
			w.statuses.add(target, owner, int(config.freeze_status), float(config.freeze_ms))

func push(p: Dictionary, owner: Dictionary, target: Dictionary, config: Dictionary) -> void:
	if w.damage.protection.blocks_displacement(target):
		return
	p.ice_group.knocked.append(target.id)
	var from: Vector2 = target.pos
	var to: Vector2 = from + p.direction * float(config.knock_distance)
	to.x = clampf(to.x, w.combat.world.left, w.combat.world.right)
	to.y = clampf(to.y, w.combat.world.top, w.combat.world.bottom)
	target["forced_motion"] = {"type": "push", "from": from, "to": to, "start": w.time_ms, "duration": int(config.knock_ms)}
	target.attack_events.clear()
	target.action_until = w.time_ms
	w.space.release(target)

func rain(owner: Dictionary, skill: Dictionary, point: Vector2) -> void:
	var config: Dictionary = skill.ice_arrows
	var data: Dictionary = w.catalog.record("skills", int(config.rain_skill))
	data["ice_rain"] = config.duplicate(true)
	data["ice_source"] = int(skill.__id__)
	w.projectiles.launch(owner, {"id": 0, "pos": point, "dead": false}, data, point, 0)
	var p: Dictionary = w.missiles[-1]
	p["ice_frozen"] = []
	p.remaining = int(config.rain_ticks)
	p.interval = int(config.rain_interval_ms)
	p.radius = float(config.rain_radius)
	p.expires = w.time_ms + int(config.rain_ms)
	rain_tick(p, owner)

func rain_tick(p: Dictionary, owner: Dictionary) -> void:
	if w.time_ms >= p.expires:
		p.ended = true
		return
	while p.remaining > 0 and w.time_ms >= p.at:
		p.remaining -= 1
		p.at += p.interval
		for target in w.targets.area(owner, p.pos, p.radius):
			if w.targets.hidden_enemy(owner, target):
				continue
			damage(owner, target, p.skill, int(p.skill.ice_source), 0, true)
			if not p.ice_frozen.has(target.id) and not target.dead:
				p.ice_frozen.append(target.id)
				freeze_once(owner, target, p.skill.ice_rain)

func freeze_once(owner: Dictionary, target: Dictionary, config: Dictionary) -> void:
	# A short rain freeze must never shorten an existing three-second freeze.
	var until = 0
	for state in target.statuses:
		if state.id == int(config.freeze_status) and state.source == owner.id:
			until = int(state.expires)
	w.statuses.add(target, owner, int(config.freeze_status), float(config.rain_freeze_ms))
	for state in target.statuses:
		if state.id == int(config.freeze_status) and state.source == owner.id:
			state.expires = maxi(until, int(state.expires))
