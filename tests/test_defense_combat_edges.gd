extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Traits = preload("res://src/features/defense/domain/defense_traits.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	_traits(test, catalog)
	_mitigation(test, catalog)
	_periodic_snapshot(test, catalog)
	_pending_animation(test, catalog)
	_projectile_lifetimes(test, catalog)
	_throw(test, catalog)
	_hp_selection(test, catalog)
	_death_timing(test, catalog)

func world(catalog):
	var w = Session.new(catalog)
	w.start(23)
	w.factory.add_hero(4)
	w.units[w.heroes[0]].skills.clear()
	w.spawn_wave = 20
	w.stage = 19
	w.phase = "playing"
	return w

func _traits(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	var enemy = w.factory.create("enemy", 101, hero.pos + Vector2(0, -100), 2)
	enemy.traits = [["dodge3", "100"]]
	test.assert_true(w.damage.traits.missed(hero, enemy, false, {}), "melee dodge trait applies to melee basic attack")
	hero.front = false
	test.assert_true(not w.damage.traits.missed(hero, enemy, false, {}), "melee dodge cannot evade ranged basic attack")
	enemy.traits = [["dodge4", "100"]]
	test.assert_true(w.damage.traits.missed(hero, enemy, false, {}), "ranged dodge applies to a ranged basic attack")
	test.assert_true(w.damage.traits.missed(hero, enemy, true, {"tags": PackedStringArray(["6"])}), "ranged dodge applies to magic normal attack")
	test.assert_true(not w.damage.traits.missed(hero, enemy, true, {}), "ranged dodge does not replace skill dodge")
	enemy.traits = [["dodge2", "100"]]
	test.assert_true(w.damage.traits.missed(hero, enemy, true, {}), "skill dodge applies to skill damage")
	hero.core.attributes.set_value("15", 100)
	test.assert_true(not w.damage.traits.missed(hero, enemy, true, {}), "accuracy cancels trait dodge")
	hero.core.attributes.set_value("24", 5)
	hero.traits = [["penetrate", "20", "40"]]
	test.assert_equal(Traits.penetration(hero), Vector2(25, 0.6), "fixed and proportional penetration remain distinct")
	w.dispose()

func _mitigation(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	var enemy = w.factory.create("enemy", 101, hero.pos, 2)
	hero.core.attributes.set_value("10", 100)
	hero.shield = 1000.0
	var value = w.damage.mitigation.apply(enemy, hero, 50, true, {"kind": "skill", "tags": PackedStringArray(["3", "4"])})
	test.assert_equal(value, 50.0, "no-defense and no-shield skill ignores hero armor and shield")
	test.assert_equal(hero.shield, 1000.0, "bypassed shield is preserved")
	value = w.damage.mitigation.apply(enemy, hero, 50, true, {"kind": "skill"})
	test.assert_equal(value, 1.0, "source hero spell retains minimum damage after shielding")
	enemy.core.attributes.set_value("10", 100)
	enemy.traits.clear()
	value = w.damage.mitigation.apply(hero, enemy, 50, true, {"kind": "skill", "tags": PackedStringArray(["3", "4"])})
	test.assert_equal(value, 1.0, "no-defense tag is restricted to hero recipients")
	w.dispose()

func _periodic_snapshot(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	var enemy = w.factory.create("enemy", 101, hero.pos, 2)
	enemy.core.attributes.set_value("10", 10000)
	enemy.shield = 10000.0
	w.statuses.add(enemy, hero, 1, 3000)
	var hp = U.hp(enemy)
	w.units.erase(hero.id)
	w.time_ms = 1000
	w.statuses.tick()
	test.assert_true(U.hp(enemy) < hp, "periodic status survives removal of its caster")
	test.assert_equal(enemy.shield, 10000.0, "periodic status bypasses defense and shield")
	w.dispose()

func _pending_animation(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	var enemy = w.factory.create("enemy", 101, hero.pos + Vector2(0, -40), 2)
	var skill = {"__id__": 999, "type": "6", "aim": [8], "damage": ["0:0:2"], "isContinued": 1, "triggerOpp": ["7:1"], "cd": 1000}
	hero.skills[999] = {"data": skill, "next": 0, "count": 0}
	w.ai.attack(hero, enemy)
	var attack_end: int = hero.action_until
	w.skills.trigger(hero, "hurt", enemy, U.stat(hero, 1))
	test.assert_equal(hero.action, "attack", "animated passive does not replace the current normal attack")
	test.assert_equal(hero.pending_actions.size(), 1, "animated passive is queued once")
	w.time_ms = attack_end
	w.ai.tick()
	test.assert_equal(hero.action, "skill", "queued passive starts its own skill animation when attack completes")
	test.assert_true(hero.action_until > attack_end, "queued skill keeps its animation duration")
	w.dispose()

func _projectile_lifetimes(test, catalog) -> void:
	var w = world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	var enemy = w.factory.create("enemy", 101, owner.pos + Vector2(0, -200), 2)
	var skill = {"__id__": 999, "type": "2", "damage": ["0:0:2"], "movie_effect": ["fireballboom", 1, 0.4]}
	owner.skills[999] = {"data": skill}
	w.projectiles.launch(owner, enemy, skill, Vector2.INF, 0)
	w.projectiles.tick()
	test.assert_equal(w.missiles.size(), 1, "area visual remains alive after its damage pulse")
	w.time_ms = 399
	w.projectiles.tick()
	test.assert_equal(w.missiles.size(), 1, "area lifetime does not finish early")
	w.time_ms = 400
	w.projectiles.tick()
	test.assert_equal(w.missiles.size(), 0, "area ends at its configured lifetime")
	skill = {"__id__": 1000, "type": "33", "damage": ["0:0:2"], "damage_num": 4, "damage_interval": 0.1, "speed": 500, "damage_range": [[200]], "movie_effect": ["fireball_pl", 1, -1]}
	w.projectiles.launch(owner, enemy, skill, Vector2.INF, 0)
	var p: Dictionary = w.missiles[0]
	w.time_ms = p.fly_until
	w.projectiles.tick()
	var pos: Vector2 = p.pos
	w.time_ms += 16
	w.projectiles.tick()
	test.assert_equal(p.pos, pos, "frisbee stops and attacks after its flight, without returning to the caster")
	w.dispose()

func _throw(test, catalog) -> void:
	var w = world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	var enemy = w.factory.create("enemy", 101, owner.pos + Vector2(200, -100), 2)
	var target_pos: Vector2 = enemy.pos
	var from: Vector2 = owner.pos
	w.projectiles.effects.apply(owner, enemy, {"__id__": 999, "speed": 500, "actionOth": [["throw", "8"]]})
	test.assert_true(owner.has("forced_motion"), "self-targeted throw moves the caster selected by its rule")
	test.assert_equal(enemy.pos, target_pos, "throw keeps the impacted destination in place")
	w.time_ms = owner.forced_motion.duration / 2
	w.ai.forced_move(owner)
	test.assert_true(owner.pos != from and owner.pos != target_pos, "throw traverses an arc instead of teleporting")
	w.time_ms = owner.forced_motion.duration
	w.ai.forced_move(owner)
	test.assert_equal(owner.pos, target_pos, "throw arrives at the impacted destination")
	test.assert_true(not owner.has("forced_motion"), "throw releases forced movement at completion")
	w.dispose()

func _hp_selection(test, catalog) -> void:
	var w = world(catalog)
	var owner: Dictionary = w.units[w.heroes[0]]
	var a = w.factory.create("enemy", 101, owner.pos, 2)
	var b = w.factory.create("enemy", 102, owner.pos, 2)
	a.core.attributes.set_value("1", 1000)
	a.core.attributes.set_value("hp", 600)
	b.core.attributes.set_value("1", 200)
	b.core.attributes.set_value("hp", 180)
	var result = w.targets.select_rule(owner, {"attack_range": 500}, {"type": [3], "targetCamp": 2}, {})
	test.assert_equal(result[0].id, a.id, "max HP target sorts absolute remaining health rather than percentage")
	result = w.targets.select_rule(owner, {"attack_range": 500}, {"type": [4], "targetCamp": 2}, {})
	test.assert_equal(result[0].id, a.id, "healing target sorts largest absolute missing health")
	w.dispose()

func _death_timing(test, catalog) -> void:
	var w = world(catalog)
	var hero: Dictionary = w.units[w.heroes[0]]
	var rescue = {"__id__": 999, "type": "6", "aim": [8], "damage": ["1:100:1"], "triggerOpp": ["9:100"], "cd": 10000}
	hero.skills[999] = {"data": rescue, "next": 0, "count": 0}
	w.damage.defeat(hero, {})
	test.assert_true(not hero.dead and U.hp(hero) > 0, "instant death-begin healing prevents death")
	hero.skills[1000] = {"data": {"__id__": 1000, "type": "6", "aim": [8], "damage": ["0:0:2"], "triggerOpp": ["10:100"], "actionOth": [["summon", "2", "1"]]}, "next": 0, "count": 0}
	w.damage.defeat(hero, {})
	test.assert_true(hero.dead, "death-begin rescue obeys its cooldown")
	test.assert_equal(hero.death_finish_at, 750, "death animation uses recorded frame duration")
	test.assert_equal(hero.revive_at, 20000, "warrior revival clock starts at death and includes animation")
	w.time_ms = 749
	w.factory.lifecycle()
	test.assert_true(not w.snapshot().heroes[0].tombstone, "tombstone waits until death animation ends")
	w.time_ms = 750
	w.factory.lifecycle()
	w.projectiles.tick()
	test.assert_true(w.snapshot().heroes[0].tombstone, "death finish starts tombstone phase")
	var summons = w.units.values().filter(func(u): return u.owner == hero.id and not u.dead)
	test.assert_equal(summons.size(), 1, "death-after skill can summon while its caster is dead")
	w.factory.lifecycle()
	w.projectiles.tick()
	test.assert_equal(w.units.values().filter(func(u): return u.owner == hero.id and not u.dead).size(), 1, "death-after event is emitted once")
	w.dispose()
