class_name DefenseProjectileGeometry
extends RefCounted

const Body = preload("res://src/features/defense/domain/defense_attack_geometry.gd")

static func aim_point(u: Dictionary) -> Vector2:
	if not u.has("motion"):
		return u.pos
	var offset: Array = u.motion.body_offset
	return u.pos + Vector2(offset[0] * u.facing, offset[1])

static func scale_for(p: Dictionary) -> Vector2:
	if p.kind in [0, 1, 6, 7]:
		return Vector2.ONE
	var size: Dictionary = p.shape.get("baseSize", {})
	var scale_value = p.radius / float(size.get("x", 1)) if p.radius > 0 and float(size.get("x", 0)) > 0 else 1.0
	if p.kind in [4, 5]:
		return Vector2(scale_value, 4)
	if p.kind == 33:
		return Vector2(scale_value, p.radius / maxf(1, float(size.get("y", 1))))
	if p.kind == 31 and p.radius == 0:
		return Vector2.ZERO
	if p.kind == 17:
		return Vector2(scale_value, float(p.skill.get("attack_range", 0)) / maxf(1, float(size.get("y", 1))))
	return Vector2.ONE * scale_value

static func shape(p: Dictionary) -> PackedVector2Array:
	var dimensions: Dictionary = p.shape.get("collisionSize", {})
	if float(dimensions.get("x", 0)) <= 0 or float(dimensions.get("y", 0)) <= 0:
		return PackedVector2Array()
	var size: Dictionary = p.shape.baseSize
	var pivot: Dictionary = p.shape.basePivot
	var position: Dictionary = p.shape.collisionPos
	var scaling = scale_for(p)
	var center = Vector2(position.x - size.x * pivot.x, position.y - size.y * pivot.y) * scaling
	var half = Vector2(dimensions.x, dimensions.y) * scaling / 2
	var result = PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		result.append(p.pos + (center + corner).rotated(p.rotation))
	return result

static func overlaps(p: Dictionary, u: Dictionary, polygon: PackedVector2Array) -> bool:
	if p.kind in [31, 33]:
		var scaling = scale_for(p)
		var dimensions: Dictionary = p.shape.get("collisionSize", {})
		var radius = float(dimensions.get("x", 0)) * scaling.x / 2
		if radius <= 0:
			return false
		var size: Dictionary = p.shape.baseSize
		var pivot: Dictionary = p.shape.basePivot
		var offset_p: Dictionary = p.shape.collisionPos
		var origin: Vector2 = p.pos + (Vector2(offset_p.x - size.x * pivot.x, offset_p.y - size.y * pivot.y) * scaling).rotated(p.rotation)
		var offset: Array = u.motion.body_offset
		var center: Vector2 = u.pos + Vector2(offset[0] * u.facing, offset[1])
		var half = Vector2(u.motion.body_size[0], u.motion.body_size[1]) / 2
		var closest = Vector2(clampf(origin.x, center.x - half.x, center.x + half.x), clampf(origin.y, center.y - half.y, center.y + half.y))
		return closest.distance_squared_to(origin) <= radius * radius
	if polygon.is_empty():
		return false
	return not Geometry2D.intersect_polygons(polygon, Body.shape(u, "body", 0)).is_empty()

static func recipients(w, p: Dictionary, owner: Dictionary) -> Array:
	if p.skill.get("area_shape", "") == "circle":
		return w.targets.area(owner, p.pos, p.radius, p.allies)
	var result: Array = []
	var polygon = shape(p)
	var center = Vector2.ZERO
	var reach = 0.0
	for point in polygon:
		center += point / 4
	for point in polygon:
		reach = maxf(reach, point.distance_to(center))
	for u: Dictionary in w.units.values():
		if u.dead or (u.side == owner.side) != p.allies:
			continue
		if u.pos.distance_squared_to(center) > pow(reach + 250, 2):
			continue
		if overlaps(p, u, polygon):
			result.append(u)
	return result

static func swept(w, p: Dictionary, owner: Dictionary, before: Vector2) -> Array:
	var dimensions: Dictionary = p.shape.get("collisionSize", {})
	if float(dimensions.get("x", 0)) <= 0 or float(dimensions.get("y", 0)) <= 0:
		return []
	var scaling = scale_for(p)
	var size: Dictionary = p.shape.baseSize
	var pivot: Dictionary = p.shape.basePivot
	var offset: Dictionary = p.shape.collisionPos
	var center = before + (Vector2(offset.x - size.x * pivot.x, offset.y - size.y * pivot.y) * scaling).rotated(p.rotation)
	var half = Vector2(dimensions.x, dimensions.y) * scaling / 2
	var axes = [Vector2.RIGHT, Vector2.DOWN, Vector2.RIGHT.rotated(p.rotation), Vector2.DOWN.rotated(p.rotation)]
	var movement: Vector2 = p.pos - before
	var radii: Array = []
	for axis: Vector2 in axes:
		radii.append(half.x * absf(axis.dot(axes[2])) + half.y * absf(axis.dot(axes[3])))
	var found: Array = []
	for u: Dictionary in w.units.values():
		if u.dead or (u.side == owner.side) != p.allies or p.hits.has(u.id) or p.ignored.has(u.id) or w.targets.hidden_enemy(owner, u):
			continue
		var body_center = aim_point(u)
		var body_half = Vector2(u.motion.body_size[0], u.motion.body_size[1]) / 2
		# Cheap swept bounds reject distant bodies before the four-axis test.
		var reach = body_half + Vector2(radii[0], radii[1])
		if body_center.x < minf(center.x, center.x + movement.x) - reach.x or body_center.x > maxf(center.x, center.x + movement.x) + reach.x:
			continue
		if body_center.y < minf(center.y, center.y + movement.y) - reach.y or body_center.y > maxf(center.y, center.y + movement.y) + reach.y:
			continue
		var fraction = contact_fraction(body_center - center, body_half, movement, axes, radii)
		if fraction >= 0:
			found.append({"unit": u, "fraction": fraction})
	found.sort_custom(func(a, b): return a.unit.id < b.unit.id if a.fraction == b.fraction else a.fraction < b.fraction)
	return found

static func contact_fraction(delta: Vector2, half: Vector2, movement: Vector2, axes: Array, radii: Array) -> float:
	var entry = 0.0
	var exit_at = 1.0
	for i in range(axes.size()):
		var axis: Vector2 = axes[i]
		var distance = delta.dot(axis)
		var extent = float(radii[i]) + half.x * absf(axis.x) + half.y * absf(axis.y)
		var speed = movement.dot(axis)
		if absf(speed) < 0.000001:
			if absf(distance) > extent:
				return -1.0
			continue
		var first = (distance - extent) / speed
		var last = (distance + extent) / speed
		entry = maxf(entry, minf(first, last))
		exit_at = minf(exit_at, maxf(first, last))
		if entry > exit_at:
			return -1.0
	return entry
