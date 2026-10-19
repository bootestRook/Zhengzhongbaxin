extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const UNLOCKED = [1, 2, 4, 13, 17]

func run(test) -> void:
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "initial roster catalog loads")
	test.assert_equal(catalog.available_heroes(), UNLOCKED, "only the five initial heroes can be recruited")
	var seen: Dictionary = {}
	for seed in range(1, 65):
		var w = Session.new(catalog)
		w.start(seed)
		var legal = w.offers.size() == 3
		for item in w.offers:
			legal = legal and _legal(w, item)
			seen[item.id] = true
		w.submit("refresh")
		for item in w.offers:
			legal = legal and _legal(w, item)
			seen[item.id] = true
		w.submit("choose", {"index": 0})
		for deal in range(10):
			w.choices.offer("upgrade")
			for item in w.offers:
				legal = legal and _legal(w, item)
			var reward = w.loot.roll()
			legal = legal and not reward.is_empty() and _legal(w, reward)
		w.pending = [w.heroes[0]]
		w.choices.offer("bonus")
		for item in w.offers:
			legal = legal and item.kind == "upgrade" and _legal(w, item)
		test.assert_true(legal, "seed %d recruitment, refresh, upgrades, bonus and loot stay inside the initial roster" % seed)
		w.dispose()
	test.assert_equal(seen.size(), 5, "all five initial heroes remain obtainable")
	_reject_locked(test, catalog)

func _legal(w, item: Dictionary) -> bool:
	if item.kind == "hero":
		return UNLOCKED.has(item.id)
	var owner: Dictionary = w.units.get(item.owner, {})
	var option: Dictionary = w.catalog.record("options", item.id)
	return not owner.is_empty() and UNLOCKED.has(owner.template) and option.type.has(owner.template)

func _reject_locked(test, catalog) -> void:
	var w = Session.new(catalog)
	w.start(3)
	var before = w.offers.duplicate(true)
	w.offers = [{"kind": "hero", "id": 5, "owner": 0}]
	test.assert_equal(w.submit("choose", {"index": 0}), "该英雄尚未解锁", "confirmation rejects an injected locked recruit")
	test.assert_true(w.heroes.is_empty() and w.history.is_empty(), "rejected recruitment changes no roster or history")
	w.offers = before
	w.submit("choose", {"index": 0})
	# Insert a complete locked Definition through the unit factory to exercise
	# selection guards independently of the normal recruitment filter.
	w.factory.add_hero(5)
	var locked: int = w.heroes[1]
	var item = w.choices.card(catalog.record("options", 397), locked)
	test.assert_true(not w.choices.eligible(catalog.record("options", 397), w.units[locked]), "locked commander options fail shared eligibility")
	test.assert_true(w.choices.upgrade_pool().all(func(candidate): return candidate.owner != locked), "locked owner cannot enter ordinary or chest upgrade pools")
	var history = w.history.duplicate(true)
	w.offers = [item]
	w.phase = "choice"
	test.assert_equal(w.submit("choose", {"index": 0}), "当前词条不可选择", "confirmation rejects an injected locked option")
	test.assert_equal(w.history, history, "rejected option changes no history")
	w.phase = "playing"
	w.offers.clear()
	w.loot.enqueue("elite")
	w.loot.advance()
	for reward in w.loot.current.items:
		test.assert_true(_legal(w, reward), "automatic rewards exclude an injected locked owner")
	w.dispose()
