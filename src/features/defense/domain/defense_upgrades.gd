class_name DefenseUpgrades
extends RefCounted

const C = preload("res://src/features/defense/domain/defense_catalog.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
var w

func _init(world) -> void:
	w = world

func apply(unit: Dictionary, id: int, count: bool = true) -> void:
	var option = w.catalog.record("options", id)
	if option.is_empty():
		w.note("missing_option.%d" % id)
		return
	if count:
		w.selected[str(id)] = int(w.selected.get(str(id), 0)) + 1
	w.damage.protection.configure(unit, option.get("guard", {}))
	var active = int(option.get("active", 0))
	if active > 0:
		unit.active_level += 1
	for value in option.get("unlock", []):
		if int(value) < 0:
			unit.skills.erase(-int(value))
		else:
			w.skills.learn(unit, int(value))
	for entry in option.get("equip_skill", []):
		w.passives.add(unit, str(entry))
	for pair in option.get("up_skill", []):
		var ids = str(pair).split(":")
		if ids.size() >= 2:
			unit.skills.erase(int(ids[0]))
			w.skills.learn(unit, int(ids[1]))
	for value in option.get("attribute_correct", []):
		attribute(unit, str(value), id)
	for sid in unit.skills:
		if matches(unit.skills[sid].data, option):
			modify(unit.skills[sid].data, option)
	unit.upgrades.append(id)
	refresh_soldiers(unit, option)
	for entry in option.get("summon", []):
		var parts = str(entry).split(":")
		if parts.size() >= 2 and parts[1].is_valid_int():
			for i in range(int(parts[1])):
				w.factory.create("summon", int(parts[0]), unit.pos + Vector2(70 * (i + 1), -100), unit.side, unit.id)

func attribute(unit: Dictionary, text: String, option_id: int) -> void:
	var p = C.numbers(text)
	if p.size() < 3:
		w.note("attribute_expression.%d" % option_id)
		return
	var key = str(int(p[0]))
	var amount: float = p[1]
	if int(p[2]) in [2, 3]:
		amount = unit.core.attributes.base_value(key) * amount / 100.0
	unit.core.attributes.add_modifier(key, "final_add", amount, "option.%d" % option_id)
	if key == "1":
		unit.core.attributes.set_value("hp", U.hp(unit) + maxf(0, amount))

func modify(skill: Dictionary, option: Dictionary) -> void:
	if skill.has("assassination"):
		for key in option.get("assassination_mod", {}):
			var value = option.assassination_mod[key]
			skill.assassination[key] = value if value is bool else float(skill.assassination[key]) + float(value)
	if skill.has("ice_arrows"):
		for key in option.get("ice_mod", {}):
			var value = option.ice_mod[key]
			skill.ice_arrows[key] = value if value is bool else float(skill.ice_arrows[key]) + float(value)
	if skill.has("thorn_armor"):
		for key in option.get("thorn_mod", {}):
			var value = option.thorn_mod[key]
			skill.thorn_armor[key] = value if value is bool else float(skill.thorn_armor[key]) + float(value)
	if skill.has("fireball"):
		for key in option.get("fireball_mod", {}):
			var value = option.fireball_mod[key]
			skill.fireball[key] = value if value is bool else float(skill.fireball.get(key, 0)) + float(value)
	if option.has("duration_up"):
		for status in skill.get("statusChange", []):
			status[1] = str(float(status[1]) + float(option.duration_up))
		for action in skill.get("actionOth", []):
			if str(action[0]) == "ridicule":
				action[1] = str(float(action[1]) + float(option.duration_up))
	if option.has("change_damage"):
		skill["bonus_damage"] = float(skill.get("bonus_damage", 0)) + C.number(option.change_damage)
	for pair in [["change_damage_num", "damage_num"], ["salvo", "salvo"], ["running_fire", "running_fire"], ["repeat_fire", "repeat_fire"], ["speed_up", "speed"], ["range_up", "attack_range"], ["aimAdd", "extra_targets"]]:
		if option.has(pair[0]):
			skill[pair[1]] = C.number(skill.get(pair[1], 1 if pair[1] == "running_fire" else 0)) + C.number(option[pair[0]])
	if option.has("damageRange_up"):
		# Keep the cumulative area percentage; circular geometry converts it once at impact.
		skill["radius_bonus"] = float(skill.get("radius_bonus", 0)) + C.number(option.damageRange_up)
	if option.has("repeat_fire"):
		skill["repeat_target"] = int(C.number(option.repeat_fire, 1))
	for status in option.get("change_addStatus", []):
		merge_entry(skill.statusChange, status, 1)
	for entry in option.get("change_actionOth", []):
		if str(entry[0]) == "proAdd":
			for index in range(skill.get("triggerOpp", []).size()):
				var trigger_value: Array = str(skill.triggerOpp[index]).split(":")
				if trigger_value.size() > 1:
					trigger_value[1] = str(float(trigger_value[1]) + float(entry[1]))
					skill.triggerOpp[index] = ":".join(trigger_value)
			continue
		merge_entry(skill.actionOth, entry, 2 if str(entry[0]) == "summon" else entry.size())
	for entry in option.get("skillGroupAdd", []):
		skill.skillGroupType.append(entry.duplicate())
	if option.has("change_triggerCd"):
		skill["cd"] = maxf(100, float(skill.get("cd", 1000)) + C.number(option.change_triggerCd))

func matches(skill: Dictionary, option: Dictionary) -> bool:
	if option.get("aim_skill", []).has(int(skill.__id__)):
		return true
	var tags = str(skill.get("damage_type", "")).split(";")
	for type in option.get("aim_type", []):
		if str(int(type)) in tags:
			return true
	return false

func merge_entry(entries: Array, change: Array, identity: int) -> void:
	for entry in entries:
		if entry.slice(0, identity) == change.slice(0, identity):
			for i in range(identity, change.size()):
				while entry.size() <= i:
					entry.append("0")
				entry[i] = str(float(entry[i]) + float(change[i]))
			return
	entries.append(change.duplicate())

func soldier_template(owner: Dictionary, id: int) -> int:
	for option_id in owner.get("upgrades", []):
		for pair in w.catalog.record("options", option_id).get("soldiers_change", []):
			var parts = C.numbers(pair)
			if int(parts[0]) == id:
				id = int(parts[1])
	return id

func soldier_bonus(owner: Dictionary, classes: Array) -> float:
	var bonus = 0.0
	for option_id in owner.get("upgrades", []):
		for pair in w.catalog.record("options", option_id).get("soldiers_upgrade", []):
			var parts = C.numbers(pair)
			if classes.has(int(parts[0])):
				bonus += parts[1]
	return bonus

func soldier_skills(owner: Dictionary, unit: Dictionary) -> void:
	for option_id in owner.get("upgrades", []):
		for pair in w.catalog.record("options", option_id).get("soldiers_skill", []):
			var parts = C.numbers(pair)
			if int(parts[0]) == unit.template:
				w.skills.learn(unit, int(parts[1]))

func refresh_soldiers(owner: Dictionary, option: Dictionary) -> void:
	if option.get("soldiers_change", []).is_empty() and option.get("soldiers_upgrade", []).is_empty() and option.get("soldiers_skill", []).is_empty():
		return
	for u: Dictionary in w.units.values():
		if u.owner != owner.id or u.dead:
			continue
		var ratio = U.hp(u) / maxf(1, U.stat(u, 1))
		var next = w.factory.create("summon", u.template, u.pos, u.side, owner.id)
		if not next.is_empty():
			next.expires = u.expires
			next.core.attributes.set_value("hp", U.stat(next, 1) * ratio)
			w.units.erase(u.id)
			w.core.remove_entity(str(u.id))
