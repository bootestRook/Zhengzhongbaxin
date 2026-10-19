extends SceneTree

func _initialize() -> void:
	var suite = preload("res://tests/test_defense_ice_terms.gd").new()
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	assert(catalog.load_default().is_empty())
	var results: Array = []
	for replay in range(2):
		var w = suite.world(catalog)
		var hero: Dictionary = w.units[w.heroes[0]]
		for term in [401, 402, 403, 404, 405, 408]:
			suite.choose(w, term)
		for i in range(3):
			var target = preload("res://tests/test_defense_hero_skill_contracts.gd").new().enemy(w, hero.pos + Vector2(-150 + i * 150, -250))
			target.core.attributes.set_value("1", 1000000000)
			target.core.attributes.set_value("hp", 1000000000)
		var combos = 0
		var rains = 0
		for i in range(10000):
			assert(w.skills.cast(hero, hero.skills[20002].data, {}))
			var arrows = w.missiles.filter(func(p): return p.skill.has("ice_shot")).size()
			var areas = w.missiles.filter(func(p): return p.skill.has("ice_rain")).size()
			assert(arrows == 4 or arrows == 8)
			assert(areas <= 1)
			combos += int(arrows == 8)
			rains += areas
			w.missiles.clear()
		assert(combos >= 4750 and combos <= 5250)
		assert(rains >= 1800 and rains <= 2200)
		results.append({"casts": 10000, "combo": combos, "rain": rains})
		w.dispose()
	assert(results[0] == results[1])
	print("[OK] ice probability sample and deterministic replay: ", JSON.stringify(results))
	quit()
