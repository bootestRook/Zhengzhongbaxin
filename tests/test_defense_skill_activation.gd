extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Fixture = preload("res://tests/test_defense_hero_roster.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
var fixture = Fixture.new()

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	for params in [[4, 755, 200, 10000], [1, 17, 1200, 6000]]:
		_activation(test, catalog, params)
	_shield_upgrade(test, catalog)
	_fire_distance(test, catalog)
	_thorn_lifetime(test, catalog)
	_element_colors(test, catalog)

func _activation(test, catalog, params: Array) -> void:
	var w = fixture.world(catalog, params[0])
	var hero: Dictionary = w.units[w.heroes[0]]
	hero.pos = Vector2(200, 1600)
	var state: Dictionary = hero.skills[params[1]]
	w.time_ms = 5000
	var before: Dictionary = {"action": hero.action, "until": hero.action_until, "attack": hero.attack_at, "next": state.next}
	test.assert_true(not w.skills.ready_action(hero), "empty field does not begin a ranged activation")
	var ally = w.factory.create("hero", 2, hero.pos, 1)
	test.assert_true(not w.skills.ready_action(hero), "an ally cannot satisfy the enemy activation gate")
	ally.dead = true
	# Probe the foot-centered activation circle while staying inside the
	# independently attack-point-centered projectile target circle.
	var direction = Vector2(0.8, -0.6)
	var target = fixture.enemy(w, hero.pos + direction * (params[2] + 1))
	test.assert_true(not w.skills.ready_action(hero), "one unit outside the activation circle cannot start a skill")
	target.pos = hero.pos + direction * params[2]
	target.hidden_until = w.time_ms + 1000
	test.assert_true(not w.skills.ready_action(hero), "hidden enemies cannot start a skill")
	target.hidden_until = 0
	target.dead = true
	test.assert_true(not w.skills.ready_action(hero), "dead enemies cannot start a skill")
	test.assert_equal({"action": hero.action, "until": hero.action_until, "attack": hero.attack_at, "next": state.next}, before, "failed activation does not change animation, basic attack or cooldown")
	test.assert_true(w.skills.queue.is_empty(), "failed activation queues no cast")
	target.dead = false
	test.assert_true(w.skills.ready_action(hero), "enemy entering the exact circle boundary permits immediate casting")
	test.assert_equal(state.next, 5000 + params[3], "cooldown starts from the successful activation")
	if params[0] == 4:
		fixture.spells(w, 6200)
		var shield: Dictionary = w.damage.protection.active(hero)
		test.assert_true(not shield.is_empty(), "shield applies after its actual windup")
		if not shield.is_empty():
			test.assert_equal(shield.expires - shield.started, 4000, "base shield remains exactly four seconds")
	w.dispose()

func _shield_upgrade(test, catalog) -> void:
	var w = fixture.world(catalog, 4)
	var hero: Dictionary = w.units[w.heroes[0]]
	var target = fixture.enemy(w, hero.pos + Vector2(500, 0))
	test.assert_true(not w.skills.ready_action(hero), "base shield waits for enemies within two hundred")
	w.upgrades.apply(hero, 200103)
	target.pos = hero.pos + Vector2(201, 0)
	test.assert_true(not w.skills.ready_action(hero), "taunt expansion does not expand the casting boundary")
	target.pos = hero.pos + Vector2(470, 0)
	test.assert_true(not w.skills.ready_action(hero), "an enemy in expanded taunt range alone cannot start shield")
	fixture.enemy(w, hero.pos + Vector2(0, 200))
	test.assert_true(w.skills.ready_action(hero), "an enemy at the two hundred casting boundary starts shield")
	fixture.spells(w, 1200)
	test.assert_equal(target.taunt, hero.id, "expanded taunt reaches its area after a valid cast")
	test.assert_equal(catalog.record("skills", 755).get("radius_bonus", 0), 0, "range upgrades do not mutate static definitions")
	w.dispose()

func _fire_distance(test, catalog) -> void:
	for sample in [[Vector2(800, 100), true], [Vector2(800, 849), true], [Vector2(800, 850), true],
		[Vector2(1160, 880), true], [Vector2(1160.8, 879.4), false]]:
		var w = fixture.world(catalog, 1)
		var hero: Dictionary = w.units[w.heroes[0]]
		hero.pos = Vector2(200, 1600) if sample[0].x > 1000 else Vector2(800, 1300)
		fixture.enemy(w, sample[0])
		test.assert_equal(w.skills.ready_action(hero), sample[1], "fireball uses its 1200 distance gate without a hidden Y850 restriction")
		w.dispose()

func _thorn_lifetime(test, catalog) -> void:
	var w = fixture.world(catalog, 2)
	var hero: Dictionary = w.units[w.heroes[0]]
	w.factory.add_hero(4)
	var ally: Dictionary = w.units[w.heroes[1]]
	ally.pos = hero.pos + Vector2(80, 0)
	ally.core.attributes.set_value("hp", 100)
	test.assert_true(w.skills.ready_action(hero), "thorn armor starts for friendly hero")
	fixture.spells(w, 1200)
	var heal = U.hp(ally)
	test.assert_equal(heal, 100 + U.stat(hero, 4) * 1.2, "thorn armor heals exactly once")
	w.skills.cast(hero, hero.skills[20301].data, {})
	var effect: Dictionary = w.snapshot().visuals.back()
	test.assert_equal(effect.expires - effect.start, 400, "thorn link remains visible four hundred milliseconds")
	ally.pos += Vector2(30, -10)
	hero.pos += Vector2(-20, 10)
	effect = w.snapshot().visuals.back()
	test.assert_equal(effect.from_pos, w.targets.attack_point(hero), "link follows caster")
	test.assert_equal(effect.to_pos, w.targets.attack_point(ally), "link follows protected hero")
	w.dispose()

func _element_colors(test, catalog) -> void:
	for params in [[13, 20002, "#72d8ff", "0;106;104"], [17, 1435, "#ffe45b", "0;106;109"]]:
		var w = fixture.world(catalog, params[0])
		var hero: Dictionary = w.units[w.heroes[0]]
		var target = fixture.enemy(w, hero.pos + Vector2(50, 0))
		w.projectiles.launch(hero, target, hero.skills[params[1]].data, Vector2.INF, 0)
		test.assert_equal(w.snapshot().missiles[0].tint, params[2], "element color reaches the rendering snapshot")
		test.assert_equal(hero.skills[params[1]].data.damage_type, params[3], "visual color preserves the damage element")
		w.projectiles.launch(hero, target, catalog.record("skills", 21), Vector2.INF, 0)
		test.assert_equal(w.snapshot().missiles[1].tint, "#ffffff", "uncolored projectiles preserve their original artwork")
		w.dispose()
