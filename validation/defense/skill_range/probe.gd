extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var catalog = preload("res://src/features/defense/domain/defense_catalog.gd").new()
	catalog.load_default()
	var fixture = preload("res://tests/test_defense_hero_roster.gd").new()
	for seed_value in range(8):
		var w = fixture.world(catalog, 1)
		w.start(seed_value)
		print("seed ", seed_value, " offers ", w.snapshot().offers.map(func(o): return o.id))
		w.dispose()
	for point in [Vector2(800, 100), Vector2(800, 849), Vector2(800, 850), Vector2(1160, 880), Vector2(1160.8, 879.4)]:
		var w = fixture.world(catalog, 1)
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.pos = Vector2(200, 1600) if point.x > 1000 else Vector2(800, 1300)
		var enemy = fixture.enemy(w, point)
		var starts: bool = w.skills.ready_action(hero)
		print("fire point=", point, " foot_distance=", hero.pos.distance_to(point), " attack_offset=", w.targets.attack_point(hero) - hero.pos,
			" guard=", w.guard.battle_allows(hero, enemy), " starts=", starts, " projectile_targets=", w.skills.fireball.targets(hero, hero.skills[17].data.fireball).size())
		w.dispose()
	quit()
