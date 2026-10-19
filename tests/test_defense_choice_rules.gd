extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")

class FourHeroCatalog:
	extends "res://src/features/defense/domain/defense_catalog.gd"
	func available_heroes() -> Array:
		return [1, 2, 4, 13]

class OwnedHeroCatalog:
	extends "res://src/features/defense/domain/defense_catalog.gd"
	func available_heroes() -> Array:
		return [1, 2]

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var w = Session.new(catalog)
	test.assert_equal(w.submit("start"), "缺少对局种子", "domain requires an injected run seed")
	test.assert_equal(w.start(0), "无效对局种子", "zero seed cannot silently normalize to a fixed game")
	test.assert_equal(w.start(-1), "无效对局种子", "negative run seed rejected")
	test.assert_equal(w.start(0x80000000), "无效对局种子", "out-of-range run seed rejected")
	test.assert_equal(w.phase, "home", "invalid seed leaves session unchanged")
	w.start(3)
	test.assert_equal(ids(w.offers), [4, 2, 1], "hero candidates draw sequentially without replacement from the initial roster")
	w.submit("refresh")
	for id in ids(w.offers):
		test.assert_true(catalog.available_heroes().has(id), "five-hero refresh refills from the unlocked roster")
	test.assert_equal(w.refresh_left, 1, "first refresh consumes one of the two run-wide uses")
	test.assert_equal(w.submit("refresh"), "", "second refresh is available in the same deal")
	test.assert_equal(w.refresh_left, 0, "second refresh exhausts the run-wide allowance")
	var unchanged = w.offers.duplicate(true)
	test.assert_equal(w.submit("refresh"), "本局刷新次数已用完", "exhausted refresh rejected")
	test.assert_equal(w.offers, unchanged, "exhausted refresh cannot replace candidates")
	w.dispose()
	var a = Session.new(catalog)
	var b = Session.new(catalog)
	for seed in [3, 17, 889, 20261013]:
		a.start(seed)
		b.start(seed)
		test.assert_equal(a.offers, b.offers, "same injected seed replays opening candidates")
		a.submit("refresh")
		b.submit("refresh")
		test.assert_equal(a.offers, b.offers, "same seed and refresh input replay the next deal")
	a.start(3)
	b.start(23)
	test.assert_true(a.offers != b.offers, "different seeds exercise different opening deals")
	a.dispose()
	b.dispose()
	_refresh_small_pool(test, catalog)
	_upgrade_weights(test, catalog)
	_eligibility(test, catalog)
	_run_refresh_budget(test, catalog)

func _run_refresh_budget(test, catalog) -> void:
	var w = Session.new(catalog)
	w.start(53)
	test.assert_equal(w.refresh_left, 2, "new run receives exactly two shared refreshes")
	w.submit("pause")
	test.assert_equal(w.submit("refresh"), "当前无法刷新", "paused selection cannot spend a refresh")
	test.assert_equal(w.refresh_left, 2, "rejected paused refresh keeps both uses")
	w.submit("pause")
	w.submit("choose", {"index": 0})
	test.assert_equal(w.submit("refresh"), "当前无法刷新", "combat cannot spend a refresh")
	w.kills = int(w.level.waves[0].count)
	w.choices.advance()
	test.assert_equal(w.stage, 1, "real level advancement opens an upgrade deal")
	test.assert_equal(w.refresh_left, 2, "first level-up preserves the run-wide allowance")
	w.submit("refresh")
	test.assert_equal(w.refresh_left, 1, "upgrade refresh spends one shared use")
	w.submit("choose", {"index": 0})
	w.pending = [w.heroes[0], w.heroes[0]]
	w.choices.offer("bonus")
	test.assert_equal(w.refresh_left, 1, "specified-owner reward shares the remaining budget")
	w.submit("refresh")
	test.assert_equal(w.refresh_left, 0, "bonus refresh spends the final shared use")
	w.submit("choose", {"index": 0})
	test.assert_equal(w.choice_kind, "bonus", "second pending reward opens normally")
	test.assert_equal(w.refresh_left, 0, "chained pending rewards never refill refreshes")
	var offers: Array = w.offers.duplicate(true)
	var random_state: Dictionary = w.rng.snapshot()
	test.assert_equal(w.submit("refresh"), "本局刷新次数已用完", "third refresh is rejected across separate deals")
	test.assert_equal(w.offers, offers, "exhausted refresh preserves the current options")
	test.assert_equal(w.rng.snapshot(), random_state, "exhausted refresh consumes no gameplay randomness")
	w.submit("choose", {"index": 0})
	w.loot.enqueue("elite")
	w.loot.advance()
	test.assert_true(not w.submit("refresh").is_empty(), "roulette rewards cannot be refreshed")
	test.assert_equal(w.refresh_left, 0, "roulette neither spends nor refills refreshes")
	w.submit("reward_close", {"id": w.loot.current.id})
	w.kills += int(w.level.waves[w.stage].count)
	w.choices.advance()
	test.assert_equal(w.refresh_left, 0, "later level-up cannot restore the exhausted budget")
	w.finish(false)
	w.submit("start", {"seed": 17})
	test.assert_equal(w.refresh_left, 2, "retry from result restores exactly two uses")
	w.submit("refresh")
	w.finish(false)
	w.submit("home")
	w.submit("start", {"seed": 23})
	test.assert_equal(w.refresh_left, 2, "home then new run restores exactly two uses")
	w.dispose()

func ids(items: Array) -> Array:
	var result: Array = []
	for item in items:
		result.append(item.id)
	return result

func option(id: int, grade: int, hero: int) -> Dictionary:
	return {"id": id, "icon": "21:%d" % grade, "type": [hero], "title": "测试词条", "description": "测试描述",
		"options_num": 1, "premise1": [], "premise2": [], "isNew": 0, "numTable": []}

func world(catalog):
	var w = Session.new(catalog)
	w.start(3)
	w.factory.add_hero(1)
	w.factory.add_hero(2)
	w.phase = "playing"
	w.offers.clear()
	return w

func _refresh_small_pool(test, catalog) -> void:
	var limited = FourHeroCatalog.new()
	limited.load_default()
	var w = Session.new(limited)
	w.start(3)
	w.choices.offer("hero", true)
	var picked = ids(w.offers)
	test.assert_equal(picked.size(), 3, "short refresh pool brings previous heroes back to fill three slots")
	test.assert_true(picked[0] != picked[1] and picked[1] != picked[2] and picked[0] != picked[2], "small-pool refill still forbids duplicate heroes")
	for id in picked:
		test.assert_true(id in [1, 2, 4, 13], "refill remains inside the available hero roster")
	w.submit("choose", {"index": 0})
	var owned: int = w.units[w.heroes[0]].template
	w.choices.offer("hero")
	for id in ids(w.offers):
		test.assert_true(id != owned, "owned heroes never re-enter candidate pool")
	w.dispose()

func _upgrade_weights(test, catalog) -> void:
	var owned = OwnedHeroCatalog.new()
	owned.load_default()
	var w = world(owned)
	var first: int = w.heroes[0]
	var second: int = w.heroes[1]
	w.choices.options = {"901": option(901, 2, 1), "902": option(902, 5, 2)}
	w.selected.clear()
	w.choices.hero_weights = {first: 0, second: 5}
	w.choices.offer("upgrade")
	test.assert_equal(w.offers[0].owner, second, "hero weight selects the owner before item quality")
	test.assert_equal(w.offers[1].owner, first, "empty selected hero bucket falls back to the whole eligible pool")
	test.assert_equal(w.offers.size(), 2, "depleted pool hides unavailable slots instead of fabricating rewards")
	test.assert_true(w.offers[0].id != w.offers[1].id, "each slot excludes options already drawn in this deal")
	w.choices.options = {"901": option(901, 2, 1), "902": option(902, 3, 1)}
	w.choices.hero_weights = {first: 5, second: 0}
	w.choices.quality_weights = [0, 0, 10000, 0, 0]
	w.choices.offer("upgrade")
	test.assert_equal(w.offers[0].id, 902, "per-quality weights determine the selected option")
	test.assert_equal(w.offers[1].id, 901, "zero weighted bucket falls back uniformly rather than dropping a valid option")
	var weights = w.choices.hero_weights.duplicate()
	w.choices.offer("upgrade")
	test.assert_equal(w.choices.hero_weights, weights, "showing and refreshing candidates does not change hero balance")
	w.pending = [second]
	w.choices.options = {"901": option(901, 2, 1), "902": option(902, 3, 2)}
	w.choices.offer("bonus")
	test.assert_equal(w.offers[0].owner, second, "bonus candidates belong only to the specified hero")
	w.choices.balance(first)
	test.assert_equal(w.choices.hero_weights[first], 4, "confirmed owner loses one hero weight")
	test.assert_equal(w.choices.hero_weights[second], 1, "other owned hero gains one hero weight")
	for _i in range(10):
		w.choices.balance(first)
	test.assert_equal(w.choices.hero_weights[first], 0, "hero weight cannot become negative")
	w.start(17)
	test.assert_equal(w.choices.hero_weights.size(), 0, "new session resets the shared chest/choice hero balance")
	w.dispose()

func _eligibility(test, catalog) -> void:
	var w = world(catalog)
	w.selected = {"1": 1}
	var hero: Dictionary = w.units[w.heroes[0]]
	var item = option(901, 3, 1)
	item.premise1 = [[1, 1], [2, -1]]
	item.premise2 = [[3, 1], [4, 1]]
	w.choices.options["901"] = item
	w.selected["2"] = 0
	test.assert_true(not w.choices.eligible(item, hero), "positive alternatives need at least one satisfied prerequisite")
	w.selected["3"] = 1
	test.assert_true(w.choices.eligible(item, hero), "satisfied mandatory and one alternative prerequisite unlock candidate")
	w.selected["2"] = 1
	test.assert_true(not w.choices.eligible(item, hero), "negative prerequisite excludes a mutually exclusive choice")
	item.premise1 = []
	item.premise2 = []
	item.numTable = [901]
	test.assert_true(not w.choices.eligible(item, hero), "numTable templates cannot appear as selectable options")
	item.numTable = []
	w.selected["901"] = 1
	test.assert_true(not w.choices.eligible(item, hero), "option count cap excludes consumed items")
	w.selected.erase("901")
	var a = option(901, 2, 1)
	var b = option(902, 2, 1)
	a.isNew = 2
	b.isNew = 2
	a.options_num = 10
	b.options_num = 10
	w.choices.options = {"901": a, "902": b}
	w.selected = {"901": 1, "902": 1}
	test.assert_true(not w.choices.eligible(a, hero), "isNew group cap uses total confirmed selections")
	w.choices.options = {"901": option(901, 2, -1), "902": option(902, 2, -1)}
	w.choices.options["901"].isNew = -7
	w.choices.options["902"].isNew = -7
	w.choices.options["901"].options_num = 10
	w.choices.options["902"].options_num = 10
	w.selected = {"901": 4, "902": 3}
	w.selected.clear()
	test.assert_true(not w.choices.eligible(w.choices.options["901"], hero), "statue options are ineligible even with no prior selections")
	w.dispose()
