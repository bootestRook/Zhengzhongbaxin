class_name DefenseUnits
extends RefCounted

const Attribute = preload("res://src/runtime/core/core_attribute_definition.gd")
const C = preload("res://src/features/defense/domain/defense_catalog.gd")
var w

func _init(world) -> void:
	w = world

func create(kind: String, template: int, pos: Vector2, side: int, owner_id: int = 0, spawn_entry: Dictionary = {}) -> Dictionary:
	var wave_index := int(spawn_entry.get("wave", w.spawn_wave))
	var wave: Dictionary = w.level.waves[clampi(wave_index - 1, 0, w.level.waves.size() - 1)]
	var bonus := 0.0
	var hp_factor := float(spawn_entry.get("hp_multiplier", wave.get("hp_multiplier", 1.0)))
	var atk_factor := float(spawn_entry.get("atk_multiplier", wave.get("atk_multiplier", 1.0)))
	return _build(kind, template, pos, side, owner_id, bonus, hp_factor, atk_factor, spawn_entry, wave_index)

func create_encounter(entry: Dictionary, pos: Vector2) -> Dictionary:
	var unit = create(str(entry.kind), int(entry.id), pos, 2, 0, entry)
	if not unit.is_empty():
		unit.encounter_wave = int(entry.wave)
		unit.encounter_id = str(entry.get("encounter_id", "legacy:%d:%d" % [int(entry.wave), int(entry.id)]))
		unit.encounter_row_id = int(entry.get("row_id", entry.id))
	return unit

func _build(kind: String, template: int, pos: Vector2, side: int, owner_id: int, bonus: float, hp_factor: float, atk_factor: float, spawn_entry: Dictionary = {}, spawn_wave_index: int = -1) -> Dictionary:
	if kind == "summon":
		template = w.upgrades.soldier_template(w.units.get(owner_id, {}), template)
	var source = w.catalog.record("heroes" if kind == "hero" else ("summons" if kind == "summon" else "monsters"), template)
	if source.is_empty():
		return {}
	var id: int = w.next_id
	w.next_id += 1
	var core = w.core.create_entity(str(id))
	var base: Dictionary = {}
	for key: String in w.attribute_defs:
		base[key] = float(w.attribute_defs[key].get("num", 0)) if kind == "hero" else 0.0
	if kind == "hero":
		base = source.base.duplicate(true)
		w.gems.apply_hero_base(source, base)
	else:
		var levels = w.level.chapter_data
		var hp_level: float = w.level_id + float(levels.get("hp_up", 0)) + float(w.level.raw.get("hp_up", 0)) + bonus
		var atk_level: float = w.level_id + float(levels.get("atk_up", 0)) + float(w.level.raw.get("atk_up", 0)) + bonus
		var hp_growth = 0.0
		for i in range(maxi(0, spawn_wave_index)):
			atk_level += float(w.level.atk_growth[mini(i, w.level.atk_growth.size() - 1)])
			hp_growth += float(w.level.hp_growth[mini(i, w.level.hp_growth.size() - 1)])
		base["1"] = (C.number(source.get("hp", "100")) + C.number(source.get("hp", "100"), 1) * hp_level) * (1.0 + hp_growth / 100.0)
		base["4"] = C.number(source.get("atk", "20")) + C.number(source.get("atk", "20"), 1) * atk_level
		base["6"] = float(source.get("atkSpe", 200))
		base["17"] = float(source.get("speed", 40))
		base["26"] = 0.0
		base["5"] = float(source.get("atkNum", 1))
		base["3"] = float(source.get("block", 0))
		if kind == "summon":
			var owner = w.units.get(owner_id, {})
			if not owner.is_empty():
				var summon_bonus = stat(owner, 13) + w.upgrades.soldier_bonus(owner, source.get("class", []))
				base["1"] = (C.number(source.hp) + C.number(source.hp, 1) + stat(owner, 1) * w.passives.value(owner, 29) / 100.0) * (1 + summon_bonus / 100.0)
				base["4"] = (C.number(source.atk) + C.number(source.atk, 1) + stat(owner, 4) * w.passives.value(owner, 21) / 100.0) * (1 + summon_bonus / 100.0)
				base["10"] = stat(owner, 10) * w.passives.value(owner, 30) / 100.0
		elif side == 2:
			base["1"] *= pow(1 + minf(w.level_id, 100) * 0.001, floor(w.spawn_wave / 3.0))
			base["1"] *= w.level.enemy_hp_multiplier * hp_factor
			base["4"] *= w.level.enemy_atk_multiplier * atk_factor
	for entry in source.get("characteristic", []):
		if str(entry[0]) == "defense":
			base["10"] = float(base.get("10", 0)) + float(base.get("4", 0)) * float(entry[1]) / 100.0
	for key: String in base:
		core.attributes.register_definition(Attribute.new(key, float(base[key])))
	core.attributes.register_definition(Attribute.new("hp", float(base.get("1", 100)), 0, INF))
	var metadata_key = ("hero" if kind == "hero" else ("soldierData" if kind == "summon" else "monsterData")) + ":" + str(template)
	var motion: Dictionary = w.combat.actors.get(metadata_key, {})
	var front: bool = str(motion.get("missile", "")).is_empty()
	var unit = {"id": id, "template": template, "kind": kind, "side": side, "owner": owner_id,
		"attack_delay_ms": int(source.attack_delay_ms) if kind == "hero" else 0,
		"base_attack_speed": float(base.get("6", 0)), "profession": int(source.get("profession", 0)) if kind == "hero" else 0,
		"element": str(source.get("element", "物理")) if kind == "hero" else "物理",
		"damage_type": source.damage_type if kind == "hero" else "1;6",
		"core": core, "res": source.get("res", ""), "name": source.get("name", "") if kind == "hero" else source.get("title", "召唤物"),
		"pos": pos, "home": pos, "front": front, "target": 0, "ai_at": 0, "attack_at": 0,
		"action": "idle", "action_at": 0, "facing": 1.0, "dead": false, "revive_at": 0,
		"remove_at": 0, "expires": 0, "skills": {}, "upgrades": [], "statuses": [],
		"attacks": 0, "hits": 0, "kills": 0, "passives": [], "stats": {"damage": 0.0, "taken": 0.0, "heal": 0.0},
		"shield": 0.0, "shield_hits": 0, "wave": w.spawn_wave, "class": source.get("class", []),
		"encounter_wave": 0, "encounter_id": "", "encounter_row_id": 0,
		"health_bars": maxi(1, int(spawn_entry.get("health_bars", 1))),
		"radius": float(motion.get("foot_radius", 0)), "body_radius": C.number(motion.get("body_size", [0, 0])) / 2, "death_count": 0,
		"motion": motion, "blocked_by": 0, "row_index": 0, "back_lock": false, "entering": kind == "hero", "guard_return": false,
		"attack_events": [], "action_until": 0, "action_rate": 1.0, "taunt": 0, "taunt_until": 0,
		"channel_at": 0, "channel_skills": {}, "channel_deadline": -1,
		"force_boss": 0,
		"traits": source.get("characteristic", []),
		"pending_actions": [],
		"skill_order": 0,
		"active_level": 0,
		"corpse_ms": int(source.get("corpse", 0)), "death_finished": false, "death_finish_at": 0,
		"death_pose": {"action": "idle", "elapsed": 0},
		"entry_speed_bonus": maxf(0, 240 - w.spawn_wave * 40) if side == 2 else 0.0}
	w.units[id] = unit
	w.space.register(unit)
	for sid in source.get("skills" if kind == "hero" else "skill", []):
		w.skills.learn(unit, int(sid))
	if kind == "summon":
		w.upgrades.soldier_skills(w.units.get(owner_id, {}), unit)
	return unit

func add_hero(hero_id: int) -> bool:
	if w.heroes.size() >= w.rules.hero_limit:
		return false
	for id in w.heroes:
		if w.units[id].template == hero_id:
			return false
	var definition = w.catalog.record("heroes", hero_id)
	if definition.is_empty() or not definition.available:
		return false
	var row: Array = []
	for id in w.heroes:
		if w.units[id].front == definition.front:
			row.append(id)
	var unit = create("hero", hero_id, hero_spawn(), 1)
	if unit.is_empty():
		return false
	w.heroes.append(unit.id)
	unit.row_index = row.size()
	for option_id in definition.initial_options:
		w.upgrades.apply(unit, int(option_id))
	if w.passives.value(unit, 43) > 0:
		w.pending.append(unit.id)
	reset_homes()
	w.skills.trigger(unit, "enter", {})
	summon_effect(unit.pos)
	for id in w.heroes:
		if id != unit.id:
			w.skills.trigger(w.units[id], "ally_enter", unit)
	w.events.append({"type": "hero_joined", "hero": hero_id})
	return true

func hero_spawn() -> Vector2:
	return Vector2(w.rules.hero_spawn[0], w.rules.hero_spawn[1])

func summon_effect(pos: Vector2, reviving: bool = false) -> void:
	for entry in [["battleEffect:summon2", -2], ["battleEffect:summon3", 1]]:
		w.cue("revive" if reviving else "effect", pos, {"res": entry[0], "scale": 1.25 if reviving else 1.0, "duration": 500,
			"pivot": Vector2(0.5, 0.8), "layer": entry[1], "loop": false})

func reset_homes() -> void:
	for front in [true, false]:
		var row: Array = []
		for id in w.heroes:
			if w.units[id].front == front:
				row.append(w.units[id])
		for index in range(row.size()):
			var u = row[index]
			var point: Array = w.combat.formation["front" if front else "back"][row.size() - 1][index]
			u.home = Vector2(point[0], point[1])
			u.back_lock = false
			u.guard_return = u.front and not u.entering

func lifecycle() -> void:
	var remove: Array = []
	for u: Dictionary in w.units.values():
		if u.dead:
			if not u.death_finished and w.time_ms >= u.death_finish_at:
				u.death_finished = true
				w.skills.trigger(u, "death_after", u)
			if u.kind == "hero" and w.time_ms >= u.revive_at:
				revive_hero(u)
			elif u.kind != "hero" and w.time_ms >= u.remove_at and not death_activity(u):
				remove.append(u.id)
		elif u.expires > 0 and w.time_ms >= u.expires:
			w.damage.defeat(u, {})
	for id in remove:
		w.units.erase(id)
		w.core.remove_entity(str(id))

func revive_hero(u: Dictionary) -> void:
	u.dead = false
	u.death_finished = false
	u.core.lifecycle = "active"
	u.core.attributes.set_value("hp", stat(u, 1))
	u.pos = hero_spawn()
	u.entering = true
	u.guard_return = false
	u.back_lock = false
	u.target = 0
	u.ai_at = w.time_ms
	u.action = "idle"
	u.action_at = w.time_ms
	u.action_until = w.time_ms
	u.attack_events.clear()
	u.attack_at = w.time_ms
	summon_effect(u.pos, true)
	w.skills.trigger(u, "revive", u)
	for id in w.heroes:
		if id != u.id:
			w.skills.trigger(w.units[id], "ally_revive", u)
	w.gems.on_hero_revive(u)
	w.events.append({"type": "revived", "unit": u.id})

func death_activity(u: Dictionary) -> bool:
	for p in w.missiles:
		if p.owner == u.id and p.skill.get("death_cast", false):
			return true
	for entry in w.skills.queue:
		if entry.owner == u.id and entry.get("death_cast", false):
			return true
	return false

static func stat(unit: Dictionary, key: int) -> float:
	return unit.core.attributes.value(str(key)) if not unit.is_empty() else 0.0

static func hp(unit: Dictionary) -> float:
	return unit.core.attributes.value("hp") if not unit.is_empty() else 0.0
