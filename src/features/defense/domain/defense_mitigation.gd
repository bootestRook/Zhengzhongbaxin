class_name DefenseMitigation
extends RefCounted

const U = preload("res://src/features/defense/domain/defense_units.gd")
const Traits = preload("res://src/features/defense/domain/defense_traits.gd")
var w

func _init(world) -> void:
	w = world

func apply(source: Dictionary, target: Dictionary, value: float, magical: bool, context: Dictionary) -> float:
	var periodic = context.get("kind", "attack") == "periodic"
	var true_damage = bool(context.get("true_damage", false))
	var tags: PackedStringArray = context.get("tags", PackedStringArray())
	var no_shield = periodic or "4" in tags
	var no_defense = true_damage or periodic or context.get("ignore_defense", false) or (target.kind == "hero" and "3" in tags)
	if magical and not periodic and not true_damage:
		value *= maxf(0, 1 - U.stat(target, 29) / 100.0)
	if target.kind != "hero" and not no_shield:
		value = absorb(target, value)
		if value <= 0:
			return 0
	if not no_defense:
		var defense = U.stat(target, 10)
		if target.kind != "hero" or not magical:
			var penetration = Traits.penetration(source)
			defense = (defense - penetration.x * (1 if target.kind == "hero" else 2)) * penetration.y
		if target.kind == "hero":
			defense = maxf(0, defense)
		value = maxf(1, value - defense)
	value *= maxf(0, 1 - U.stat(target, 11) / 100.0)
	if not periodic and not true_damage:
		value *= w.passives.damage_multiplier(source, target, magical)
		value = w.passives.redirect(source, target, value)
		value *= w.gems.damage_taken_multiplier(target, source, context)
	if target.kind == "hero" and not no_shield:
		value = absorb(target, value)
		if context.get("kind", "attack") == "skill":
			value = maxf(1, value)
	return maxf(0, value)

func absorb(target: Dictionary, value: float) -> float:
	if target.shield_hits > 0:
		target.shield_hits -= 1
		w.statuses.consume_shield(target, 1, true)
		w.cue("number", target.pos, {"text": "抵挡", "color": "blue"})
		return 0
	var before: float = target.shield
	var absorbed = minf(target.shield, value)
	target.shield -= absorbed
	w.statuses.consume_shield(target, absorbed)
	if before > 0 and target.shield <= 0:
		w.passives.shield_broken(target, before)
	return maxf(0, value - absorbed)
