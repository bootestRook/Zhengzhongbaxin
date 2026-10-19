extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
const U = preload("res://src/features/defense/domain/defense_units.gd")
const Statue = preload("res://src/features/defense/domain/defense_statue.gd")

func run(test) -> void:
	var catalog = Catalog.new()
	test.assert_equal(catalog.load_default(), "", "formal gem catalog loads")
	test.assert_equal(catalog.records("gems").size(), 300, "formal gem table keeps all 300 rows")
	test.assert_equal(catalog.record("gems", 143).effect.value, 12.0, "stage gem keeps the percentage after the wave number")
	test.assert_equal(catalog.record("gems", 217).effect.cooldown_ms, 60000, "low-health regeneration keeps the sixty-second cooldown")
	test.assert_equal(catalog.record("gems", 277).description, "多重射击额外触发1次连击", "multi-combo wording uses the confirmed description")
	test.assert_equal(catalog.record("gems", 70).description, "暴击伤害+5%", "critical damage gem uses the formal percentage")
	test.assert_equal(catalog.record("gems", 76).effect.type, "suspended", "attack speed remains suspended")
	test.assert_equal(catalog.record("gems", 190).effect.radius, 300.0, "statue punishment uses the selected 300-unit radius")
	var world = Session.new(catalog)
	var snapshot: Dictionary = world.equipment.snapshot()
	test.assert_true(snapshot.gems.head.size() > 0, "formal inventory replaces test gems")
	var ordinary = _item(snapshot, catalog, "攻击增幅", "普通")
	var fine = _item(snapshot, catalog, "攻击增幅", "精良")
	test.assert_true(not ordinary.is_empty() and not fine.is_empty(), "attack gem copies exist")
	test.assert_equal(world.submit("gem_inlay", {"part": "head", "item": ordinary}), "", "ordinary gem can be installed")
	test.assert_equal(world.submit("gem_inlay", {"part": "head", "item": fine}), "请选择要替换的宝石", "higher quality same family requests replacement")
	test.assert_equal(world.submit("gem_replace", {"part": "head", "item": fine, "slot": 0}), "", "higher quality same family replaces")
	world.start(1)
	var hero_index: int = world.offers.find_custom(func(item): return int(item.id) == 1)
	if hero_index >= 0:
		world.submit("choose", {"index": hero_index})
	var hero: Dictionary = world.units[world.heroes[0]]
	test.assert_equal(U.stat(hero, 4), 66.0, "attack gem applies to a newly recruited hero")
	var enemy = world.factory.create("enemy", 101, hero.pos + Vector2(0, -200), 2)
	world.damage.hit(enemy, hero, 10, false, false)
	var hp_before = U.hp(hero)
	world.time_ms = 4000
	world.statuses.tick()
	test.assert_equal(U.hp(hero), hp_before, "life regeneration does not tick at four seconds")
	world.time_ms = 5000
	world.statuses.tick()
	test.assert_true(U.hp(hero) > hp_before, "life regeneration ticks every five seconds")

	var burn_world = Session.new(catalog)
	var burn_snapshot: Dictionary = burn_world.equipment.snapshot()
	var burn_item = _item(burn_snapshot, catalog, "烈焰焚身", "至尊")
	var burn_part: String = _part(burn_snapshot, catalog, burn_item)
	test.assert_equal(burn_world.submit("gem_inlay", {"part": burn_part, "item": burn_item}), "", "burn gem installs")
	burn_world.start(1)
	var burn_index: int = burn_world.offers.find_custom(func(item): return int(item.id) == 1)
	if burn_index >= 0:
		burn_world.submit("choose", {"index": burn_index})
	var burn_owner: Dictionary = burn_world.units[burn_world.heroes[0]]
	var burn_target = burn_world.factory.create("enemy", 101, burn_owner.pos + Vector2(0, -200), 2)
	burn_target.shield = 50.0
	var burn_hp = U.hp(burn_target)
	burn_world.damage.true_damage(burn_owner, burn_target, 20.0)
	test.assert_equal(U.hp(burn_target), burn_hp, "true percentage damage is absorbed by shield")

	var statue_world = Session.new(catalog)
	var statue_snapshot: Dictionary = statue_world.equipment.snapshot()
	var statue_strength = _item(statue_snapshot, catalog, "雕像强化", "普通")
	var statue_guard = _item(statue_snapshot, catalog, "防护强化", "普通")
	statue_world.submit("gem_inlay", {"part": _part(statue_snapshot, catalog, statue_strength), "item": statue_strength})
	statue_world.submit("gem_inlay", {"part": _part(statue_snapshot, catalog, statue_guard), "item": statue_guard})
	statue_world.start(1)
	test.assert_equal(statue_world.wall_max, 4400.0, "statue strength raises maximum life")
	statue_world.damage.hit_wall(100.0)
	statue_world.damage.hit_wall(100.0)
	test.assert_equal(statue_world.wall_hp, 4400.0, "statue protection blocks first two direct hits")
	statue_world.damage.hit_wall(100.0)
	test.assert_equal(statue_world.wall_hp, 4305.0, "statue damage reduction applies after protection")
	var punishment_world = Session.new(catalog)
	var punishment_snapshot: Dictionary = punishment_world.equipment.snapshot()
	var punishment_item = _item(punishment_snapshot, catalog, "天罚", "传说")
	punishment_world.submit("gem_inlay", {"part": _part(punishment_snapshot, catalog, punishment_item), "item": punishment_item})
	punishment_world.start(1)
	var punishment_index: int = punishment_world.offers.find_custom(func(item): return int(item.id) == 1)
	if punishment_index >= 0: punishment_world.submit("choose", {"index": punishment_index})
	var near = punishment_world.factory.create("enemy", 101, Statue.BODY_CENTER + Vector2(100, 0), 2)
	var far = punishment_world.factory.create("enemy", 101, Statue.BODY_CENTER + Vector2(351, 0), 2)
	punishment_world.damage.hit_wall(punishment_world.wall_max * 0.5 + 1.0)
	test.assert_true(punishment_world.statuses.has_status(near, 4), "statue punishment stuns enemies inside the 300-unit radius")
	test.assert_true(not punishment_world.statuses.has_status(far, 4), "statue punishment excludes enemies outside the radius")
	test.assert_true(punishment_world.statuses.prevents(near, "move") and punishment_world.statuses.prevents(near, "attack") and punishment_world.statuses.prevents(near, "skill"), "stun prevents movement, attack and skill")
	var has_tianfa_visual := false
	for visual: Dictionary in punishment_world.visuals:
		if visual.get("kind", "") == "effect" and visual.get("res", "") == "bulletStatus:stun3":
			has_tianfa_visual = true
	test.assert_true(has_tianfa_visual, "statue punishment emits the trigger effect cue")
	if has_tianfa_visual:
		var trigger_visual: Dictionary = punishment_world.visuals.filter(func(visual): return visual.get("kind", "") == "effect" and visual.get("res", "") == "bulletStatus:stun3")[0]
		test.assert_true(absf(float(trigger_visual.scale) - 0.18) < 0.001, "statue punishment trigger cue uses the readable star-ring scale")
		test.assert_equal(trigger_visual.get("visual_tint", ""), "#ffd35a", "statue punishment trigger cue uses a visible gold tint")
	var punishment_view: Dictionary = punishment_world.snapshot()
	var near_view: Dictionary = {}
	for actor: Dictionary in punishment_view.actors:
		if int(actor.get("id", -1)) == int(near.id):
			near_view = actor
			break
	var has_stun_visual := false
	for effect: Dictionary in near_view.get("status_effects", []):
		if effect.get("res", "") == "bulletStatus:stun3":
			has_stun_visual = true
	test.assert_true(has_stun_visual, "stunned targets expose the stun visual effect")
	if has_stun_visual:
		var stun_effect: Dictionary = near_view.status_effects.filter(func(effect): return effect.get("res", "") == "bulletStatus:stun3")[0]
		test.assert_true(absf(float(stun_effect.scale.x) - 0.18) < 0.001 and absf(float(stun_effect.scale.y) - 0.18) < 0.001, "stun visual uses the readable star-ring scale")
	world.dispose()
	burn_world.dispose()
	statue_world.dispose()
	punishment_world.dispose()

func _item(snapshot: Dictionary, catalog, name: String, quality: String) -> String:
	for item in snapshot.gem_defs:
		var definition: Dictionary = catalog.record("gems", int(snapshot.gem_defs[item]))
		if definition.get("name", "") == name and definition.get("quality", "") == quality:
			return item
	return ""

func _part(snapshot: Dictionary, catalog, item: String) -> String:
	var definition: Dictionary = catalog.record("gems", int(snapshot.gem_defs[item]))
	return str(definition.parts[0])
