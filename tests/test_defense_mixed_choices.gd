extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const Fixtures = preload("res://tests/test_defense_choice_rules.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var w = Session.new(catalog)
	w.start(889)
	test.assert_true(w.offers.all(func(item): return item.kind == "hero"), "opening still offers three first-hero candidates")
	w.factory.add_hero(1)
	w.phase = "playing"
	w.pending.clear()
	var owner: int = w.heroes[0]
	w.choices.options = {}
	for grade in range(2, 6):
		w.choices.options[str(90000 + grade)] = Fixtures.new().option(90000 + grade, grade, 1)
	var recruits = 0
	var counts = [0, 0, 0, 0]
	var valid = true
	var same_replay = Session.new(catalog)
	same_replay.start(889)
	same_replay.factory.add_hero(1)
	same_replay.choices.options = w.choices.options.duplicate(true)
	for deal in range(10000):
		w.choices.offer("upgrade")
		var keys: Array = []
		var count = 0
		valid = valid and w.offers.size() == 3
		for item in w.offers:
			var key = "%s:%d" % [item.kind, item.id]
			valid = valid and not keys.has(key)
			keys.append(key)
			if item.kind == "hero":
				count += 1
				valid = valid and item.id != 1 and item.owner == 0
			else:
				valid = valid and item.owner == owner
		counts[count] += 1
		recruits += count
		if deal < 25:
			same_replay.choices.offer("upgrade")
			test.assert_equal(w.offers, same_replay.offers, "mixed deals replay on the named RNG stream")
	test.assert_true(valid, "all mixed deals contain three unique eligible cards with correct owners")
	test.assert_true(recruits >= 7200 and recruits <= 7800, "30000 eligible slots track the configured 25 percent recruitment rate")
	test.assert_true(counts.all(func(count): return count > 0), "one deal can contain zero, one, two or three recruitment cards")
	print("[MIXED] slots=30000 recruits=%d counts=%s" % [recruits, str(counts)])
	same_replay.dispose()
	# Refresh excludes the previous recruitment group without applying any card.
	while not w.offers.any(func(item): return item.kind == "hero"):
		w.choices.offer("upgrade")
	var prior: Array = w.offers.filter(func(item): return item.kind == "hero").map(func(item): return item.id)
	var weights: Dictionary = w.choices.hero_weights.duplicate()
	var selected: Dictionary = w.selected.duplicate()
	w.refresh_left = 1
	test.assert_equal(w.submit("refresh"), "", "mixed refresh uses the existing refresh intent")
	var remaining = catalog.available_heroes().filter(func(id): return id != 1 and not prior.has(id))
	if remaining.size() >= 3:
		test.assert_true(w.offers.all(func(item): return item.kind != "hero" or not prior.has(item.id)), "mixed refresh excludes previous recruit candidates when enough remain")
	test.assert_equal(w.heroes.size(), 1, "refresh cannot recruit or consume an option")
	test.assert_equal(w.selected, selected, "refresh does not apply upgrades")
	test.assert_equal(w.choices.hero_weights, weights, "redrawing preserves hero balance")
	# Bonus and chest rewards remain upgrades even with a large recruitment pool.
	w.pending = [owner]
	for i in range(25):
		w.choices.offer("bonus")
		test.assert_true(w.offers.all(func(item): return item.kind == "upgrade" and item.owner == owner), "hero bonus excludes recruitment")
		test.assert_equal(w.loot.roll().kind, "upgrade", "chest rolling excludes recruitment")
	w.pending.clear()
	# Owned heroes keep occupying their slots after death.
	for id in [2, 4, 13, 17]:
		w.factory.add_hero(id)
	w.damage.defeat(w.units[owner], {})
	for i in range(25):
		w.choices.offer("upgrade")
		test.assert_true(w.offers.all(func(item): return item.kind == "upgrade"), "five heroes suppress recruitment including while an owned hero is dead")
	test.assert_true(not w.factory.add_hero(10), "sixth hero is still rejected")
	w.choices.options.clear()
	w.choices.offer("upgrade")
	test.assert_equal(w.phase, "playing", "exhausted full-team pool resumes battle without an empty choice screen")
	w.dispose()
	_collision(test, catalog)
	# No legal upgrades: recruitment fills the slots, without duplicates.
	w = Session.new(catalog)
	w.start(17)
	w.factory.add_hero(1)
	w.choices.options.clear()
	w.choices.offer("upgrade")
	test.assert_equal(w.offers.size(), 3, "recruitment fills slots when upgrade pool is exhausted")
	test.assert_true(w.offers.all(func(item): return item.kind == "hero"), "empty upgrade pool yields only available recruitment cards")
	w.dispose()

func _collision(test, catalog) -> void:
	# A synthetic collision keeps this routing test independent of live term IDs.
	var fixture_catalog = Catalog.new()
	fixture_catalog.load_default()
	var option: Dictionary = catalog.record("options", 201)
	option.id = 13
	option.__id__ = 13
	fixture_catalog._data.options["13"] = option
	for chosen_kind in ["hero", "upgrade"]:
		var w = Session.new(fixture_catalog)
		w.start(17)
		w.factory.add_hero(1)
		w.choices.options = {"13": fixture_catalog.record("options", 13)}
		var found = false
		for i in range(200):
			w.choices.offer("upgrade")
			if w.offers.any(func(item): return item.kind == "hero" and item.id == 13) and w.offers.any(func(item): return item.kind == "upgrade" and item.id == 13):
				found = true
				break
		test.assert_true(found, "equal numeric hero/option IDs can coexist in one mixed deal")
		if found:
			for i in range(w.offers.size()):
				if w.offers[i].kind == chosen_kind and w.offers[i].id == 13:
					test.assert_equal(w.submit("choose", {"index": i}), "", "ID collision selects by per-card kind")
					break
			test.assert_equal(w.heroes.size(), 2 if chosen_kind == "hero" else 1, "colliding recruitment cannot be mistaken for an upgrade")
			test.assert_equal(int(w.selected.get("13", 0)), 1 if chosen_kind == "upgrade" else 0, "colliding upgrade cannot be mistaken for recruitment")
		w.dispose()
