class_name DefenseTraits
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
var w

func _init(world) -> void:
	w = world

func missed(source: Dictionary, target: Dictionary, magical: bool, context: Dictionary) -> bool:
	var normal = not magical or context.get("tags", PackedStringArray()).has("6")
	var ranged = not source.get("front", true)
	var hit_rate = U.stat(source, 15)
	for entry in source.get("traits", []):
		if str(entry[0]) == "precise":
			hit_rate += float(entry[1])
	var missed = false
	for entry in target.get("traits", []):
		var kind = str(entry[0])
		var eligible = (kind == "dodge" and not magical) or (kind == "dodge2" and magical)
		eligible = eligible or (kind == "dodge3" and not magical and not ranged) or (kind == "dodge4" and normal and (magical or ranged))
		if not eligible:
			continue
		var chance = float(entry[1]) - hit_rate
		if chance >= 100 or (chance > 0 and w.rng.stream("defense.combat").next_int(100) < chance):
			missed = true
	return missed

static func penetration(source: Dictionary) -> Vector2:
	var result = Vector2(U.stat(source, 24), 1)
	for entry in source.get("traits", []):
		if str(entry[0]) == "penetrate":
			result.x += float(entry[1])
			if entry.size() > 2:
				result.y -= float(entry[2]) / 100.0
	return result
