extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "combat metadata loads")
	_formation(test, catalog)
	_attack_frames(test, catalog)
	_targets(test, catalog)
	_summons(test, catalog)
	_waves(test, catalog)
	_projectiles(test, catalog)
	_healing_targets(test, catalog)
	_fire_events(test, catalog)

func world(catalog):
	var w = Session.new(catalog)
	w.start(17)
	w.spawn_wave = 20
	w.stage = 19
	w.phase = "playing"
	return w

func _formation(test, catalog) -> void:
	for ids in [[4, 5, 7, 8, 9], [1, 2, 3, 10, 14]]:
		var w = world(catalog)
		var first_pos = Vector2.ZERO
		for i in range(5):
			test.assert_true(w.factory.add_hero(ids[i]), "distinct documented hero joins")
			var u: Dictionary = w.units[w.heroes[i]]
			var points: Array = w.combat.formation["front" if u.front else "back"][i]
			test.assert_equal(u.pos, w.factory.hero_spawn(), "new hero appears in front of the statue")
			for j in range(i + 1):
				test.assert_equal(w.units[w.heroes[j]].home, Vector2(points[j][0], points[j][1]), "row home follows resource layout")
			if i == 0:
				first_pos = u.pos
			else:
				test.assert_equal(w.units[w.heroes[0]].pos, first_pos, "existing hero does not teleport during row change")
		w.dispose()
	var w = world(catalog)
	w.factory.add_hero(4)
	var first: Dictionary = w.units[w.heroes[0]]
	test.assert_true(not w.factory.add_hero(4), "duplicate hero rejected before creation")
	var death_position = Vector2(650, 620)
	first.pos = death_position
	w.damage.defeat(first, {})
	test.assert_equal(w.snapshot().heroes[0].pos, death_position, "death animation stays at the actual defeat position")
	w.factory.add_hero(5)
	test.assert_equal(first.home, Vector2(1000, 950), "dead hero retains its arrival index")
	w.time_ms = first.death_finish_at
	w.factory.lifecycle()
	test.assert_equal(w.snapshot().heroes[0].pos, death_position, "recruitment cannot move the tombstone away from the defeat position")
	w.time_ms = first.revive_at
	w.factory.lifecycle()
	test.assert_equal(first.pos, w.factory.hero_spawn(), "revive appears in front of the statue and retains its home")
	w.dispose()

func _healing_targets(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(2)
	w.factory.add_hero(4)
	var owner: Dictionary = w.units[w.heroes[0]]
	var ally: Dictionary = w.units[w.heroes[1]]
	ally.pos = owner.pos + Vector2(0, -100)
	ally.core.attributes.set_value("hp", U.hp(ally) - 100)
	var enemy = w.factory.create("enemy", 101, ally.pos + Vector2(20, 0), 2)
	var hp = U.hp(ally)
	var enemy_hp = U.hp(enemy)
	var skill = {"__id__": 999, "type": "2:2", "damage": ["0:100:1"], "damage_range": [[150]], "movie_effect": ["heal2", 1, 1]}
	owner.skills[999] = {"data": skill}
	w.projectiles.launch(owner, ally, skill, Vector2.INF, 0)
	w.projectiles.tick()
	test.assert_true(U.hp(ally) > hp, "friendly area heals allied units")
	test.assert_equal(U.hp(enemy), enemy_hp, "friendly area cannot heal enemies")
	w.wall_hp = 1000
	skill = {"__id__": 1000, "type": "6:2", "aim": [46], "damage": ["0:100:1"], "movie_effect": ["heal2", 1, 1]}
	owner.skills[1000] = {"data": skill}
	w.skills.cast(owner, skill, {})
	w.projectiles.tick()
	test.assert_true(w.wall_hp > 1000, "wall-targeted healing changes authoritative wall state")
	w.dispose()

func _attack_frames(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(4)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.skills.clear()
	var enemy = w.factory.create("enemy", 101, hero.pos + Vector2(0, -40), 2)
	w.ai.attack(hero, enemy)
	var hp = U.hp(enemy)
	w.time_ms = 358
	w.ai.advance_attack(hero)
	test.assert_equal(U.hp(enemy), hp, "warrior valid frame 3 has no damage before 359ms at baseline animation rate")
	w.time_ms = 359
	w.ai.advance_attack(hero)
	test.assert_true(U.hp(enemy) < hp, "warrior hit occurs on valid frame")
	w.dispose()
	w = world(catalog)
	w.factory.add_hero(1)
	hero = w.units[w.heroes[0]]
	hero.skills.clear()
	enemy = w.factory.create("enemy", 101, hero.pos + Vector2(0, -400), 2)
	w.ai.attack(hero, enemy)
	w.time_ms = 477
	w.ai.advance_attack(hero)
	test.assert_equal(w.missiles.size(), 1, "ranged valid frame emits a projectile")
	hp = U.hp(enemy)
	w.projectiles.tick()
	test.assert_equal(U.hp(enemy), hp, "ranged damage waits for flight")
	for i in range(30):
		w.time_ms += 16
		w.projectiles.tick()
	test.assert_true(U.hp(enemy) < hp, "ranged projectile actually hits")
	w.dispose()

func _targets(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(1)
	var hero: Dictionary = w.units[w.heroes[0]]
	var a = w.factory.create("enemy", 101, hero.pos + Vector2(0, -100), 2)
	var b = w.factory.create("enemy", 102, hero.pos + Vector2(0, -200), 2)
	b.core.attributes.set_value("hp", U.stat(b, 1) * 0.2)
	var rule = {"type": [4], "targetCamp": 2, "random": "2:2", "targetHp": [0, 50], "targetEntity": [102]}
	var targets = w.targets.select_rule(hero, {"attack_range": 500}, rule, a)
	test.assert_equal(targets.size(), 1, "HP and entity filters exclude invalid candidates")
	test.assert_equal(targets[0].id, b.id, "ordinary previous target does not override skill filter")
	w.factory.add_hero(4)
	var blocker: Dictionary = w.units[w.heroes[1]]
	hero.pos = hero.home
	blocker.pos = blocker.home
	a.pos = blocker.pos + Vector2(0, -80)
	test.assert_equal(w.space.blocker(a).id, blocker.id, "enemy binds available block capacity")
	w.damage.defeat(blocker, a)
	test.assert_equal(a.blocked_by, 0, "death releases blocker ownership")
	w.dispose()

func _summons(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(1)
	var hero: Dictionary = w.units[w.heroes[0]]
	var skill = {"__id__": 999, "actionOth": [["summon", "2", "2", "10", "2"]]}
	hero.skills[999] = {"data": skill, "summons": []}
	w.projectiles.effects.apply(hero, hero, skill)
	w.projectiles.effects.apply(hero, hero, skill)
	var alive = 0
	for u: Dictionary in w.units.values():
		if u.kind == "summon" and not u.dead:
			alive += 1
	test.assert_equal(alive, 3, "limit replacement occurs before batch and preserves source overshoot behavior")
	test.assert_equal(w.heroes.size(), 1, "summons do not occupy hero slots")
	w.dispose()

func _waves(test, catalog) -> void:
	var w = world(catalog)
	w.spawn_wave = 12
	var boss = w.factory.create("boss", 105, Vector2(800, 10), 2)
	w.spawn_wave = 17
	test.assert_true(not w.spawn.can_advance(), "unresolved boss prevents sixth wave ahead")
	w.damage.defeat(boss, {})
	test.assert_true(w.spawn.can_advance(), "dead boss releases advance gate")
	w.spawn_wave = 0
	w.spawn.reset()
	w.spawn.tick()
	test.assert_equal(w.spawn.normal_total, 1, "first wave emits immediately")
	w.spawn.spawn_encounter({"id": 114, "kind": "boss", "wave": 20, "distribution": 4, "hp_multiplier": 1, "atk_multiplier": 1})
	var found: Dictionary = w.units.values().back()
	test.assert_true(absf(found.pos.x - 800) < 0.01 and absf(found.pos.y - 10) < 0.01, "boss obeys center distribution")
	w.dispose()

func _projectiles(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(10)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.skills.clear()
	var a = w.factory.create("enemy", 101, hero.pos + Vector2(0, -100), 2)
	var b = w.factory.create("enemy", 102, hero.pos + Vector2(0, -400), 2)
	a.pos.x = hero.pos.x + hero.motion.attack_offset[0] * hero.facing - a.motion.attack_offset[0] * a.facing
	b.pos.x = a.pos.x
	var skill = {"__id__": 999, "type": "4", "damage": ["0:10"], "damage_range": [[40]], "movie_effect": ["laserdie", 1, 1], "damage_num": 1}
	hero.skills[999] = {"data": skill}
	w.projectiles.launch(hero, a, skill, Vector2.INF, 0)
	var beam: Dictionary = w.missiles[0]
	b.pos = beam.from + beam.direction * 400 - Vector2(b.motion.body_offset[0] * b.facing, b.motion.body_offset[1])
	var hp = U.hp(b)
	w.projectiles.tick()
	test.assert_true(U.hp(b) < hp, "laser collision includes other enemies along its segment")
	w.dispose()

func _fire_events(test, catalog) -> void:
	var w = world(catalog)
	w.factory.add_hero(1)
	var owner: Dictionary = w.units[w.heroes[0]]
	owner.skills.clear()
	var a = w.factory.create("enemy", 101, owner.pos + Vector2(-25, -100), 2)
	var b = w.factory.create("enemy", 102, owner.pos + Vector2(-25, -170), 2)
	var c = w.factory.create("enemy", 103, owner.pos + Vector2(-25, -220), 2)
	for enemy in [a, b, c]:
		enemy.core.attributes.set_value("hp", 10000)
	var child = {"__id__": 1000, "type": "6", "damage": ["0:0:2"]}
	owner.skills[1000] = {"data": child, "next": 0, "count": 0}
	child = {"__id__": 1001, "type": "6", "damage": ["0:0:2"]}
	owner.skills[1001] = {"data": child, "next": 0, "count": 0}
	var parent = {"__id__": 999, "type": "9", "aim": [1], "attack_range": 1000, "damage": ["0:1"],
		"damage_num": 10, "damage_range": [[100]], "speed": 15000, "running_fire": 2, "salvo": 1,
		"parameters": [0.1, 6], "skillGroupType": [[1, 1000], [13, 1001]]}
	owner.skills[999] = {"data": parent, "next": 0, "count": 0}
	w.skills.cast(owner, parent, a)
	test.assert_equal(w.missiles.size(), 2, "salvo emits two simultaneous copies")
	w.projectiles.tick()
	var hit_chains = w.skills.queue.filter(func(row): return row.skill == 1000)
	var cd_chains = w.skills.queue.filter(func(row): return row.skill == 1001)
	test.assert_true(hit_chains.size() <= 2, "first-hit chain runs at most once per piercing projectile")
	test.assert_equal(cd_chains.size(), 1, "CD-fire chain runs once for a burst rather than once per salvo copy")
	w.damage.defeat(a, {})
	w.time_ms = 99
	w.skills.tick()
	test.assert_equal(w.missiles.filter(func(p): return p.skill.__id__ == 999 and p.start == 99).size(), 0, "next burst respects firing interval")
	w.time_ms = 100
	w.skills.tick()
	var later = w.missiles.filter(func(p): return p.skill.__id__ == 999 and p.start == 100)
	test.assert_equal(later.size(), 2, "next burst fires at its scheduled time")
	for p in later:
		test.assert_true(p.target != a.id, "a later burst retargets instead of shooting a dead cached recipient")
	w.dispose()
