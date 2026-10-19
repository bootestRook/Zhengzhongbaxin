class_name DefenseGuard
extends RefCounted

const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")
const CHASE_TOP = 480.0
var w

func _init(world) -> void:
	w = world

func applies(source: Dictionary) -> bool:
	return source.kind == "hero" and source.front

func line() -> float:
	return CHASE_TOP

func behind(source: Dictionary, target: Dictionary) -> bool:
	return target.pos.y > source.home.y + 50.0

func limit_position(source: Dictionary, destination: Vector2) -> Vector2:
	if not applies(source):
		return destination
	return Vector2(clampf(destination.x, w.combat.world.left, w.combat.world.right), clampf(destination.y, line(), w.combat.world.bottom))

func choose_enemy(source: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var direct: Dictionary = {}
	var rear: Dictionary = {}
	var best_score = INF
	var direct_score = INF
	var rear_distance = INF
	for target: Dictionary in w.units.values():
		if target.dead or target.side == source.side or w.targets.hidden_enemy(source, target):
			continue
		if behind(source, target):
			var distance: float = source.pos.distance_squared_to(target.pos)
			if distance < rear_distance:
				rear_distance = distance
				rear = target
		var value = w.targets.score(source, target)
		if value < best_score:
			best_score = value
			best = target
		if Geometry.reaches(source, target) and value < direct_score:
			direct_score = value
			direct = target
	return rear if not rear.is_empty() else (direct if not direct.is_empty() else best)

