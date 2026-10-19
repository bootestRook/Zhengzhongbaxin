extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")
const Assassin = preload("res://tests/test_defense_assassin_terms.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	var load_error = catalog.load_default()
	test.assert_equal(load_error, "", "guard fixtures load the current generated catalog")
	if not load_error.is_empty():
		return
	for hid in [4, 17]:
		_entry(test, catalog, hid)
		_targets(test, catalog, hid)
		_hold_and_return(test, catalog, hid)
		_action_lock(test, catalog, hid)
		_advance(test, catalog, hid)
		_boundary_attack(test, catalog, hid)
	_hunt(test, catalog)

func world(catalog, hid: int):
	var w = Session.new(catalog)
	w.start(53)
	w.spawn_wave = 20
	w.stage = 19
	w.phase = "playing"
	w.factory.add_hero(hid)
	for state in w.units[w.heroes[0]].skills.values():
		state.next = 1000000
	return w

func enemy(w, pos: Vector2, kind: String = "enemy") -> Dictionary:
	var target = w.factory.create(kind, 101 if kind == "enemy" else 105, pos, 2)
	for key in ["1", "hp"]:
		target.core.attributes.set_value(key, 100000)
	target["busy_until"] = 1000000
	return target

func _entry(test, catalog, hid: int) -> void:
	var w = world(catalog, hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	var target = enemy(w, hero.pos + Vector2(200, 0))
	hero.target = target.id
	hero.ai_at = 1000
	test.assert_true(not Geometry.reaches(hero, target), "entry fixture has a target outside melee reach")
	var distance: float = hero.pos.distance_squared_to(hero.home)
	w.step()
	test.assert_true(hero.pos.distance_squared_to(hero.home) < distance, "hero %d with ready attack walks to formation instead of chasing off-route target" % hid)
	for tick in range(1200):
		w.step()
		if not hero.entering:
			break
	test.assert_true(not hero.entering and not target.dead and hero.pos.distance_to(hero.home) < 71, "hero %d completes real entry while the off-route target survives" % hid)
	w.dispose()

func _targets(test, catalog, hid: int) -> void:
	var w = world(catalog, hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.pos = hero.home
	var far = enemy(w, Vector2(hero.home.x, 470))
	far.target = hero.id
	var boss = enemy(w, Vector2(hero.home.x, 460), "boss")
	test.assert_true(w.targets.can_finish_chase(), "last-wave boss exception exists for ranged cleanup")
	test.assert_true(not w.ai.choose_enemy(hero).is_empty(), "the chase boundary does not remove enemies from front hero targeting")
	var near = enemy(w, hero.home + Vector2(60, -50))
	test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), near.id, "front hero acquires nearby enemy in the middle-lower guard area")
	var rear = enemy(w, Vector2(1200, 1250))
	test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), rear.id, "rear leak takes priority over a forward contact")
	rear.hidden_until = 1000000
	test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), near.id, "hidden rear enemy cannot steal defense priority")
	test.assert_equal(w.guard.limit_position(hero, far.pos).y, 480.0, "an attack beyond the boundary clamps the movement endpoint instead of deleting the target")
	w.dispose()

func _hold_and_return(test, catalog, hid: int) -> void:
	var w = world(catalog, hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.pos = hero.home
	var target = enemy(w, hero.home + Vector2(60, -80))
	var minimum: float = hero.pos.y
	for tick in range(1000):
		w.step()
		minimum = minf(minimum, hero.pos.y)
	test.assert_true(hero.attacks >= 3, "hero %d sustains actual melee combat within the guard area" % hid)
	test.assert_true(minimum >= 480, "hero %d never walks beyond the fixed chase boundary" % hid)
	test.assert_true(not target.dead, "guard test observes continued contact instead of ending the fight")
	# Capture one entire cooldown in contact, without a forced trip to the slot.
	for tick in range(200):
		w.step()
		if w.time_ms >= hero.action_until and w.time_ms < hero.attack_at and hero.action == "idle":
			break
	var held: Vector2 = hero.pos
	for tick in range(8):
		w.step()
	test.assert_equal(hero.pos, held, "hero %d stands steady during post-entry contact cooldown" % hid)
	target.pos.y = 100
	for tick in range(800):
		w.step()
	test.assert_true(hero.pos.y >= 480 and hero.pos.y <= 500, "front hero follows an escaping target only as far as the movement boundary")
	target.dead = true
	for tick in range(800):
		w.step()
	test.assert_true(hero.pos.distance_to(hero.home) < 71 and hero.back_lock, "hero %d releases escaping target and walks back to its own slot" % hid)
	test.assert_true(not hero.guard_return, "return state ends after reaching the formation cell")
	w.dispose()

func _action_lock(test, catalog, hid: int) -> void:
	var w = world(catalog, hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.pos = Vector2(hero.home.x, 450)
	var target = enemy(w, hero.pos + Vector2(0, -30))
	w.ai.attack(hero, target)
	var end: int = hero.action_until
	var origin: Vector2 = hero.pos
	for tick in range(100):
		if w.time_ms + 16 >= end:
			break
		w.step()
	test.assert_true(hero.action == "attack" and hero.pos == origin, "hero %d finishes a committed attack before recovering from displacement" % hid)
	w.step()
	test.assert_true(hero.guard_return and hero.action == "walk" and hero.pos.y > origin.y, "hero %d begins gradual recovery after the action ends" % hid)
	test.assert_true(hero.pos.distance_to(origin) < 10, "recovering from displacement moves one step instead of snapping to the chase line")
	# A surviving enemy can be attacked again as soon as the hero is inside
	# the chase boundary. Remove it to isolate the targetless return path.
	target.dead = true
	for tick in range(500):
		w.step()
	test.assert_true(hero.pos.distance_to(hero.home) < 71, "off-zone displacement recovers without a position snap")
	w.dispose()

func _advance(test, catalog, hid: int) -> void:
	var w = world(catalog, hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.pos = hero.home
	var target = enemy(w, Vector2(hero.home.x, 650))
	test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), target.id, "front hero acquires a target inside the red-box area before close contact")
	var before: Vector2 = hero.pos
	w.step()
	test.assert_true(hero.pos.y < before.y, "front hero immediately walks toward the available forward target")
	var minimum: float = hero.pos.y
	for tick in range(1400):
		w.step()
		minimum = minf(minimum, hero.pos.y)
	test.assert_true(hero.stats.damage > 0 and hero.attacks > 0, "front hero really reaches and attacks the forward target")
	test.assert_true(minimum < hero.home.y - 200 and minimum >= 480, "front hero can cross the obsolete formation-relative limit without crossing the red box")
	target.pos.y = 470
	hero.pos = Vector2(hero.home.x, 490)
	for tick in range(100):
		w.ai.move(hero, Vector2(hero.pos.x, 0), true, false)
		test.assert_true(hero.pos.y >= 480, "movement clamps every step to the fixed red-box boundary")
	var side = enemy(w, Vector2(350 if hero.home.x > 800 else 1250, 650))
	target.hidden_until = 1000000
	test.assert_equal(w.ai.choose_enemy(hero).get("id", 0), side.id, "the full width of the red box is available to front heroes")
	w.dispose()

func _boundary_attack(test, catalog, hid: int) -> void:
	var w = world(catalog, hid)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.guard_return = true
	hero.pos = Vector2(hero.home.x, 480)
	var target = enemy(w, hero.pos + Vector2(0, -160 if hid == 17 else -20))
	if hid == 17:
		hero.skills[1435].next = 0
		hero.attack_at = 1000000
	else:
		test.assert_true(Geometry.reaches(hero, target), "boundary melee fixture is inside its real hit geometry")
	for tick in range(200):
		w.step()
		if hid != 17:
			test.assert_true(hero.pos.y >= 480, "a basic attack beyond the chase line keeps the walking hero inside it")
		if hero.stats.damage > 0:
			break
	test.assert_true(hero.stats.damage > 0, "a ready attack hits an in-range enemy beyond the chase boundary even while returning")
	if hid == 17:
		test.assert_equal(hero.pos, target.pos, "assassination really lands on an in-range target outside the chase boundary")
		test.assert_true(w.visuals.any(func(v): return v.get("res", "") == "hero17:kill" and v.pos == target.pos), "assassination slash appears at the outside target and landing")
		var landing: Vector2 = hero.pos
		var end: int = hero.action_until
		while w.time_ms + 16 < end:
			w.step()
			test.assert_equal(hero.pos, landing, "outside assassination completes its committed animation before walking back")
		w.step()
		test.assert_true(hero.pos.y > landing.y and hero.pos.y < 480 and hero.pos.distance_to(landing) < 10,
			"outside assassination begins a gradual walking return without snapping to the boundary")
		for tick in range(500):
			var before: Vector2 = hero.pos
			w.step()
			test.assert_true(hero.pos.distance_to(before) < 10, "outside assassination returns in walking steps instead of teleporting back")
			if hero.pos.y >= 480:
				break
		test.assert_true(hero.pos.y >= 480, "assassin walks back inside while the attacked outside target is still alive")
		test.assert_true(not target.dead, "returning from an outside assassination does not require killing its target")
	w.dispose()

func _hunt(test, catalog) -> void:
	var w = world(catalog, 17)
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.entering = false
	hero.pos = hero.home
	hero.attack_at = 1000000
	for term in [501, 502, 506]:
		Assassin.new().choose(w, term)
	hero.skills[1435].next = 0
	var first = enemy(w, hero.pos + Vector2(0, -20))
	first.core.attributes.set_value("hp", 1)
	for tick in range(100):
		w.step()
		if first.dead:
			break
	test.assert_true(first.dead and hero.skills[1435].hunt_ready, "real assassination kill arms hunt")
	var second = enemy(w, Vector2(hero.home.x, 650))
	second.core.attributes.set_value("hp", 1)
	var outside = enemy(w, Vector2(hero.home.x, 470))
	outside.core.attributes.set_value("hp", 1)
	var distant = enemy(w, Vector2(hero.home.x, 50))
	var minimum: float = hero.pos.y
	for tick in range(400):
		w.step()
		minimum = minf(minimum, hero.pos.y)
	test.assert_true(second.dead, "hunt retains its real recast against an in-zone target")
	test.assert_true(outside.dead and not distant.dead and minimum < 480, "hunt really lands outside to kill a target within its own skill range")
	test.assert_true(hero.pos.y >= 480, "hunt walks back inside after its outside kill without chaining to an out-of-range enemy")
	test.assert_true(hero.skills[1435].hunt_ready and hero.skills[1435].next <= w.time_ms, "no legal target preserves the ready hunt bonus and cooldown")
	var rear = enemy(w, Vector2(hero.home.x, 1230))
	rear.core.attributes.set_value("hp", 1)
	for tick in range(600):
		w.step()
	test.assert_true(rear.dead and not distant.dead, "ready hunt prioritizes rear leaks while respecting its real range")
	distant.dead = true
	for tick in range(800):
		w.step()
	test.assert_true(hero.pos.distance_to(hero.home) < 71, "assassin returns to formation after all targets are gone")
	w.dispose()
