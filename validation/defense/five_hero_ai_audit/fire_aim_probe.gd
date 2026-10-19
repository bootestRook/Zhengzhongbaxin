extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Geometry = preload("res://src/features/defense/domain/defense_projectile_geometry.gd")

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var rows: Array = []
	for template in [106, 112, 103, 107, 113]:
		for x in [600, 1000]:
			for facing in [-1.0, 1.0]:
				var w = Session.new(catalog)
				w.level_id = 5
				w.start(81)
				w.spawn_wave = 20
				w.stage = 19
				w.factory.add_hero(1)
				w.phase = "playing"
				var hero: Dictionary = w.units[w.heroes[0]]
				hero.pos = hero.home
				hero.busy_until = 100000
				var enemy = w.factory.create("enemy", template, Vector2(x, 800), 2)
				enemy.facing = facing
				enemy.busy_until = 100000
				enemy.skills.clear()
				enemy.traits.clear()
				enemy.core.attributes.set_value("1", 1000000)
				enemy.core.attributes.set_value("hp", 1000000)
				w.skills.cast(hero, hero.skills[21].data, enemy)
				var shot: Dictionary = w.missiles[0]
				var body: Array = enemy.motion.body_offset
				var center: Vector2 = enemy.pos + Vector2(body[0] * enemy.facing, body[1])
				var closest = Geometry2D.get_closest_point_to_segment(center, shot.from, shot.to)
				var row = {"template": template, "x": x, "facing": facing, "from": str(shot.from), "aim": str(shot.to),
					"body_center": str(center), "body_size": enemy.motion.body_size, "ray_to_body_center": closest.distance_to(center), "body_overlaps": 0}
				for tick in range(350):
					for missile in w.missiles:
						if int(missile.skill.get("__id__", 0)) == 21 and Geometry.overlaps(missile, enemy, Geometry.shape(missile)):
							row.body_overlaps += 1
					w.step()
				row.damage = hero.stats.damage
				row.hits = hero.hits
				rows.append(row)
				w.dispose()
	FileAccess.open("res://validation/defense/five_hero_ai_audit/fire_aim_probe.json", FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print("[FIRE AIM] total=", rows.size(), " zero_damage=", rows.filter(func(r): return r.damage == 0).size())
	quit()
