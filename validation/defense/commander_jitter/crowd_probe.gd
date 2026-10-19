extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	for heroes in [[5], [5, 4, 17, 1, 2]]:
		for seed_value in [1, 2, 3, 6, 17, 81]:
			battle(catalog, seed_value, heroes)
	quit()

func battle(catalog, seed_value: int, heroes: Array) -> void:
	var w = Session.new(catalog)
	w.level_id = 5
	w.start(seed_value)
	for hid in heroes:
		w.factory.add_hero(hid)
	w.phase = "playing"
	var hero: Dictionary = w.units[w.heroes[0]]
	var last_delta = Vector2.ZERO
	var previous_action_change = -1000
	var previous_facing_change = -1000
	var changes: Array = []
	var reversals = 0
	var stutters = 0
	var flips = 0
	for i in range(15000):
		if w.phase == "choice":
			w.choices.choose(0)
		if w.phase != "playing":
			break
		var pos: Vector2 = hero.pos
		var facing: float = hero.facing
		var action: String = hero.action
		var target: int = hero.target
		w.step()
		var delta: Vector2 = hero.pos - pos
		if delta.dot(last_delta) < -0.01 and delta.length_squared() < 100:
			reversals += 1
			if changes.size() < 20:
				changes.append(["reverse", w.time_ms, str(pos), str(hero.pos), hero.action, target, hero.target])
		if delta.length_squared() > 0.01:
			last_delta = delta
		if hero.action != action:
			if action == "walk" and hero.action == "idle" and hero.target == target and w.time_ms - previous_action_change <= 32:
				stutters += 1
				if changes.size() < 20:
					changes.append(["stutter", w.time_ms, str(pos), str(hero.pos), target])
			previous_action_change = w.time_ms
		if hero.facing != facing:
			if w.time_ms - previous_facing_change <= 400:
				flips += 1
				if changes.size() < 20:
					changes.append(["flip", w.time_ms, str(pos), str(hero.pos), target, hero.target])
			previous_facing_change = w.time_ms
	print(JSON.stringify({"seed": seed_value, "roster": heroes, "time": w.time_ms, "flips": flips, "stutters": stutters, "reversals": reversals, "attacks": hero.attacks, "changes": changes}))
	w.dispose()
