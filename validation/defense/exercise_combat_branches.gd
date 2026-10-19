extends SceneTree

const Catalog = preload("res://src/features/defense/domain/defense_catalog.gd")
const Session = preload("res://src/features/defense/domain/defense_session.gd")
var options: Dictionary
var rows: Array = []

func _initialize() -> void:
	var catalog = Catalog.new()
	catalog.load_default()
	options = catalog.records("options")
	for hid in catalog.available_heroes():
		for option: Dictionary in options.values():
			if option.get("type", []) != [hid] or int(option.get("options_num", 0)) <= 0:
				continue
			var w = Session.new(catalog)
			w.start(31)
			w.factory.add_hero(hid)
			var hero: Dictionary = w.units[w.heroes[0]]
			var reachable = acquire(w, hero, option.id, [])
			if not w.pending.is_empty():
				w.choices.offer("bonus")
				w.submit("choose", {"index": 0})
			w.phase = "playing"
			w.spawn_wave = 20
			w.stage = 19
			w.wall_hp = 100000
			for i in range(6):
				var enemy = w.factory.create("enemy", 101, hero.pos + Vector2(-120 + i * 50, -100 - i * 15), 2)
				enemy.core.attributes.set_value("1", 100000)
				enemy.core.attributes.set_value("hp", 100000)
				enemy.core.attributes.set_value("4", 1)
			for tick in range(1500):
				w.step()
				w.drain_events()
			var summons = 0
			for u in w.units.values():
				if u.owner == hero.id:
					summons += 1
			rows.append({"hero": hid, "option": option.id, "title": option.title, "prerequisites_satisfied": reachable,
				"damage": hero.stats.damage, "heal": hero.stats.heal, "summons": summons,
				"learned_skills": hero.skills.keys(), "diagnostics": w.diagnostics.duplicate(), "phase": w.phase})
			w.dispose()
		print("[OK] hero %d branches exercised" % hid)
	var file = FileAccess.open("res://validation/defense/combat_branch_exercise.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture": "24s isolated branch with durable enemy targets; not original-client equivalence proof", "rows": rows}, "\t") + "\n")
	print("[OK] branch exercise: %d hero option scenarios" % rows.size())
	quit()

func acquire(w, hero: Dictionary, id: int, path: Array) -> bool:
	if path.has(id) or not options.has(str(id)):
		return false
	var option: Dictionary = options[str(id)]
	if int(w.selected.get(str(id), 0)) > 0:
		return true
	var next = path.duplicate()
	next.append(id)
	for condition in option.get("premise1", []):
		if int(condition[1]) > 0:
			for i in range(int(condition[1])):
				if not acquire(w, hero, int(condition[0]), next):
					return false
	var alternatives: Array = option.get("premise2", [])
	if not alternatives.is_empty():
		var met = false
		for condition in alternatives:
			if w.choices.meets(condition):
				met = true
		if not met:
			for condition in alternatives:
				if int(condition[1]) > 0 and acquire(w, hero, int(condition[0]), next):
					break
	if not w.choices.eligible(option, hero):
		return false
	w.upgrades.apply(hero, id)
	return true
