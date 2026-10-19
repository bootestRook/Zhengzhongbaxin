class_name DefenseChoices
extends RefCounted

var w
var options: Dictionary
var quality_weights: Array
var hero_weights: Dictionary = {}
var last_heroes: Array = []

func _init(world) -> void:
	w = world
	options = w.catalog.records("options")
	quality_weights = w.catalog.records("loot").quality_weights

func reset() -> void:
	hero_weights.clear()
	last_heroes.clear()

func advance() -> void:
	if w.stage >= w.rules.max_level - 1:
		return
	var threshold = 0
	for i in range(w.stage + 1):
		threshold += int(w.level.waves[i].count)
	if w.kills < threshold:
		return
	w.stage += 1
	offer("upgrade")

func eligible(o: Dictionary, owner: Dictionary) -> bool:
	if not owner.is_empty() and not w.rules.unlocked_heroes.has(owner.template):
		return false
	if int(o.get("isNew", 0)) < 0 or not o.get("numTable", []).is_empty():
		return false
	var count = int(w.selected.get(str(o.id), 0))
	if count >= int(o.get("options_num", 0)):
		return false
	if not owner.is_empty() and not o.get("type", []).has(owner.template):
		return false
	var group = int(o.get("isNew", 0))
	if group > 1:
		var used = 0
		for id in w.selected:
			var prior: Dictionary = options.get(str(id), {})
			if int(prior.get("isNew", 0)) == group and prior.get("type", []) == o.get("type", []):
				used += int(w.selected[id])
		if used >= absi(group):
			return false
	for condition in o.get("premise1", []):
		if not meets(condition):
			return false
	var alternatives: Array = o.get("premise2", [])
	if not alternatives.is_empty():
		var any_met = false
		for condition in alternatives:
			any_met = any_met or meets(condition)
		if not any_met:
			return false
	return true

func meets(condition: Array) -> bool:
	if condition.size() < 2:
		return false
	var count = int(w.selected.get(str(int(condition[0])), 0))
	return count >= int(condition[1]) if float(condition[1]) >= 0 else count < -int(condition[1])

func hero_pool() -> Array:
	if w.heroes.size() >= w.rules.hero_limit:
		return []
	var pool: Array = []
	var previous: Array = []
	for id in w.catalog.available_heroes():
		var already = false
		for owned in w.heroes:
			already = already or w.units[owned].template == id
		if already:
			continue
		var h = w.catalog.record("heroes", id)
		var titles: Array = []
		for option_id in h.initial_options:
			var skill = w.catalog.record("options", int(option_id))
			titles.append(skill.title)
		var item = {"kind": "hero", "id": id, "owner": 0, "title": h.name, "description": "招募%s" % h.name, "subtitle": " / ".join(titles), "res": h.res, "weight": h.get("recruit_weight", 5000)}
		if last_heroes.has(id):
			previous.append(item)
		else:
			pool.append(item)
	if pool.size() < 3:
		pool.append_array(previous)
	return pool

func take_hero(pool: Array, rng) -> Dictionary:
	var index = -1
	for item in pool:
		if item.weight != pool[0].weight:
			index = pool.find(rng.choose_weighted(pool))
			break
	if index < 0:
		index = rng.next_int(pool.size())
	var item: Dictionary = pool[index]
	pool.remove_at(index)
	last_heroes.append(item.id)
	return item

func offer(kind: String, refreshing: bool = false) -> void:
	assert(kind in ["hero", "upgrade", "bonus"], "unsupported choice kind")
	w.choice_kind = kind
	w.offers.clear()
	if not refreshing:
		last_heroes.clear()
	var rng = w.rng.stream("defense.choice")
	var pool: Array = hero_pool() if kind in ["hero", "upgrade"] else []
	last_heroes.clear()
	if kind == "hero":
		for _i in range(mini(3, pool.size())):
			w.offers.append(take_hero(pool, rng))
	else:
		var excluded: Array = []
		var owner = int(w.pending[0]) if kind == "bonus" else 0
		for _i in range(3):
			var item: Dictionary = {}
			if not pool.is_empty() and rng.next_int(10000) < w.rules.recruit_chance:
				item = take_hero(pool, rng)
			else:
				item = roll_upgrade(rng, excluded, owner)
				if item.is_empty() and not pool.is_empty():
					item = take_hero(pool, rng)
			if item.is_empty():
				break
			w.offers.append(item)
			if item.kind == "upgrade":
				excluded.append(item.id)
	if w.offers.is_empty():
		w.phase = "playing"
		return
	w.phase = "choice"

func upgrade_pool(excluded: Array = [], only_owner: int = 0) -> Array:
	var result: Array = []
	for option: Dictionary in options.values():
		if excluded.has(int(option.id)) or int(option.get("isNew", 0)) < 0:
			continue
		for owner in w.heroes:
			if (only_owner == 0 or owner == only_owner) and eligible(option, w.units[owner]):
				result.append(card(option, owner))
	return result

func roll_upgrade(rng, excluded: Array = [], only_owner: int = 0) -> Dictionary:
	var candidates = upgrade_pool(excluded, only_owner)
	if candidates.is_empty():
		return {}
	if only_owner > 0:
		return pick(candidates, rng)
	var owners: Array = []
	for owner in w.heroes:
		owners.append({"id": owner, "weight": hero_weights.get(owner, 5)})
	var selected: Dictionary = rng.choose_weighted(owners)
	var owned: Array = []
	for item in candidates:
		if not selected.is_empty() and item.owner == selected.id:
			var option: Dictionary = options[str(item.id)]
			var parts = str(option.icon).split(":")
			owned.append({"item": item, "weight": option.get("draw_weight", quality_weights[int(parts[1]) - 1])})
	var chosen: Dictionary = rng.choose_weighted(owned)
	return chosen.item if not chosen.is_empty() else pick(candidates, rng)

func pick(candidates: Array, rng) -> Dictionary:
	# Other heroes keep their uniform bonus/replacement draw. Explicit libraries
	# preserve the same owner mass, then use their own weights within that owner.
	var explicit = false
	for item in candidates:
		explicit = explicit or options[str(item.id)].has("draw_weight")
	if not explicit:
		return candidates[rng.next_int(candidates.size())]
	var owners: Dictionary = {}
	for item in candidates:
		if not owners.has(item.owner):
			owners[item.owner] = {"id": item.owner, "weight": 0, "items": []}
		owners[item.owner].weight += 1
		owners[item.owner].items.append(item)
	var owner: Dictionary = owners.values()[0] if owners.size() == 1 else rng.choose_weighted(owners.values())
	var rows: Array = []
	for item in owner.items:
		rows.append({"item": item, "weight": options[str(item.id)].get("draw_weight", 1)})
	return rng.choose_weighted(rows).item

func balance(owner: int) -> void:
	for id in w.heroes:
		hero_weights[id] = maxi(0, int(hero_weights.get(id, 5)) - 1) if id == owner else int(hero_weights.get(id, 5)) + 1

func card(o: Dictionary, owner: int) -> Dictionary:
	return {"kind": "upgrade", "id": int(o.id), "owner": owner, "title": o.title, "description": o.description,
		"subtitle": w.units[owner].name, "res": w.units[owner].res}

func choose(index: int) -> String:
	if w.phase != "choice" or w.paused or index < 0 or index >= w.offers.size():
		return "当前无法选择"
	var item: Dictionary = w.offers[index]
	var previous_kind: String = w.choice_kind
	if item.kind == "hero":
		if not w.catalog.available_heroes().has(int(item.id)):
			return "该英雄尚未解锁"
		if not w.factory.add_hero(int(item.id)):
			return "无法加入英雄"
	else:
		var owner: Dictionary = w.units.get(item.owner, {})
		if owner.is_empty() or not eligible(options.get(str(item.id), {}), owner):
			return "当前词条不可选择"
		w.upgrades.apply(w.units[item.owner], int(item.id))
		balance(item.owner)
	w.history.append({"stage": w.stage, "kind": item.kind if previous_kind in ["hero", "upgrade"] else previous_kind, "id": item.id, "owner": item.owner})
	w.events.append({"type": "choice_made", "title": item.title})
	w.offers.clear()
	w.phase = "playing"
	if previous_kind == "hero" and w.extra_choices_left > 0:
		w.extra_choices_left -= 1
		offer("upgrade")
		return ""
	if previous_kind == "bonus":
		w.pending.pop_front()
	if not w.pending.is_empty():
		offer("bonus")
	return ""

