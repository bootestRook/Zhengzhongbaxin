class_name DefenseAttackGeometry
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")

static func detection_radius(source: Dictionary) -> float:
	var radius = U.stat(source, 26)
	if radius > 0:
		return radius
	var dimensions: Array = source.motion.get("attack_box_size", [0, 0])
	var offset: Array = source.motion.get("attack_box_offset", [0, 0])
	return Vector2(dimensions[0], dimensions[1]).length() / 2 + Vector2(offset[0], offset[1]).length()

static func intersects(source: Dictionary, target: Dictionary, inset: float = 0.0) -> bool:
	var extra = U.stat(source, 26)
	if extra > 0:
		extra = maxf(0, extra - inset)
		var offset: Array = target.motion.get("body_offset", [0, 0])
		var center: Vector2 = target.pos + Vector2(offset[0] * target.facing, offset[1])
		var dimensions: Array = target.motion.get("body_size", [0, 0])
		var half = Vector2(dimensions[0], dimensions[1]) / 2
		var closest = Vector2(clampf(source.pos.x, center.x - half.x, center.x + half.x), clampf(source.pos.y, center.y - half.y, center.y + half.y))
		return closest.distance_squared_to(source.pos) <= extra * extra
	var box_size: Array = source.motion.get("attack_box_size", [0, 0])
	var offset: Array = source.motion.get("attack_box_offset", [0, 0])
	var limit = Vector2(box_size[0], box_size[1]).length() / 2 + Vector2(offset[0], offset[1]).length() + 100
	if source.pos.distance_squared_to(target.pos) > limit * limit:
		return false
	var attack = shape(source, "attack_box", -float(source.motion.get("attack_angle", 0)) * source.facing * PI / 180, inset)
	var body = shape(target, "body", 0)
	return not Geometry2D.intersect_polygons(attack, body).is_empty()

static func shape(u: Dictionary, prefix: String, angle: float, inset: float = 0.0) -> PackedVector2Array:
	var offset: Array = u.motion.get(prefix + "_offset", [0, 0])
	var dimensions: Array = u.motion.get(prefix + "_size", [0, 0])
	var center: Vector2 = u.pos + Vector2(offset[0] * u.facing, offset[1])
	var half = Vector2(maxf(0, dimensions[0] / 2.0 - inset), maxf(0, dimensions[1] / 2.0 - inset))
	var result = PackedVector2Array()
	for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
		result.append(center + corner.rotated(angle))
	return result

static func approach(source: Dictionary, target: Dictionary) -> Vector2:
	if U.stat(source, 26) > 0:
		return target.pos
	var offset: Array = source.motion.get("attack_box_offset", [0, 0])
	var body: Array = target.motion.get("body_offset", [0, 0])
	# The target's emission point may be far outside its hittable body.
	return target.pos + Vector2(body[0] * target.facing - offset[0] * source.facing, body[1] - offset[1])

static func reaches(source: Dictionary, target: Dictionary) -> bool:
	if target.is_empty():
		return false
	if not source.front:
		return intersects(source, target)
	var facing = source.duplicate()
	facing.facing = -1.0 if target.pos.x > source.pos.x else 1.0
	return intersects(facing, target)

