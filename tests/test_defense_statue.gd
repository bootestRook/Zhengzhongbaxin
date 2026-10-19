extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")
const Statue = preload("res://src/features/defense/domain/defense_statue.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_distant_enemies(test, catalog)
	_impact_range(test, catalog)
	_feedback(test, catalog)

func world(catalog):
	var w = Session.new(catalog)
	w.level_id = 3
	w.start(81)
	w.phase = "playing"
	return w

func tick(w) -> void:
	w.time_ms += 16
	w.space.rebuild()
	w.navigation.rebuild()
	w.ai.tick()

func _distant_enemies(test, catalog) -> void:
	for template in [101, 106, 112]:
		for x in [350, 1250]:
			var w = world(catalog)
			var enemy = w.factory.create("enemy", template, Vector2(x, 1460), 2)
			enemy.skills.clear()
			var initial_hp: float = w.wall_hp
			for i in range(120):
				tick(w)
			test.assert_equal(w.wall_hp, initial_hp, "monster %d at side X%d cannot hit the statue from the bottom line" % [template, x])
			test.assert_equal(enemy.attacks, 0, "distant monster must approach before attacking")
			test.assert_true(absf(enemy.pos.x - Statue.BODY_CENTER.x) < absf(x - Statue.BODY_CENTER.x), "monster walks toward statue body horizontally")
			for i in range(3000):
				tick(w)
				if w.wall_hp < initial_hp:
					break
			test.assert_true(w.wall_hp < initial_hp, "monster %d reaches and damages the statue from X%d" % [template, x])
			test.assert_true(Geometry.intersects(enemy, Statue.TARGET), "statue damage happens inside the actual attack shape")
			w.dispose()

func _impact_range(test, catalog) -> void:
	for moved_away in [false, true]:
		var w = world(catalog)
		var enemy = w.factory.create("enemy", 101, Vector2(850, 1460), 2)
		enemy.skills.clear()
		enemy.pos = Geometry.approach(enemy, Statue.TARGET)
		w.ai.tick()
		test.assert_equal(enemy.attacks, 1, "monster in contact begins its attack animation")
		test.assert_equal(w.wall_hp, w.wall_max, "statue waits for the attack's effective frame")
		var event: Dictionary = enemy.attack_events[0]
		if moved_away:
			enemy.pos = Vector2(1250, 1460)
		w.time_ms = event.at
		w.ai.advance_attack(enemy)
		test.assert_equal(w.wall_hp, w.wall_max if moved_away else w.wall_max - U.stat(enemy, 4), "effective frame rechecks statue contact after displacement")
		test.assert_equal(w.visuals.filter(func(effect): return effect.kind == "wall_hit").size(), 0 if moved_away else 1, "only a landed statue hit produces a damage number")
		w.dispose()

func _feedback(test, catalog) -> void:
	var w = world(catalog)
	var enemy = w.factory.create("enemy", 101, Vector2(1250, 1460), 2)
	w.damage.apply_wall(enemy, {"damage": ["4:100"]})
	var effects = w.visuals.filter(func(effect): return effect.kind == "wall_hit")
	test.assert_equal(effects.size(), 1, "skill damage to statue uses the same feedback path")
	test.assert_equal(effects[0].pos, Statue.BODY_CENTER, "damage number anchors on statue body rather than attacker lane")
	test.assert_equal(w.snapshot().statue_pos, Statue.POSITION, "render snapshot shares the authoritative statue position")
	var selected = w.targets.select_rule(enemy, {}, {"type": [6]}, {})
	test.assert_equal(selected[0].pos, Statue.POSITION, "statue-targeted skills use the actual statue position")
	test.assert_equal(w.targets.attack_point(selected[0]), Statue.BODY_CENTER, "statue-targeted projectiles aim at its body")
	w.dispose()
