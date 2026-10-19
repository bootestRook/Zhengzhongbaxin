extends RefCounted

const Lab = preload("res://src/features/defense/domain/lab/battle_lab.gd")
const Config = preload("res://src/features/defense/domain/lab/lab_config.gd")

func run(test, catalog) -> Dictionary:
	var report = {"scope": "创建、配置及固定步进烟测；不等同于每个技能效果正确", "monsters": [], "terms": []}
	var lab = Lab.new(catalog)
	for key in catalog.records("monsters"):
		var value = Config.empty()
		var hero = Config.unit(1, "hero", 4, [800, 1000])
		hero.survival = "immortal"
		hero.actions = {"move": false, "attack": true, "skill": true}
		var monster = Config.unit(2, "enemy", int(key), [800, 950])
		monster.survival = "immortal"
		value.units = [hero, monster]
		var error: String = lab.load_config(value)
		test.assert_equal(error, "", "monster creates: " + key)
		if not error.is_empty(): continue
		lab.submit("advance", {"ticks": 180})
		test.assert_true(lab.world.diagnostics.is_empty(), "monster has no missing definition: " + key)
		var casts: Array = []
		for event in lab.world.trace:
			if event.type == "cast" and event.get("source", 0) == 2 and not event.skill in casts: casts.append(event.skill)
		report.monsters.append({"template": int(key), "declared_skills": catalog.record("monsters", int(key)).get("skill", []), "observed_casts": casts,
			"steps": 180, "status": "runtime_smoke_only", "diagnostics": lab.world.diagnostics.duplicate()})
	for hero_id in catalog.available_heroes():
		for key in catalog.records("options"):
			var option = catalog.record("options", int(key))
			if not option.get("type", []).has(hero_id): continue
			var config = Config.empty()
			var hero = Config.unit(1, "hero", hero_id, [800, 1000])
			hero.survival = "immortal"
			var initial: Array = catalog.record("heroes", hero_id).initial_options
			if not int(key) in initial:
				var error = Config.prerequisites(catalog, hero.terms, int(key), initial)
				test.assert_equal(error, "", "term prerequisites resolve: " + key)
				hero.terms[key] = 1
			var monster = Config.unit(2, "enemy", 104, [800, 950])
			monster.survival = "immortal"
			config.units = [hero, monster]
			var error: String = lab.load_config(config)
			test.assert_equal(error, "", "term configuration loads: " + key)
			if not error.is_empty(): continue
			lab.submit("advance", {"ticks": 180})
			test.assert_true(lab.inspect(1).terms.has(int(key)), "term attached to real instance: " + key)
			test.assert_true(lab.world.diagnostics.is_empty(), "term runtime has no missing definition: " + key)
			report.terms.append({"hero": hero_id, "term": int(key), "status": "configuration_and_runtime_smoke_only", "steps": 180})
	test.assert_equal(report.monsters.size(), catalog.records("monsters").size(), "every current monster selected")
	test.assert_true(not report.terms.is_empty(), "term coverage is nonzero")
	lab.dispose()
	return report
