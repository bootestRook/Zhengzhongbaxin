class_name DefenseAI
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
const C = preload("res://src/features/defense/domain/defense_catalog.gd")
const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")
const Displacement = preload("res://src/features/defense/domain/defense_displacement.gd")
const Statue = preload("res://src/features/defense/domain/defense_statue.gd")
var w

func _init(world) -> void:
	w = world

func tick() -> void:
	for u: Dictionary in w.units.values():
		if u.dead:
			continue
		if forced_move(u):
			continue
		advance_attack(u)
		if w.time_ms < maxi(u.action_until, int(u.get("busy_until", 0))):
			continue
		if w.skills.pending_action(u):
			continue
		if u.action in ["attack", "skill", "skill2"]:
			set_action(u, "idle")
		if w.guard.applies(u) and not u.entering and u.pos.y < w.guard.line():
			return_to_guard(u)
			continue
		if w.time_ms >= u.ai_at:
			u.ai_at = w.time_ms + (200 if u.kind in ["hero", "boss"] else 500)
			if not (u.side == 2 and u.pos.y < w.combat.world.warning_y and u.target == 0):
				if w.skills.ready_action(u):
					continue
			var chosen = choose_enemy(u)
			u.target = chosen.get("id", 0)
		var target: Dictionary = w.units.get(u.target, {})
		if not target.is_empty() and (target.dead or w.targets.hidden_enemy(u, target) or not w.targets.basic_target_allowed(u, target)):
			u.target = 0
			target = {}
		if return_to_guard(u):
			continue
		# Entry uses attack cooldown gaps to reach formation, even with a target.
		# Committed attacks and ready skills have already taken priority above.
		if u.kind == "hero" and u.entering and (w.time_ms < u.attack_at or not Geometry.reaches(u, target)):
			return_home(u)
			continue
		if not target.is_empty():
			u.back_lock = false
			u.facing = -1.0 if target.pos.x > u.pos.x else 1.0
			# During cooldown, finish a melee chase inside the hit box instead of
			# stopping at its edge and restarting after the target's next step.
			var contact_inset = 8.0 if u.front and u.action == "walk" and w.time_ms < u.attack_at else 0.0
			if Geometry.intersects(u, target, contact_inset):
				if not recover_firing_position(u, target):
					attack(u, target)
			else:
				move(u, Geometry.approach(u, target), false)
		elif u.side == 2:
			if u.pos.y < w.combat.world.warning_y:
				# Entry is a downward march, not a path to the common wall target.
				move(u, Vector2(u.pos.x, w.combat.world.bottom), false, false)
			else:
				u.facing = -1.0 if Statue.BODY_CENTER.x > u.pos.x else 1.0
				if Geometry.intersects(u, Statue.TARGET):
					attack(u, {})
				else:
					move(u, Geometry.approach(u, Statue.TARGET), false, false)
		else:
			if w.guard.applies(u) and not u.entering and u.pos.distance_squared_to(u.home) > 2500:
				u.guard_return = true
				u.back_lock = false
			return_home(u)

func return_to_guard(u: Dictionary) -> bool:
	if not w.guard.applies(u) or u.entering:
		return false
	if u.pos.y < w.guard.line():
		u.guard_return = true
		u.back_lock = false
	if not u.guard_return:
		return false
	var target: Dictionary = w.units.get(u.target, {})
	if u.pos.y >= w.guard.line() and not target.is_empty() and not target.dead and not w.targets.hidden_enemy(u, target) \
		and (w.guard.behind(u, target) or Geometry.reaches(u, target)):
		u.guard_return = false
		return false
	return_home(u)
	return true

func recover_firing_position(u: Dictionary, target: Dictionary) -> bool:
	if u.kind != "hero" or u.front or u.entering or w.time_ms >= u.attack_at:
		return false
	if Vector2i(floori(u.pos.x / 50), floori(u.pos.y / 50)) == Vector2i(floori(u.home.x / 50), floori(u.home.y / 50)):
		return false
	var radius = U.stat(u, 26)
	if u.home.distance_squared_to(target.pos) > radius * radius:
		return false
	move(u, u.home)
	return true

func return_home(u: Dictionary) -> void:
	if u.back_lock:
		set_action(u, "idle")
		return
	var destination: Vector2 = u.home
	move(u, destination)
	if Vector2i(floori(u.pos.x / 50), floori(u.pos.y / 50)) == Vector2i(floori(destination.x / 50), floori(destination.y / 50)):
		u.back_lock = true
		u.entering = false
		u.guard_return = false
		set_action(u, "idle")

func choose_enemy(u: Dictionary) -> Dictionary:
	if u.side == 1:
		return w.targets.patrol(u)
	var taunt: Dictionary = w.units.get(u.taunt, {})
	if w.time_ms < u.taunt_until and not taunt.is_empty() and not taunt.dead and not w.targets.hidden_enemy(u, taunt):
		return taunt
	if u.kind == "boss":
		return w.targets.nearest_blocker(u)
	if u.pos.y < w.combat.world.warning_y:
		return {}
	return w.space.blocker(u)

func attack(u: Dictionary, target: Dictionary) -> void:
	if w.time_ms < u.attack_at or w.statuses.prevents(u, "attack"):
		set_action(u, "idle")
		return
	if not target.is_empty() and w.skills.combat_action(u, target):
		return
	u.attacks += 1
	set_action(u, "attack", true)
	u.action_rate = animation_rate(u)
	var frames: Array = u.motion.get("frames", {}).get("attack", [])
	var elapsed = 0
	u.attack_events.clear()
	for index in range(frames.size()):
		if u.motion.get("valid", []).has(index + 1):
			u.attack_events.append({"at": w.time_ms + roundi(elapsed / u.action_rate), "target": target.get("id", 0), "wall": target.is_empty()})
		elapsed += int(frames[index])
	u.action_until = w.time_ms + maxi(16, roundi(elapsed / u.action_rate))
	if w.rng.stream("defense.combat").next_int(100) < w.passives.value(u, 40):
		var duration = u.action_until - w.time_ms
		for event in u.attack_events.duplicate(true):
			event.at += duration
			u.attack_events.append(event)
		u["double_at"] = u.action_until
		u.action_until += duration
	u.attack_at = u.action_until + period(u)
	for event in u.attack_events:
		if event.at <= w.time_ms:
			emit_attack(u, event)
			event.at = -1
	if not u.motion.get("sound", []).is_empty():
		w.events.append({"type": "sound", "name": u.motion.sound[0]})

func advance_attack(u: Dictionary) -> void:
	w.skills.actions.advance(u)
	if u.get("double_at", 0) > 0 and w.time_ms >= u.double_at:
		u.action_at = int(u.double_at)
		u.double_at = 0
	for event in u.attack_events:
		if event.at >= 0 and w.time_ms >= event.at:
			if not w.statuses.prevents(u, "attack"):
				emit_attack(u, event)
			event.at = -1
	if u.action == "attack" and w.time_ms >= u.action_until:
		u.attack_events.clear()

func forced_move(u: Dictionary) -> bool:
	return Displacement.tick(w, u)

func emit_attack(u: Dictionary, event: Dictionary) -> void:
	if event.wall:
		if Geometry.intersects(u, Statue.TARGET):
			w.damage.hit_wall(U.stat(u, 4))
		return
	var target: Dictionary = w.units.get(event.target, {})
	if target.is_empty() or target.dead or w.targets.hidden_enemy(u, target):
		return
	if u.front:
		w.skills.trigger(u, "attack_begin", target)
		w.skills.trigger(u, "attack_emit", target)
	var candidates: Array = []
	for other: Dictionary in w.units.values():
		if other.side != u.side and not other.dead and Geometry.intersects(u, other):
			candidates.append(other)
	candidates.erase(target)
	candidates.sort_custom(func(a, b): return absf(u.pos.x - a.pos.x) < absf(u.pos.x - b.pos.x))
	candidates.push_front(target)
	var amount = U.stat(u, 4) + w.passives.attack_bonus(u)
	for recipient in candidates.slice(0, maxi(1, int(U.stat(u, 5)))):
		if not u.front:
			w.projectiles.basic(u, recipient, amount)
		else:
			w.damage.basic_hit(u, recipient, amount)
			w.skills.trigger(u, "attack", recipient)
			w.skills.trigger(recipient, "physical_hurt", u)
	if not u.front:
		w.skills.trigger(u, "attack_emit", target)

func move(u: Dictionary, destination: Vector2, face_destination: bool = true, path: bool = true) -> void:
	if w.statuses.prevents(u, "move"):
		set_action(u, "idle")
		return
	destination = w.guard.limit_position(u, destination)
	if u.pos.distance_to(destination) < 3:
		set_action(u, "idle")
		return
	if u.side == 2 and u.pos.y < w.combat.world.warning_y:
		u.entry_speed_bonus *= 1 - 16.0 / 7000
	else:
		u.entry_speed_bonus = 0.0
	var speed_value = movement_speed(u)
	if speed_value <= 0:
		set_action(u, "idle")
		return
	var waypoint: Vector2 = w.navigation.toward(u, destination) if path else destination
	waypoint = w.guard.limit_position(u, waypoint)
	var previous_y: float = u.pos.y
	w.space.move(u, waypoint, speed_value * 0.016)
	if w.guard.applies(u) and previous_y >= w.guard.line():
		u.pos = w.guard.limit_position(u, u.pos)
	if face_destination:
		u.facing = -1.0 if destination.x > u.pos.x else 1.0
	set_action(u, "walk")

func movement_speed(u: Dictionary) -> float:
	var entry_base = u.core.attributes.base_value("17")
	for state in u.statuses:
		for entry in w.statuses.definitions[str(state.id)].get("attributeRev", []):
			var parts = C.numbers(entry)
			if parts.size() >= 2 and int(parts[0]) == 17 and (parts.size() < 3 or int(parts[2]) == 1):
				entry_base += parts[1] * state.stacks
	return maxf(0, U.stat(u, 17) + entry_base * u.entry_speed_bonus / 100.0)

func set_action(u: Dictionary, action: String, restart: bool = false) -> void:
	if u.action != action or restart:
		u.action = action
		u.action_at = w.time_ms
		u.action_rate = 1.0

static func animation_rate(u: Dictionary) -> float:
	var speed = maxf(25, U.stat(u, 6))
	return 1 + floorf((speed - 300) / 40 if speed > 300 else speed / 20) / 100.0

static func period(u: Dictionary) -> int:
	if u.kind == "hero":
		return maxi(1, roundi(u.attack_delay_ms * (100 + maxf(25, u.base_attack_speed)) / (100 + maxf(25, U.stat(u, 6)))))
	return maxi(1, floori(500000.0 / (100 + maxf(25, U.stat(u, 6)))))
