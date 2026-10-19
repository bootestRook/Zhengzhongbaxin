class_name DefenseSpace
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
var w
var cells: Dictionary = {}
var attackers: Dictionary = {}
var by_side: Dictionary = {1: [], 2: []}
var occupied: Dictionary = {}
var max_radius: float = 0

func _init(world) -> void:
	w = world

func rebuild() -> void:
	cells.clear()
	attackers.clear()
	by_side = {1: [], 2: []}
	occupied.clear()
	max_radius = 0
	w.targets.score_cache.clear()
	for u: Dictionary in w.units.values():
		if u.dead:
			continue
		var key = cell(u.pos)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(u)
		max_radius = maxf(max_radius, u.radius)
		by_side[u.side].append(u)
		if u.blocked_by > 0:
			if not occupied.has(u.blocked_by):
				occupied[u.blocked_by] = []
			occupied[u.blocked_by].append(u)
		if u.target > 0:
			attackers[u.target] = int(attackers.get(u.target, 0)) + 1

func register(u: Dictionary) -> void:
	by_side[u.side].append(u)
	var key = cell(u.pos)
	if not cells.has(key):
		cells[key] = []
	cells[key].append(u)
	max_radius = maxf(max_radius, u.radius)
	w.targets.score_cache.clear()

func bind(enemy: Dictionary, blocker: Dictionary) -> void:
	var next_id: int = blocker.get("id", 0)
	if enemy.blocked_by > 0:
		occupied.get(enemy.blocked_by, []).erase(enemy)
		# Losing a blocking slot also ends its ordinary pursuit. Committed
		# attacks and independent boss/skill targets retain their own lifetime.
		var taunted = w.time_ms < enemy.taunt_until and enemy.taunt == enemy.blocked_by
		if next_id != enemy.blocked_by and enemy.kind != "boss" and not taunted and enemy.target == enemy.blocked_by:
			enemy.target = 0
	enemy.blocked_by = next_id
	if enemy.blocked_by > 0:
		if not occupied.has(enemy.blocked_by):
			occupied[enemy.blocked_by] = []
		occupied[enemy.blocked_by].append(enemy)

static func cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / 100), floori(pos.y / 100))

func nearby(pos: Vector2, radius: float) -> Array:
	var result: Array = []
	var low = cell(pos - Vector2.ONE * radius)
	var high = cell(pos + Vector2.ONE * radius)
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			for u in cells.get(Vector2i(x, y), []):
				if not u.dead:
					result.append(u)
	return result

func move(u: Dictionary, destination: Vector2, distance: float) -> void:
	var step = minf(distance, u.pos.distance_to(destination))
	var direction: Vector2 = (destination - u.pos).normalized()
	var neighbors = nearby(u.pos, u.radius + max_radius + step)
	var next: Vector2 = u.pos + direction * step
	var steered = false
	for other: Dictionary in neighbors:
		if other.id == u.id:
			continue
		var other_pos: Vector2 = other.pos
		var delta: Vector2 = next - other_pos
		var spacing: float = u.radius + other.radius
		var length_squared = delta.length_squared()
		if length_squared >= spacing * spacing:
			continue
		if other.get("hidden_until", 0) > w.time_ms or other.action in ["skill", "skill2"]:
			continue
		if not steered and (other_pos - u.pos).dot(direction) > 0:
			var tangent = direction.orthogonal()
			var side: float = (other_pos - u.pos).dot(tangent)
			# Opposing movers pass on their own right in a head-on contact.
			var turn = -signf(side) if absf(side) > 0.001 else 1.0
			next = u.pos + (direction + tangent * turn).normalized() * step
			if next.x < w.combat.world.left or next.x > w.combat.world.right or next.y < 0 or next.y > w.combat.world.bottom:
				next = u.pos + (direction - tangent * turn).normalized() * step
			steered = true
			delta = next - other_pos
			length_squared = delta.length_squared()
			if length_squared >= spacing * spacing:
				continue
		var length = sqrt(length_squared)
		var normal = delta / length if length > 0.001 else Vector2(1 if u.id > other.id else -1, 0)
		next += normal * minf(spacing - length, step)
	# Separation cannot accelerate a unit or move a stationary neighbor.
	next = u.pos + (next - u.pos).limit_length(step)
	var previous = cell(u.pos)
	u.pos = Vector2(clampf(next.x, w.combat.world.left, w.combat.world.right), clampf(next.y, 0, w.combat.world.bottom))
	var current = cell(u.pos)
	if previous != current:
		cells.get(previous, []).erase(u)
		if not cells.has(current):
			cells[current] = []
		cells[current].append(u)

func release(u: Dictionary) -> void:
	u.blocked_by = 0
	for other: Dictionary in w.units.values():
		if other.blocked_by == u.id:
			other.blocked_by = 0
		if other.target == u.id:
			other.target = 0

func blocker(enemy: Dictionary) -> Dictionary:
	var bound: Dictionary = w.units.get(enemy.blocked_by, {})
	if not bound.is_empty() and not bound.dead and not w.targets.hidden_enemy(enemy, bound) and U.stat(bound, 3) > 0:
		return bound
	enemy.blocked_by = 0
	var candidates: Array = []
	for u: Dictionary in by_side[1 if enemy.side == 2 else 2]:
		if u.side != enemy.side and not u.dead and U.stat(u, 3) > 0 and not w.targets.hidden_enemy(enemy, u):
			if u.pos.distance_to(enemy.pos) <= w.combat.world.block_search:
				candidates.append(u)
	candidates.sort_custom(func(a, b): return a.pos.distance_squared_to(enemy.pos) < b.pos.distance_squared_to(enemy.pos))
	for u: Dictionary in candidates:
		var occupants: Array = occupied.get(u.id, []).filter(func(other): return not other.dead and other.blocked_by == u.id)
		if occupants.size() < int(U.stat(u, 3)):
			bind(enemy, u)
			return u
		for other: Dictionary in occupants:
			if enemy.pos.distance_squared_to(u.pos) < other.pos.distance_squared_to(u.pos) + 400:
				bind(other, {})
				bind(enemy, u)
				return u
	return {}
