class_name DefenseFirePatterns
extends RefCounted

const C = preload("res://src/features/defense/domain/defense_catalog.gd")
var w

func _init(world) -> void:
	w = world

func wave(owner: Dictionary, skill: Dictionary, target: Dictionary, origin: Vector2, copies: int, cd_fire: bool, selected: Array = [], fire_index: int = 0) -> void:
	if selected.is_empty():
		selected = w.targets.select(owner, skill, target, fire_index, origin)
		if selected.is_empty() and skill.get("aim", []).is_empty():
			selected = [{"id": 0, "pos": w.targets.attack_point(owner) if origin == Vector2.INF else origin, "dead": false} if target.is_empty() else target]
	var first = true
	for recipient in selected:
		for i in range(copies):
			var data = skill.duplicate(true)
			data["salvo_index"] = i
			data["cd_fire"] = first and cd_fire
			first = false
			w.skills.graph.launch(w, owner, recipient, data, origin, 0)

func repeat_end(p: Dictionary, owner: Dictionary, target: Dictionary) -> void:
	var state: Dictionary = p.repeat_state
	if state.is_empty():
		state = {"left": int(C.number(p.skill.get("repeat_fire", 0))),
			"rule": int(p.skill.get("repeat_target", C.number(p.skill.get("repeat_fire", 0), 1)))}
	if state.left <= 0 or not w.targets.definitions.has(str(state.rule)):
		return
	state.left -= 1
	var source: Dictionary = owner.duplicate()
	source.pos = p.pos
	w.targets.score_cache.erase(owner.id)
	var selected = w.targets.select_rule(source, p.skill, w.targets.definitions[str(state.rule)], target, [target.id] if not target.is_empty() else [])
	for recipient in selected:
		for i in range(1 + int(C.number(p.skill.get("salvo", 0)))):
			var data: Dictionary = p.skill.duplicate(true)
			data["salvo_index"] = i
			data["cd_fire"] = false
			data["repeat_state"] = state
			w.skills.graph.launch(w, owner, recipient, data, p.pos, 0)
