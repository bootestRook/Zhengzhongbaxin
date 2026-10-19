extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_replacement(test, catalog)
	_overflow(test, catalog)
	for hero_id in catalog.available_heroes():
		_crowd(test, catalog, hero_id)

func world(catalog, hero_id: int = 4):
	var w = Session.new(catalog)
	w.start(81)
	w.spawn_wave = 1
	w.phase = "playing"
	w.factory.add_hero(hero_id)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.pos = Vector2(800, 800)
	hero.home = hero.pos
	hero.entering = false
	hero.skills.clear()
	hero.core.attributes.set_value("1", 1000000)
	hero.core.attributes.set_value("hp", 1000000)
	return w

func _replacement(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.core.attributes.set_value("3", 1)
	var far = w.factory.create("enemy", 103, Vector2(800, 550), 2)
	var close = w.factory.create("enemy", 103, Vector2(800, 750), 2)
	far.skills.clear()
	close.skills.clear()
	far.target = w.space.blocker(far).id
	far.ai_at = 900
	far.attack_at = 1200
	far.action_until = 500
	far.attack_events = [{"at":300,"target":hero.id,"wall":false}]
	test.assert_equal(w.space.blocker(close).id, hero.id, "closer enemy takes the occupied slot")
	test.assert_equal(far.blocked_by, 0, "displaced enemy loses its binding")
	test.assert_equal(far.target, 0, "displaced enemy stops pursuing the old blocker")
	test.assert_equal(far.ai_at, 900, "slot replacement preserves the decision clock")
	test.assert_equal(far.attack_at, 1200, "slot replacement preserves attack cooldown")
	test.assert_equal(far.action_until, 500, "slot replacement preserves a committed action")
	test.assert_equal(far.attack_events.size(), 1, "slot replacement preserves a committed hit")
	far.pos = hero.pos + Vector2(-25, 0)
	var health := U.hp(hero)
	w.time_ms = 300
	w.ai.advance_attack(far)
	test.assert_true(U.hp(hero) < health, "a committed in-range hit resolves after losing its slot")
	far.taunt = hero.id
	far.taunt_until = 1000
	w.space.bind(far, hero)
	far.target = hero.id
	w.space.bind(far, {})
	test.assert_equal(far.target, hero.id, "active skill taunt retains its independent target")
	w.time_ms = 1000
	w.space.bind(far, hero)
	w.space.bind(far, {})
	test.assert_equal(far.target, 0, "expired taunt cannot retain a displaced target")
	var boss = w.factory.create("boss", 105, Vector2(850, 700), 2)
	w.space.bind(boss, hero)
	boss.target = hero.id
	w.space.bind(boss, {})
	test.assert_equal(boss.target, hero.id, "boss selection remains independent of ordinary slots")
	w.dispose()

func _overflow(test, catalog) -> void:
	var w = world(catalog)
	var front: Dictionary = w.units[w.heroes[0]]
	front.core.attributes.set_value("3", 1)
	w.factory.add_hero(5)
	var rear: Dictionary = w.units[w.heroes[1]]
	rear.pos = Vector2(800, 1100)
	var first = w.factory.create("enemy", 103, Vector2(800, 790), 2)
	first.target = w.ai.choose_enemy(first).id
	var overflow = w.factory.create("elite", 103, Vector2(800, 920), 2)
	test.assert_equal(w.ai.choose_enemy(overflow).id, rear.id, "overflow can select another blocker with capacity")
	test.assert_equal(first.blocked_by, front.id, "a farther arrival does not steal the closer occupant's slot")
	front.core.attributes.set_value("3", 0)
	rear.core.attributes.set_value("3", 0)
	var passing = w.factory.create("enemy", 103, Vector2(900, 950), 2)
	passing.skills.clear()
	test.assert_true(w.ai.choose_enemy(passing).is_empty(), "no available blocker yields no hero target")
	var start: Vector2 = passing.pos
	w.space.rebuild()
	w.navigation.rebuild()
	w.ai.tick()
	test.assert_true(passing.pos.y > start.y, "unclaimed enemy advances toward the wall")
	w.dispose()

func _crowd(test, catalog, hero_id: int) -> void:
	var w = world(catalog, hero_id)
	var hero: Dictionary = w.units[w.heroes[0]]
	var capacity := int(U.stat(hero, 3))
	hero.core.attributes.set_value("17", 0)
	for i in range(32):
		var enemy = w.factory.create("enemy", 103, Vector2(620 + (i % 8) * 50, 560 + (i / 8) * 40), 2)
		enemy.skills.clear()
		enemy.core.attributes.set_value("1", 1000000)
		enemy.core.attributes.set_value("hp", 1000000)
	var peak := 0
	var overflow_ticks := 0
	var stale_ticks := 0
	for tick in range(1250):
		w.time_ms += 16
		w.space.rebuild()
		w.navigation.rebuild()
		w.ai.tick()
		var targeted := 0
		for enemy: Dictionary in w.units.values():
			if enemy.side == 2 and enemy.target == hero.id:
				targeted += 1
				stale_ticks += int(enemy.blocked_by != hero.id)
		peak = maxi(peak, targeted)
		overflow_ticks += int(targeted > capacity)
	test.assert_equal(capacity, int(catalog.record("heroes", hero_id).base["3"]), "hero %d keeps the source blocking capacity" % hero_id)
	test.assert_equal(peak, capacity, "crowd fully uses the available slots")
	test.assert_equal(overflow_ticks, 0, "ordinary pursuit never exceeds blocking capacity")
	test.assert_equal(stale_ticks, 0, "no ordinary pursuer retains a displaced binding")
	print("[BLOCK CAPACITY] hero=%d capacity=%d peak=%d overflow_ticks=%d stale_ticks=%d" % [hero_id,capacity,peak,overflow_ticks,stale_ticks])
	w.dispose()
