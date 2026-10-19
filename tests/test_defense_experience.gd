extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Geometry = preload("res://src/features/defense/domain/defense_attack_geometry.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_recruitment(test, catalog)
	_revival(test, catalog)
	_walk_to_formation(test, catalog)
	_attack_during_entry(test, catalog)
	_entry_cooldown(test, catalog)

func _recruitment(test, catalog) -> void:
	var first = _level_choices(test, catalog, 17)
	var second = _level_choices(test, catalog, 889)
	test.assert_true(first != second, "recruitment timing depends on random deals rather than fixed levels")
	for option in catalog.records("options").values():
		test.assert_true(int(option.get("isNew", 0)) >= 0, "runtime definitions omit obsolete statue upgrades")

func _level_choices(test, catalog, seed: int) -> Array:
	var w = Session.new(catalog)
	w.start(seed)
	_choose(w)
	var recruit_levels: Array = [1]
	for level in range(2, 21):
		var before: int = w.heroes.size()
		for i in range(int(w.level.waves[level - 2].count)):
			var enemy = w.factory.create("enemy", 101, Vector2(800, 500), 2)
			w.damage.defeat(enemy, {})
		w.choices.advance()
		test.assert_equal(w.snapshot().stage, level, "kill progression reaches level %d" % level)
		test.assert_equal(w.choice_kind, "upgrade", "every post-opening level uses mixed upgrade choices")
		for item in w.offers:
			if item.kind == "upgrade":
				test.assert_true(int(catalog.record("options", item.id).get("isNew", 0)) >= 0, "ordinary choices contain no statue option")
		_choose(w)
		if w.heroes.size() > before:
			recruit_levels.append(level)
	test.assert_true(w.heroes.size() <= 5, "random recruitment never exceeds five heroes")
	var history: Array = w.history.duplicate(true)
	w.kills += 1000
	w.choices.advance()
	test.assert_equal(w.snapshot().stage, 20, "level twenty is the ceiling")
	test.assert_equal(w.history, history, "max level cannot add another upgrade or recruitment")
	if w.heroes.size() == 5:
		for id in catalog.available_heroes():
			if not w.heroes.any(func(uid): return w.units[uid].template == id):
				test.assert_true(not w.factory.add_hero(id), "sixth distinct hero cannot join")
				break
	w.dispose()
	return recruit_levels

func _choose(w) -> void:
	while w.phase in ["choice", "reward"]:
		if w.phase == "reward":
			w.submit("reward_close", {"id": w.loot.current.id})
			continue
		var pick = 0
		for i in range(w.offers.size()):
			if w.offers[i].kind == "hero" and w.offers[i].id != 6:
				pick = i
				break
		w.submit("choose", {"index": pick})

func _revival(test, catalog) -> void:
	var seconds = {1: 20, 4: 20, 10: 20, 2: 10, 3: 10, 5: 10}
	for id in catalog.available_heroes():
		var w = Session.new(catalog)
		w.start(17)
		w.factory.add_hero(id)
		w.phase = "playing"
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.skills.clear()
		w.wall_hp = 1234
		var home: Vector2 = hero.home
		var death_position = Vector2(450 + id * 30, 720)
		hero.pos = death_position
		var duration: int = seconds[catalog.record("heroes", id).profession] * 1000
		w.damage.defeat(hero, {})
		test.assert_equal(hero.revive_at, duration, "hero %d revival starts at death with exact profession duration" % id)
		test.assert_equal(w.snapshot().heroes[0].attributes["23"], duration / 1000, "displayed revival attribute is the complete duration")
		w.submit("pause")
		w.step()
		test.assert_equal(w.time_ms, 0, "paused battle freezes revival clock")
		w.submit("pause")
		w.time_ms = duration - 1
		w.factory.lifecycle()
		test.assert_true(hero.dead, "hero remains dead until the deadline")
		test.assert_true(w.snapshot().heroes[0].tombstone, "death animation finishes before revival")
		test.assert_equal(w.snapshot().heroes[0].pos, death_position, "hero %d tombstone remains at the actual defeat position" % id)
		test.assert_equal(w.wall_hp, 1234.0, "waiting for revival does not consume statue health")
		w.time_ms = duration
		w.factory.lifecycle()
		test.assert_true(not hero.dead and U.hp(hero) == U.stat(hero, 1), "profession deadline restores full health")
		test.assert_equal(hero.pos, w.factory.hero_spawn(), "revival uses the statue-front spawn")
		var lights = w.visuals.filter(func(effect): return effect.kind == "revive" and effect.start == duration)
		test.assert_equal(lights.size(), 2, "revival emits the light column and ground ring once")
		for light in lights:
			test.assert_equal(light.pos, hero.pos, "revival light follows the actual revival point")
			test.assert_true(light.expires - light.start == 500 and not light.loop, "revival light plays the complete summon animation once")
		w.factory.lifecycle()
		test.assert_equal(w.visuals.filter(func(effect): return effect.kind == "revive" and effect.start == duration).size(), 2, "later lifecycle calls cannot repeat the revival light")
		test.assert_equal(hero.home, home, "revival retains the allocated formation destination")
		test.assert_true(hero.entering and not hero.back_lock and hero.target == 0, "revival resets entry AI and stale targets")
		test.assert_equal(w.wall_hp, 1234.0, "completed revival does not consume statue health")
		w.dispose()

func _walk_to_formation(test, catalog) -> void:
	for id in catalog.available_heroes():
		var w = Session.new(catalog)
		w.start(17)
		w.spawn_wave = 20
		w.stage = 19
		w.phase = "playing"
		w.factory.add_hero(id)
		var hero: Dictionary = w.units[w.heroes[0]]
		var start: Vector2 = hero.pos
		# Isolate formation movement from the new independent timed skills.
		for state in hero.skills.values():
			state.next = 1000000
		w.step()
		test.assert_true(hero.pos != start and hero.pos.distance_to(start) <= w.ai.movement_speed(hero) * 0.016 + 0.01, "hero %d walks one real movement step without teleporting" % id)
		for i in range(2200):
			w.step()
			w.drain_events()
			if not hero.entering:
				break
		test.assert_true(not hero.entering and hero.pos.distance_to(hero.home) < 71, "hero %d reaches its formation cell" % id)
		w.dispose()

func _attack_during_entry(test, catalog) -> void:
	for id in [4, 1]:
		var w = Session.new(catalog)
		w.start(17)
		w.spawn_wave = 20
		w.stage = 19
		w.phase = "playing"
		w.factory.add_hero(id)
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.skills.clear()
		var far = w.factory.create("enemy", 101, hero.pos + Vector2(0, -maxf(U.stat(hero, 26), 400) - 100), 2)
		test.assert_true(w.ai.choose_enemy(hero).is_empty(), "entry AI ignores an enemy beyond detection range")
		var near = w.factory.create("enemy", 101, hero.pos + Vector2(0, -40), 2)
		near.core.attributes.set_value("1", 100000)
		near.core.attributes.set_value("hp", 100000)
		near["busy_until"] = 100000
		far["busy_until"] = 100000
		test.assert_equal(w.ai.choose_enemy(hero).id, near.id, "entry AI prioritizes the enemy in detection range")
		for i in range(160):
			w.step()
			w.drain_events()
		test.assert_true(hero.stats.damage > 0 and hero.entering, "hero %d attacks before reaching formation" % id)
		w.damage.defeat(near, {})
		w.damage.defeat(far, {})
		for i in range(2200):
			w.step()
			w.drain_events()
			if not hero.entering:
				break
		test.assert_true(not hero.entering and hero.pos.distance_to(hero.home) < 71, "hero %d continues to formation after combat" % id)
		w.dispose()

func _entry_cooldown(test, catalog) -> void:
	for id in catalog.available_heroes():
		for reviving in [false, true]:
			_entry_cooldown_case(test, catalog, id, reviving)

func _entry_cooldown_case(test, catalog, id: int, reviving: bool) -> void:
	var label = "hero %d %s" % [id, "revival" if reviving else "summon"]
	var w = Session.new(catalog)
	w.start(17)
	w.spawn_wave = 20
	w.stage = 19
	w.phase = "playing"
	w.factory.add_hero(id)
	var hero: Dictionary = w.units[w.heroes[0]]
	if reviving:
		w.damage.defeat(hero, {})
		w.time_ms = hero.revive_at
		w.factory.lifecycle()
	test.assert_true(hero.entering and hero.pos == w.factory.hero_spawn(), label + " begins at the actual entry point")
	for state in hero.skills.values():
		state.next = w.time_ms + 1000000
	var enemy = w.factory.create("enemy", 101, hero.pos + Vector2(0, -40), 2)
	enemy.core.attributes.set_value("1", 100000)
	enemy.core.attributes.set_value("hp", 100000)
	enemy["busy_until"] = w.time_ms + 1000000
	test.assert_true(Geometry.intersects(hero, enemy), label + " has a live enemy inside its real attack geometry")
	var origin: Vector2 = hero.pos
	w.step()
	test.assert_true(hero.action == "attack" and hero.attacks == 1, label + " attacks immediately when basic attack is ready")
	var attack_end: int = hero.action_until
	var attack_start: int = hero.action_at
	for i in range(200):
		if w.time_ms + 16 >= attack_end:
			break
		w.step()
	test.assert_equal(hero.pos, origin, label + " does not walk during the basic attack animation")
	test.assert_true(hero.action == "attack" and hero.action_at == attack_start and hero.action_until == attack_end, label + " preserves the complete basic attack action")
	var distance: float = hero.pos.distance_squared_to(hero.home)
	w.step()
	test.assert_true(hero.action == "walk" and hero.pos.distance_squared_to(hero.home) < distance, label + " moves toward formation during cooldown with an enemy still in range")
	test.assert_true(not enemy.dead and Geometry.intersects(hero, enemy), label + " cooldown movement does not require losing the target")
	var attack_due: int = hero.attack_at
	# The entry destination remains authoritative even if the target moves away.
	enemy.pos = origin + Vector2(300, 0)
	distance = hero.pos.distance_squared_to(hero.home)
	for i in range(12):
		w.step()
	test.assert_true(hero.action == "walk" and hero.pos.distance_squared_to(hero.home) < distance, label + " continues toward formation instead of chasing during cooldown")
	test.assert_equal(hero.attack_at, attack_due, label + " walking does not reset the attack cooldown")
	enemy.pos = hero.pos + Vector2(0, -40)
	w.time_ms = hero.attack_at
	w.step()
	test.assert_true(hero.action == "attack" and hero.attacks == 2, label + " stops walking and resumes basic attacks when ready")
	var second_attack_end: int = hero.action_until
	for i in range(200):
		if w.time_ms + 16 >= second_attack_end:
			break
		w.step()
	w.step()
	# Keep the real initial skill available while the basic attack is cooling down.
	if id == 2:
		w.factory.add_hero(4)
		var ally: Dictionary = w.units[w.heroes[1]]
		ally.pos = hero.pos + Vector2(100, 0)
		ally["busy_until"] = w.time_ms + 1000000
	for state in hero.skills.values():
		state.next = w.time_ms
	enemy.pos = hero.pos + Vector2(0, -40)
	hero.ai_at = w.time_ms
	hero.attack_at = w.time_ms + 10000
	w.step()
	var skill_end: int = hero.action_until
	var skill_start: int = hero.action_at
	test.assert_true(hero.action in ["attack", "skill"] and skill_end > w.time_ms, label + " ready skill interrupts cooldown walking through the real scheduler")
	var channelled: bool = not hero.channel_skills.is_empty()
	var locked = true
	for i in range(200):
		if w.time_ms + 16 >= hero.action_until:
			break
		w.step()
		if w.time_ms < hero.action_until:
			locked = locked and hero.action in ["attack", "skill", "skill2"]
			if not channelled:
				locked = locked and hero.action_at == skill_start and hero.action_until == skill_end
	test.assert_true(w.time_ms + 16 >= hero.action_until, label + " completes its real skill or channel within the bounded scenario")
	test.assert_true(locked, label + " formation movement cannot cancel or restart the skill animation")
	distance = hero.pos.distance_squared_to(hero.home)
	w.step()
	test.assert_true(hero.action == "walk" and hero.pos.distance_squared_to(hero.home) < distance, label + " resumes formation movement after the full skill action")
	# Reaching the slot with a live target must finish entry rather than lock it on.
	hero.pos = hero.home
	w.step()
	test.assert_true(not hero.entering and hero.back_lock, label + " finishes entry at its formation slot even while a target survives")
	test.assert_equal(w.phase, "playing", label + " remains a live combat scenario")
	w.dispose()
