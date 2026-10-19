extends RefCounted

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Fixture = preload("res://tests/test_defense_hero_roster.gd")
const Terms = preload("res://tests/test_defense_warrior_terms.gd")
const Area = preload("res://src/features/defense/domain/defense_area.gd")

func marked(w, id: int) -> bool:
	return w.snapshot().actors.filter(func(actor): return actor.id == id)[0].taunted

func run(test) -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	var fixture = Fixture.new()
	for expanded in [false, true]:
		var w = fixture.world(catalog, 4)
		var hero: Dictionary = w.units[w.heroes[0]]
		if expanded:
			for term in [103, 104]:
				Terms.new().choose(w, term)
		var near = fixture.enemy(w, hero.pos + Vector2(0, -150))
		var taunt_radius = Area.radius(400.0, 30.0 if expanded else 0.0)
		var edge = fixture.enemy(w, hero.pos + Vector2(450 if expanded else 350, 0))
		var outside = fixture.enemy(w, hero.pos + Vector2(700, 0))
		outside.pos.x = hero.pos.x + taunt_radius + outside.body_radius + 1
		w.visuals.clear()
		test.assert_true(w.skills.ready_action(hero), "real shield action starts before any taunt feedback")
		fixture.spells(w, 1200)
		var captions: Array = w.snapshot().visuals.filter(func(effect): return effect.kind == "skill_text")
		test.assert_equal(captions.size(), 1, "area taunt emits one caster caption for multiple enemies")
		if not captions.is_empty():
			test.assert_equal(captions[0].text, "嘲讽", "caster caption names the actual action in Chinese")
			test.assert_equal(captions[0].source_id, hero.id, "caption belongs to the caster")
			hero.pos += Vector2(20, 0)
			test.assert_equal(w.snapshot().visuals.filter(func(effect): return effect.kind == "skill_text")[0].pos, hero.pos, "caption follows the moving caster")
		test.assert_true(marked(w, near.id) and marked(w, edge.id), "every actually taunted enemy receives a marker")
		test.assert_true(not marked(w, outside.id), "outside enemy receives no false marker")
		test.assert_true(not marked(w, hero.id), "caster is not marked as a taunted enemy")
		var start: int = near.taunt_started
		var paused_at: int = w.time_ms
		w.paused = true
		w.step()
		test.assert_equal(near.taunt_started, start, "pause preserves the marker animation origin")
		test.assert_equal(w.time_ms, paused_at, "pause freezes the real battle clock")
		w.paused = false
		hero.hidden_until = w.time_ms + 100
		test.assert_true(not marked(w, near.id), "hidden caster releases the same marker as the targeting rule")
		hero.hidden_until = 0
		near.dead = true
		test.assert_true(not marked(w, near.id), "dead target has no lingering marker")
		near.dead = false
		hero.dead = true
		test.assert_true(not marked(w, edge.id), "caster death immediately removes affected enemy markers")
		hero.dead = false
		var expiry: int = near.taunt_until
		w.time_ms = expiry - 1
		test.assert_true(marked(w, edge.id), "extended or base marker remains until the actual expiry")
		w.time_ms = expiry
		test.assert_true(not marked(w, near.id) and not marked(w, edge.id), "all markers disappear at the actual taunt expiry")
		w.step()
		test.assert_true(not w.snapshot().visuals.any(func(effect): return effect.kind == "skill_text"), "expired caster captions are removed by the production battle tick")
		w.units.erase(hero.id)
		test.assert_true(not marked(w, near.id), "removed caster cannot leave a marker or invalid snapshot access")
		w.dispose()
