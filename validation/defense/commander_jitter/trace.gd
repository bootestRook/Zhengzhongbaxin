extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	for seed_value in [6, 17, 81]:
		battle(catalog, seed_value)
	quit()

func battle(catalog, seed_value: int) -> void:
	var w = Session.new(catalog)
	w.level_id = 5
	w.start(seed_value)
	for hid in [5]:
		w.factory.add_hero(hid)
	w.phase = "playing"
	var hero: Dictionary = w.units[w.heroes[0]]
	var quick_flips = 0
	var last_flip = -1000
	var changes: Array = []
	var last_delta = Vector2.ZERO
	var reversals = 0
	var action_changes = 0
	var last_action_at = -1000
	var rapid_changes: Array = []
	for i in range(7500):
		if w.phase == "choice":
			w.choices.choose(0)
		if w.phase != "playing":
			break
		var pos: Vector2 = hero.pos
		var facing: float = hero.facing
		var action: String = hero.action
		w.step()
		var delta: Vector2 = hero.pos - pos
		if delta.dot(last_delta) < -0.01:
			reversals += 1
			if changes.size() < 30:
				changes.append(["reverse", w.time_ms, str(pos), str(hero.pos), str(last_delta), str(delta), hero.action, hero.target, hero.get("path_index", 0)])
		if delta.length_squared() > 0.01:
			last_delta = delta
		if hero.action != action:
			action_changes += 1
			if w.time_ms - last_action_at <= 32 and rapid_changes.size() < 100:
				var target: Dictionary = w.units.get(hero.target, {})
				rapid_changes.append([w.time_ms, str(pos), str(hero.pos), action, hero.action, hero.target, str(target.get("pos", Vector2.ZERO)), str(Geometry.approach(hero, target)) if not target.is_empty() else "", hero.get("path_index", 0), hero.attack_at, hero.action_at])
			last_action_at = w.time_ms
		if hero.facing != facing:
			if w.time_ms - last_flip <= 48:
				quick_flips += 1
				if changes.size() < 30:
					var target: Dictionary = w.units.get(hero.target, {})
					changes.append([w.time_ms, str(pos), str(hero.pos), hero.action, hero.target, str(target.get("pos", Vector2.ZERO)), str(Geometry.approach(hero, target)) if not target.is_empty() else "", hero.get("path_index", 0)])
			last_flip = w.time_ms
	print(JSON.stringify({"battle": seed_value, "level": 5, "time": w.time_ms, "quick_flips": quick_flips, "reversals": reversals, "actions": action_changes, "attacks": hero.attacks, "changes": changes}))
	print("RAPID ", JSON.stringify(rapid_changes))
	w.dispose()
