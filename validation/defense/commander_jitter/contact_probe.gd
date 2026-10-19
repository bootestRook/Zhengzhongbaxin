extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var w = Session.new(catalog)
	w.level_id = 5
	w.start(1)
	for hid in [5, 4, 17, 1, 2]:
		w.factory.add_hero(hid)
	w.phase = "playing"
	var hero: Dictionary = w.units[w.heroes[0]]
	for i in range(7300):
		if w.phase == "choice":
			w.choices.choose(0)
		var pos: Vector2 = hero.pos
		var action: String = hero.action
		var old_target: int = hero.target
		w.step()
		if w.time_ms < 115600:
			continue
		var target: Dictionary = w.units.get(hero.target, {})
		if target.is_empty():
			if old_target != hero.target:
				print(JSON.stringify({"time": w.time_ms, "pos": str(hero.pos), "target": hero.target, "old_target": old_target, "returning": hero.guard_return}))
			continue
		if old_target == hero.target and action == hero.action:
			continue
		print(JSON.stringify({"time": w.time_ms, "pos": str(hero.pos), "delta": str(hero.pos - pos),
			"action": hero.action, "previous": action, "facing": hero.facing,
			"cooldown": hero.attack_at - w.time_ms, "target": target.id, "template": target.template,
			"target_pos": str(target.pos), "target_action": target.action, "target_facing": target.facing,
			"target_target": target.target, "blocked_by": target.blocked_by,
			"intersects": Geometry.intersects(hero, target), "goal": str(Geometry.approach(hero, target))}))
	w.dispose()
	quit()
