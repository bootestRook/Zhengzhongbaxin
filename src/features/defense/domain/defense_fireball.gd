class_name DefenseFireball
extends RefCounted

var w
var charges: Array = []

func _init(world) -> void:
	w = world

func cast(owner: Dictionary, skill: Dictionary) -> bool:
	if charges.any(func(c): return c.owner == owner.id):
		return false
	var config: Dictionary = skill.fireball.duplicate(true)
	if targets(owner, config).is_empty():
		return false
	var data: Dictionary = skill.duplicate(true)
	data.damage_num = int(config.charge_ms) / 200
	w.skills.actions.track(owner, data)
	var visuals: Array = []
	for i in range(int(config.copies)):
		var charge: Dictionary = data.duplicate(true)
		charge["fire_phase"] = "charge"
		charge["fire_visual"] = bool(config.upgraded)
		if config.upgraded:
			charge.movie_effect = ["fireball_pl2", "1.3", "-1"]
			charge["visual_tint"] = "#ffd56e"
		var point = w.targets.attack_point(owner)
		var offset = i - (int(config.copies) - 1) / 2.0
		point += Vector2(offset * 44, -absf(offset) * 12)
		w.projectiles.launch(owner, {"id": 0, "pos": point, "dead": false}, charge, point, 0)
		visuals.append(w.missiles[-1].id)
	var duration = int(config.charge_ms)
	if config.shield_percent > 0:
		w.statuses.add(owner, owner, int(config.shield_status), duration)
	charges.append({"owner": owner.id, "until": w.time_ms + duration, "config": config, "visuals": visuals})
	return true

func targets(owner: Dictionary, config: Dictionary) -> Array:
	var projectile: Dictionary = owner.skills[int(config.projectile)].data
	var source: Dictionary = owner.duplicate()
	source.pos = w.targets.attack_point(owner)
	return w.targets.select_rule(source, projectile, w.targets.definitions[str(int(projectile.aim[0]))], {})

func tick() -> void:
	for charge: Dictionary in charges.duplicate():
		var owner: Dictionary = w.units.get(charge.owner, {})
		var interrupted = owner.is_empty() or owner.dead or w.statuses.prevents(owner, "attack")
		if not interrupted and w.time_ms < charge.until:
			continue
		for p in w.missiles:
			if charge.visuals.has(p.id):
				p.ended = true
		if not owner.is_empty():
			for state in owner.statuses.duplicate():
				if state.id == int(charge.config.shield_status):
					w.statuses.remove(owner, state)
		if not interrupted:
			release(owner, charge.config)
		charges.erase(charge)

func release(owner: Dictionary, config: Dictionary) -> void:
	var selected = targets(owner, config)
	if selected.is_empty():
		return
	var projectile: Dictionary = owner.skills[int(config.projectile)].data
	if not projectile.get("sound", []).is_empty():
		w.events.append({"type": "sound", "name": str(projectile.sound[0])})
	for i in range(int(config.copies)):
		var data: Dictionary = projectile.duplicate(true)
		data["fireball_payload"] = config.duplicate(true)
		data["fire_phase"] = "flight"
		data["fire_visual"] = bool(config.upgraded)
		data.damage_num = 1 + int(config.pierce)
		data["salvo_index"] = i
		data.parameters = [0, config.spread_degrees]
		if config.upgraded:
			data.res = "bullet"
			data.movie_effect = ["fireball2", "1.15", "-1"]
			data["visual_tint"] = "#fff0a8"
		w.skills.graph.launch(w, owner, selected[0], data, Vector2.INF, 0)

func impact(owner: Dictionary, target: Dictionary, config: Dictionary) -> void:
	var point: Vector2 = target.pos
	var blast: Dictionary = owner.skills[int(config.blast)].data.duplicate(true)
	blast["radius_bonus"] = config.radius_bonus
	blast["bonus_damage"] = config.blast_bonus
	blast["fire_phase"] = "blast"
	blast["fire_visual"] = bool(config.upgraded)
	if config.speed_conversion > 0:
		blast.damage.append("4:%s:4" % (float(config.speed_conversion) * 10000))
	blast["periodic_speed_ratio"] = config.speed_conversion
	if config.burn_seconds > 0:
		blast.statusChange.append([str(int(config.burn_status)), str(config.burn_seconds)])
	if config.get("stun_seconds", 0) > 0:
		blast.statusChange.append([str(int(config.stun_status)), str(config.stun_seconds)])
	if config.upgraded:
		blast.res = "bullet2"
		blast.movie_effect = ["fireballboom2", "1.3", "0.5"]
		blast["visual_tint"] = "#ffe5a0"
	if not blast.get("sound", []).is_empty():
		w.events.append({"type": "sound", "name": str(blast.sound[0])})
	w.projectiles.launch(owner, target, blast, point, 0)
	var true_burn = w.gems.fireball_true_burn(owner, target)
	if true_burn > 0:
		w.damage.true_damage(owner, target, true_burn, {"kind": "fireball_true_burn", "tags": ["0", "102"]})
	if config.secondary:
		var secondary: Dictionary = blast.duplicate(true)
		secondary["damage_scale"] = 0.5
		secondary.radius_bonus = float(config.radius_bonus) + 30.0
		secondary["fire_secondary"] = true
		w.projectiles.launch(owner, target, secondary, point, 160)
	if config.ember_seconds > 0:
		var ember: Dictionary = owner.skills[int(config.ember)].data.duplicate(true)
		ember["radius_bonus"] = config.radius_bonus
		ember["fireball_ember"] = true
		ember.damage_num = int(config.ember_seconds)
		if config.speed_conversion > 0:
			ember.damage.append("4:%s:4" % (float(config.speed_conversion) * 10000))
		w.projectiles.launch(owner, target, ember, point, 0)

func ember_ready(owner: Dictionary, target: Dictionary, due: int) -> bool:
	var times: Dictionary = target.get("ember_ticks", {})
	if due < int(times.get(owner.id, 0)):
		return false
	times[owner.id] = due + 1000
	target["ember_ticks"] = times
	return true
