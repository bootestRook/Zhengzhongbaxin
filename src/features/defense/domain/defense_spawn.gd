class_name DefenseSpawn
extends RefCounted

var w
var wave: Dictionary = {}
var policy: Dictionary
var entry_states: Array = []
var wave_started: Array = []
var wave_left: int = 0
var normal_total: int = 0

func _init(world) -> void:
	w = world
	policy = w.catalog.spawn_policy()

func reset() -> void:
	wave.clear()
	entry_states.clear()
	wave_started.clear()
	wave_left = 0
	normal_total = 0
	for _wave in w.level.waves:
		wave_started.append(false)
		for entry in _wave.entries:
			entry_states.append({
				"entry": entry.duplicate(true), "target": -1, "spawned": 0, "cleared": 0,
				"next_at": int(entry.trigger_time_ms), "started": false
			})

func tick() -> void:
	_update_started_waves()
	for state: Dictionary in entry_states:
		if w.time_ms < int(state.next_at):
			continue
		if int(state.target) < 0:
			state.target = _target_count(state.entry)
			state.started = true
		if int(state.spawned) >= int(state.target):
			continue
		var amount = mini(int(state.entry.batch_count), int(state.target) - int(state.spawned))
		for _i in range(amount):
			spawn_entry(state.entry, int(state.spawned))
		state.spawned += amount
		state.next_at = maxi(w.time_ms + 1, int(state.next_at) + maxi(1, int(state.entry.interval_ms)))
	if w.spawn_wave > 0 and w.spawn_wave <= w.level.waves.size():
		wave_left = 0
		for state: Dictionary in entry_states:
			if int(state.entry.wave) == w.spawn_wave:
				wave_left += maxi(0, int(state.target) - int(state.spawned))

func _update_started_waves() -> void:
	for index in range(w.level.waves.size()):
		if wave_started[index]:
			continue
		var due := false
		for entry in w.level.waves[index].entries:
			if w.time_ms >= int(entry.trigger_time_ms):
				due = true
				break
		if not due:
			continue
		wave_started[index] = true
		w.spawn_wave = maxi(w.spawn_wave, index + 1)
		wave = w.level.waves[index]
		w.events.append({"type": "wave_started", "wave": index + 1})
		w.gems.on_wave_started()
		for id in w.heroes:
			w.skills.trigger(w.units[id], "wave", {})

func _target_count(entry: Dictionary) -> int:
	var base := int(entry.count)
	var fluctuation := float(entry.fluctuation)
	if fluctuation <= 0:
		return base
	var sample := float(w.rng.stream("defense.spawn").next_int(1000001)) / 1000000.0
	return maxi(1, ceili(float(base) * (1.0 - fluctuation + sample * fluctuation * 2.0)))

func spawn_entry(entry: Dictionary, instance_offset: int) -> void:
	var kind := str(entry.kind)
	var position := _position(int(entry.distribution))
	var unit = w.factory.create(kind_to_unit_kind(kind), int(entry.monster_id), position, 2, 0, entry)
	if unit.is_empty():
		return
	if kind == "normal":
		normal_total += 1
	unit.wave = int(entry.wave)
	if kind in ["elite", "boss"]:
		unit.encounter_wave = int(entry.wave)
		unit.encounter_id = "%d:%d:%d" % [w.level_id, int(entry.id), instance_offset]
		unit.encounter_row_id = int(entry.id)
		w.events.append({"type": "encounter_spawned", "name": unit.name, "kind": kind})
		w.cue("encounter", Vector2(800, 380), {"text": "%s%s 来袭" % ["精英·" if kind == "elite" else "首领·", unit.name], "duration": 2400})

func spawn_encounter(entry: Dictionary) -> void:
	var position := _position(int(entry.get("distribution", 4)))
	var unit = w.factory.create_encounter(entry, position)
	if not unit.is_empty():
		w.events.append({"type": "encounter_spawned", "name": unit.name, "kind": entry.kind})

func kind_to_unit_kind(kind: String) -> String:
	return "enemy" if kind == "normal" else kind

func _position(distribution: int) -> Vector2:
	if distribution == 4:
		return Vector2(w.combat.world.center[0], 10)
	var x = 350 + w.rng.stream("defense.spawn").next_int(901)
	return Vector2(x, 10)

func on_encounter_defeat(unit: Dictionary) -> void:
	var encounter_id := str(unit.get("encounter_id", ""))
	if encounter_id.is_empty() or w.encounters_cleared.has(encounter_id):
		return
	w.encounters_cleared.append(encounter_id)
	for state: Dictionary in entry_states:
		if int(state.entry.id) == int(unit.get("encounter_row_id", -1)):
			state.cleared += 1
			break

func all_spawned() -> bool:
	for state: Dictionary in entry_states:
		if int(state.target) < 0 or int(state.spawned) < int(state.target):
			return false
	return true

func encounters_complete() -> bool:
	for state: Dictionary in entry_states:
		if str(state.entry.kind) in ["elite", "boss"]:
			if int(state.target) < 0 or int(state.spawned) < int(state.target) or int(state.cleared) < int(state.target):
				return false
	return true

func cleared_rows() -> Array:
	var result: Array = []
	for state: Dictionary in entry_states:
		if str(state.entry.kind) in ["elite", "boss"] and int(state.cleared) >= int(state.target):
			result.append(int(state.entry.id))
	return result

func has_live_enemies() -> bool:
	for unit: Dictionary in w.units.values():
		if unit.side == 2 and not unit.dead:
			return true
	return false

func is_complete() -> bool:
	return all_spawned() and encounters_complete() and not has_live_enemies()

func begin_wave() -> void:
	var index := maxi(0, w.spawn_wave)
	if index < w.level.waves.size():
		w.spawn_wave = index + 1
		wave = w.level.waves[index]
		wave_started[index] = true
		for state: Dictionary in entry_states:
			if int(state.entry.wave) == w.spawn_wave:
				state.next_at = mini(int(state.next_at), w.time_ms)

func can_advance() -> bool:
	return not has_live_enemies()
