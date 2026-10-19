class_name DefenseSkillEffects
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
const Displacement = preload("res://src/features/defense/domain/defense_displacement.gd")
var w

func _init(world) -> void:
	w = world

func apply(owner: Dictionary, target: Dictionary, skill: Dictionary, phase: String = "begin", damage: float = 0) -> void:
	for entry in skill.get("actionOth", []):
		if entry.is_empty():
			continue
		var name = str(entry[0])
		var expected = "post" if name == "bloodsucking" else ("begin" if name in ["delivery", "transposition", "charge", "summon", "summon2", "revive", "throw"] else "pre")
		if phase != expected:
			continue
		var amount = float(entry[1]) if entry.size() > 1 else 0.0
		match str(entry[0]):
			"summon", "summon2":
				var count = maxi(1, int(entry[2])) if entry.size() > 2 else 1
				var limit = int(entry[4]) if entry.size() > 4 else 0
				var sid = int(skill.__id__)
				var instance: Dictionary = owner.skills.get(sid, {})
				var ids: Array = instance.get("summons", [])
				if limit > 0 and owner.side == 1:
					var existing: Array = []
					for id in ids:
						var u: Dictionary = w.units.get(id, {})
						if not u.is_empty() and u.template == w.upgrades.soldier_template(owner, int(amount)) and not u.dead:
							existing.append(u)
					existing.sort_custom(func(a, b): return U.hp(a) < U.hp(b))
					while existing.size() >= limit and not existing.is_empty():
						w.damage.defeat(existing.pop_front(), {})
				for i in range(count):
					var angle = w.rng.stream("defense.combat").next_int(360 if owner.side == 2 else 91) + (0 if owner.side == 2 else -135)
					var center: Vector2 = owner.pos if owner.side == 2 else owner.home
					var position: Vector2 = center + Vector2(cos(angle * PI / 180.0), sin(angle * PI / 180.0)) * 100
					if skill.get("spawn_position", false):
						position = skill.get("spawn_point", target.pos)
					var u = w.factory.create("enemy" if owner.side == 2 else "summon", int(amount), position, owner.side, owner.id)
					if u.is_empty():
						w.note("missing_summon.%d" % amount)
					else:
						ids.append(u.id)
						if entry.size() > 3 and float(entry[3]) > 0:
							u.expires = w.time_ms + roundi(float(entry[3]) * 1000)
				instance["summons"] = ids.filter(func(id): return w.units.has(id) and not w.units[id].dead)
			"bloodsucking":
				w.damage.heal(owner, owner, damage * amount / 100.0)
			"charge":
				var duration = roundi(amount / maxf(1, float(skill.get("speed", 1))) * 1000)
				owner.action = "skill2"
				owner.action_at = w.time_ms
				owner.action_until = w.time_ms + duration
			"delivery":
				var angle = w.rng.stream("defense.combat").next_int(360) * PI / 180.0
				owner.pos = target.pos + Vector2(cos(angle), sin(angle)) * amount
				owner.back_lock = false
			"hook":
				if target.has("core") and not w.damage.protection.blocks_displacement(target):
					target["forced_motion"] = {"owner": owner.id, "speed": amount}
			"throw":
				if target.has("core"):
					Displacement.throw_unit(w, owner, target, skill, int(amount))
			"purification":
				for status in target.statuses.duplicate():
					if w.statuses.definitions[str(status.id)].get("bufftype", []).has(int(amount)):
						w.statuses.remove(target, status)
			"revive":
				if target.get("kind", "") == "hero" and target.dead:
					target.revive_at -= roundi((target.revive_at - w.time_ms) * amount / 100.0)
			"resurrection":
				if target.has("core") and target.dead:
					target.dead = false
					target.remove_at = 0
					target.core.lifecycle = "active"
					target.core.attributes.set_value("hp", U.stat(target, 1) * amount / 100.0)
			"cdChange":
				for state in target.skills.values():
					state.next -= amount * 1000
			"ridicule":
				w.damage.protection.taunt(owner, target, roundi(amount * 1000))
			"kill", "eliminate":
				if target.has("core"):
					w.damage.defeat(target, owner)
			"hide", "hide2":
				var hidden = owner if name == "hide2" else target
				if hidden.has("core"):
					hidden["hidden_until"] = w.time_ms + roundi(amount)
					w.space.release(hidden)
			"transposition":
				var pos: Vector2 = owner.pos
				owner.pos = target.pos
				target.pos = pos
			_:
				w.note("action.%s" % entry[0])
