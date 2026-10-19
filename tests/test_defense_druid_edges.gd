extends RefCounted

const Flow = preload("res://tests/test_defense_druid_terms.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
var f = Flow.new()

func run(test, catalog) -> void:
	_target_priority(test, catalog)
	_skill_scope(test, catalog)
	var w = f.world(catalog)
	var target = f.ally(w)
	var source = f.enemy(w, target.pos)
	for term in [302, 303, 306, 308]:
		f.choose(w, term)
	f.cast(w)
	var hp = U.hp(source)
	w.damage.hit(source, target, 1, true, true, {"kind": "skill"})
	test.assert_equal(U.hp(source), hp - 50, "direct skills also trigger thorns")
	target.core.attributes.set_value("16", 100)
	hp = U.hp(source)
	w.damage.hit(source, target, 1, true, true)
	test.assert_equal(U.hp(source), hp, "missed attack cannot trigger thorns")
	target.core.attributes.set_value("16", 0)
	f.cast(w)
	test.assert_true(not w.statuses.has_status(source, 4), "refreshing armor cannot explode")
	w.damage.defeat(target, source)
	test.assert_true(not w.statuses.has_status(source, 4), "death cleanup does not explode")
	w.dispose()
	w = f.world(catalog)
	target = f.ally(w)
	for term in Flow.TERMS:
		f.choose(w, term)
	f.cast(w)
	var old: Dictionary = w.skills.thorns.flowers[0]
	var expires: int = old.expires
	var next: int = old.next
	w.time_ms = 1000
	f.cast(w)
	test.assert_true(w.skills.thorns.flowers.has(old), "existing flower really migrates on subsequent cast")
	test.assert_equal(old.expires, expires, "actual recast migration preserves original expiry")
	test.assert_equal(old.next, next, "actual recast migration preserves pulse clock")
	source = f.enemy(w, old.pos)
	w.units[w.heroes[0]].dead = true
	w.time_ms = 5000
	hp = U.hp(source)
	w.skills.thorns.tick()
	test.assert_true(U.hp(source) < hp, "caster death does not erase active flowers")
	test.assert_true(w.statuses.has_status(source, 5), "flower root is actually applied")
	w.time_ms = 7000
	w.statuses.tick()
	test.assert_true(not w.statuses.has_status(source, 5), "flower root expires after two seconds")
	w.time_ms = 15000
	w.skills.thorns.tick()
	test.assert_equal(old.next, 20000, "fifteen second flower includes all three scheduled pulses")
	w.paused = true
	var before: int = w.time_ms
	w.step()
	test.assert_equal(w.time_ms, before, "pause freezes flower and armor clocks")
	w.start(54)
	test.assert_true(w.skills.thorns.flowers.is_empty(), "new run clears surviving flowers")
	w.dispose()

func _target_priority(test, catalog) -> void:
	var w = f.world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	var near = f.ally(w, 4)
	var far = f.ally(w, 13)
	var middle = f.ally(w, 17)
	var outside = f.ally(w, 1)
	owner.core.attributes.set_value("hp", 1)
	near.core.attributes.set_value("1", 200)
	far.core.attributes.set_value("hp", 200)
	middle.core.attributes.set_value("hp", 300)
	outside.pos = owner.pos + Vector2(901, 0)
	var skill: Dictionary = owner.skills[20301].data
	var selected: Array = w.skills.thorns.targets(owner, skill)
	test.assert_equal(selected[0].id, far.id, "lower health percentage wins over lower absolute health and shorter distance")
	test.assert_true(f.cast(w), "health priority still uses actual skill cast")
	test.assert_equal(U.hp(far), 320, "lowest percentage ally receives actual healing")
	test.assert_true(w.statuses.has_status(far, 20301), "lowest percentage ally receives actual armor")
	test.assert_equal(U.hp(near), 100, "closer ally with less absolute health is not selected")
	test.assert_true(not w.statuses.has_status(owner, 20301), "injured caster stays excluded while legal allies exist")
	test.assert_true(not w.statuses.has_status(outside, 20301), "lower health percentage cannot bypass cast range")
	far.core.attributes.set_value("hp", 400)
	selected = w.skills.thorns.targets(owner, skill)
	test.assert_equal(selected[0].id, middle.id, "each cast reevaluates current health percentage")
	middle.dead = true
	selected = w.skills.thorns.targets(owner, skill)
	test.assert_equal(selected[0].id, far.id, "dead ally is excluded from health priority")
	middle.dead = false
	for term in [303, 306, 311]:
		f.choose(w, term)
	skill = owner.skills[20301].data
	selected = w.skills.thorns.targets(owner, skill)
	test.assert_equal([selected[0].id, selected[1].id], [middle.id, far.id], "symbiosis selects the two lowest health percentages")
	f.cast(w)
	test.assert_equal(U.hp(middle), 480, "first symbiosis target receives enhanced healing")
	test.assert_equal(U.hp(far), 580, "second symbiosis target receives enhanced healing")
	test.assert_true(w.statuses.has_status(middle, 20301) and w.statuses.has_status(far, 20301), "both low health targets receive armor")
	test.assert_true(not w.statuses.has_status(near, 20301), "symbiosis does not include higher health percentage ally")
	near.core.attributes.set_value("hp", 80)
	far.core.attributes.set_value("hp", 400)
	middle.core.attributes.set_value("hp", 400)
	far.pos = owner.pos + Vector2(100, 0)
	middle.pos = far.pos
	selected = w.skills.thorns.targets(owner, skill)
	test.assert_equal([selected[0].id, selected[1].id], [far.id, middle.id], "equal percentage uses distance then stable unit id")
	outside.pos = owner.pos + Vector2(900, 0)
	selected = w.skills.thorns.targets(owner, skill)
	test.assert_equal(selected[0].id, outside.id, "ally at cast range boundary remains eligible by health percentage")
	w.dispose()

func _skill_scope(test, catalog) -> void:
	var w = f.world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	var target = f.ally(w, 4)
	var unprotected = f.ally(w, 13)
	f.ally(w, 17)
	unprotected.core.attributes.set_value("hp", 900)
	var attacker = f.enemy(w, owner.pos + Vector2(0, -100))
	w.skills.learn(owner, 749)
	var other: Dictionary = owner.skills[749].data.duplicate(true)
	var passives: Array = owner.passives.duplicate(true)
	var before_stats: Array = []
	for key in range(1, 32):
		before_stats.append(U.stat(owner, key))
	var basic: float = w.damage.basic_hit(owner, attacker, U.stat(owner, 4))
	for term in Flow.TERMS:
		f.choose(w, term)
	var after_stats: Array = []
	for key in range(1, 32):
		after_stats.append(U.stat(owner, key))
	test.assert_equal(after_stats, before_stats, "thorn terms never modify global hero attributes")
	test.assert_equal(owner.passives, passives, "thorn terms never grant global passives")
	test.assert_equal(owner.skills[749].data, other, "thorn terms leave an existing different skill unchanged")
	test.assert_equal(w.damage.basic_hit(owner, attacker, U.stat(owner, 4)), basic, "thorn terms leave basic attack damage unchanged")
	w.skills.trigger(owner, "attack_emit", attacker)
	w.skills.trigger(owner, "attack", attacker)
	test.assert_true(w.skills.thorns.flowers.is_empty(), "basic attack triggers cannot create thorn flowers")
	test.assert_true(not w.statuses.has_status(attacker, 20306) and not w.statuses.has_status(attacker, 5), "basic attacks cannot apply thorn slow or flower root")
	w.damage.heal(owner, target, 100)
	test.assert_equal(U.hp(target), 200, "thorn healing bonus does not amplify unrelated healing")
	var hp: float = U.hp(attacker)
	w.damage.apply_skill(owner, attacker, owner.skills[749].data)
	test.assert_equal(hp - U.hp(attacker), 100, "different skill keeps its own damage")
	test.assert_true(w.skills.thorns.flowers.is_empty(), "different skill cannot generate thorn flowers")
	test.assert_true(not w.statuses.has_status(target, 20301) and target.shield == 0, "different skill cannot apply thorn armor or extra shield")
	hp = U.hp(attacker)
	w.damage.hit(attacker, target, 10, true, true)
	test.assert_equal(U.hp(attacker), hp, "learning thorn terms does not reflect damage without armor")
	test.assert_true(not w.statuses.has_status(attacker, 20306), "learning thorn terms does not slow attackers without armor")
	var late = f.world(catalog)
	for term in Flow.TERMS:
		f.choose(late, term)
	var late_owner: Dictionary = late.units[late.heroes[0]]
	late.skills.learn(late_owner, 749)
	test.assert_equal(late_owner.skills[749].data, other, "different skill learned later cannot inherit thorn terms")
	late.dispose()
	test.assert_true(f.cast(w), "thorn armor still casts with its own full upgrades")
	test.assert_true(w.statuses.has_status(target, 20301) and w.statuses.has_status(target, 20303), "actual thorn cast grants its armor and extra shield")
	test.assert_equal(w.skills.thorns.flowers.size(), 2, "actual thorn cast grants its upgraded flowers")
	hp = U.hp(attacker)
	w.damage.hit(attacker, unprotected, 10, true, true)
	test.assert_equal(U.hp(attacker), hp, "armor on other heroes cannot reflect damage from an unprotected hero")
	test.assert_true(not w.statuses.has_status(unprotected, 20301), "thorn armor remains limited to the selected two heroes")
	w.dispose()
