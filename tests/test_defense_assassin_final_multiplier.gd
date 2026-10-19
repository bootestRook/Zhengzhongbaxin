extends RefCounted

const Flow = preload("res://tests/test_defense_assassin_terms.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")

func run(test) -> void:
	var catalog = Flow.Catalog.new()
	catalog.load_default()
	for kind in ["elite", "boss"]:
		_tier(test, catalog, kind)
		_final_settlement(test, catalog, kind, 100.0)
		_final_settlement(test, catalog, kind, 2000.0)
	_derived(test, catalog)

func _tier(test, catalog, kind: String) -> void:
	var flow = Flow.new()
	var w = flow.world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	for term in [501, 502, 506]:
		flow.choose(w, term)
	var target = flow.enemy(w, owner.pos, kind)
	target.core.attributes.set_value("10", 100)
	flow.cast(w)
	test.assert_equal(U.hp(target), 99440.0, "without execution upgrade elite/boss has neither armor ignore nor triple multiplier")
	flow.choose(w, 508)
	target.core.attributes.set_value("hp", 20200)
	flow.cast(w)
	test.assert_equal(U.hp(target), 17920.0, "execution upgrade gives two separate 380-percent hits times three after settlement")
	test.assert_true(not target.dead, "elite/boss below twenty percent is damaged, not executed")
	w.dispose()

func _final_settlement(test, catalog, kind: String, shield: float) -> void:
	var flow = Flow.new()
	var w = flow.world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	for term in [501, 501, 502, 506, 508]:
		flow.choose(w, term)
	owner.core.attributes.set_value("12", 40)
	owner.core.attributes.set_value("7", 100)
	owner.core.attributes.set_value("8", 50)
	owner.skills[1435]["hunt_ready"] = true
	var target = flow.enemy(w, owner.pos, kind)
	target.core.attributes.set_value("10", 10000)
	target.core.attributes.set_value("29", 25)
	target.core.attributes.set_value("11", 20)
	target.shield = shield
	flow.cast(w)
	# Each hit: 510 * 1.4 magic * 1.5 critical * .75 resistance.
	# Shield then 20% reduction resolve normally; the remaining damage is x3.
	var damage = 3615.6 if shield == 100 else 0.0
	test.assert_true(absf(100000 - U.hp(target) - damage) < 0.001, "independent final x3 follows crit, hunt, magic, resistance, reduction and shield")
	test.assert_true(absf(owner.stats.damage - damage) < 0.001, "final multiplied damage is credited exactly")
	test.assert_true(absf(target.stats.taken - damage) < 0.001, "taken statistics use final actual hp damage")
	test.assert_true(absf(target.shield - (393.5 if shield == 2000 else 0.0)) < 0.001, "final multiplier cannot magnify damage before shield absorption")
	test.assert_true(not owner.skills[1435].hunt_ready, "hunt is consumed once across two triple-damage hits")
	w.dispose()

func _derived(test, catalog) -> void:
	var flow = Flow.new()
	var w = flow.world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	for term in Flow.TERMS:
		flow.choose(w, term)
	var target = flow.enemy(w, owner.pos + Vector2(0, -300), "elite")
	var collateral = flow.enemy(w, target.pos + Vector2(0, -180), "elite")
	flow.cast(w)
	test.assert_equal(U.hp(target), 97040.0, "only two main 460-percent hits are tripled; smoke and fan remain 100 each")
	test.assert_equal(U.hp(collateral), 99800.0, "collateral smoke and fan on elite targets never inherit final multiplier")
	w.damage.basic_hit(owner, collateral, 1)
	var before = U.hp(collateral)
	w.time_ms = 1000
	w.statuses.tick()
	test.assert_equal(before - U.hp(collateral), 30.0, "shock on elite targets retains its own 30-percent damage")
	test.assert_equal(catalog.record("skills", 1435).assassination.elite_multiplier, 3, "static final multiplier definition stays immutable")
	w.dispose()
