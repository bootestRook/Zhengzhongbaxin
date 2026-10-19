extends RefCounted

const Session = preload("res://src/features/defense/domain/lab/lab_session.gd")
const Config = preload("res://src/features/defense/domain/lab/lab_config.gd")
const Units = preload("res://src/features/defense/domain/lab/lab_units.gd")
const Operations = preload("res://src/features/defense/domain/lab/lab_operations.gd")
const Inspector = preload("res://src/features/defense/domain/lab/lab_inspector.gd")
var catalog
var world
var recipe: Dictionary
var origin: Dictionary
var journal: Array = []
var journal_full: bool = false
var last_created: Array = []
var selected_id: int = 0
var audio_events: Array = []
var operations

func _init(definitions) -> void:
	catalog = definitions
	operations = Operations.new(self)
	load_config(Config.empty())

func load_config(value: Variant) -> String:
	var error = Config.validate(value, catalog)
	if not error.is_empty():
		return error
	value = Config.normalize(value)
	var candidate = Session.new(catalog)
	candidate.level_id = int(value.level)
	error = candidate.start(int(value.seed))
	candidate.phase = "playing"
	candidate.offers.clear()
	candidate.spawn_wave = int(value.wave)
	candidate.settings = value.settings.duplicate(true)
	for spec in value.units:
		if error.is_empty():
			error = Units.spawn(candidate, spec, value.legal_terms)
	if not error.is_empty():
		candidate.dispose()
		return error
	if value.settings.spawn or value.settings.progression:
		candidate.spawn_wave = int(value.wave) - 1
		candidate.spawn.begin_wave()
	candidate.paused = true
	if world != null:
		world.dispose()
	world = candidate
	recipe = value.duplicate(true)
	origin = recipe.duplicate(true)
	journal.clear()
	journal_full = false
	audio_events.clear()
	selected_id = int(world.heroes[0]) if not world.heroes.is_empty() else (int(world.units.keys()[0]) if not world.units.is_empty() else 0)
	last_created.clear()
	return ""

func submit(action: String, payload: Dictionary = {}) -> String:
	var before = world
	var error: String = operations.submit(action, payload)
	if error.is_empty() and before == world:
		remember(action, payload)
	return error

func remember(action: String, payload: Dictionary) -> void:
	if action == "advance" and not journal.is_empty() and journal.back().action == "advance":
		journal.back().payload.ticks += int(payload.ticks)
	elif journal.size() < 10000:
		journal.append({"action": action, "payload": payload.duplicate(true), "at_ms": world.time_ms})
	else:
		journal_full = true

func advance(ticks: int) -> void:
	var was_paused: bool = world.paused
	world.paused = false
	for _index in range(ticks):
		if world.phase != "playing":
			break
		var began = Time.get_ticks_usec()
		world.step()
		world.step_us = Time.get_ticks_usec() - began
		world.peak_step_us = maxi(world.peak_step_us, world.step_us)
		for replacement in world.replacements.duplicate():
			if replacement.at <= world.time_ms:
				Units.spawn(world, replacement.spec, recipe.legal_terms)
				world.replacements.erase(replacement)
		var batch: Array = world.drain_events()
		audio_events.append_array(batch)
		if audio_events.size() > 200:
			audio_events = audio_events.slice(-200)
	world.paused = was_paused

func step_to(event_type: String, limit: int) -> String:
	var previous: int = world.trace_sequence
	for _i in range(limit):
		advance(1)
		remember("advance", {"ticks": 1})
		if world.trace.any(func(e): return e.sequence > previous and e.type == event_type and (event_type != "damage" or e.get("actual", 0) > 0)):
			return ""
		if world.phase != "playing":
			break
	return "在限定步数内未发生目标事件"

func document() -> Dictionary:
	return {"format": "defense-battle-lab", "version": 1, "config": origin.duplicate(true), "commands": journal.duplicate(true),
		"source_hashes": catalog._data.source_hashes.duplicate(true), "truncated": journal_full}

func replay(value: Variant) -> String:
	if not value is Dictionary or value.get("format") != "defense-battle-lab" or value.get("version") != 1 or not value.get("commands") is Array:
		return "无效测试文档"
	if value.get("truncated", false):
		return "操作记录已截断，无法完整复现"
	if value.get("source_hashes", {}) != catalog._data.source_hashes:
		return "源表或资源定义已变化；请使用仅加载配置，重新验证结果"
	var trial = get_script().new(catalog)
	var error: String = trial.load_config(value.get("config"))
	for command in value.commands:
		if not error.is_empty():
			break
		if not command is Dictionary or not command.get("action") is String or not command.get("payload") is Dictionary:
			error = "无效重放操作"
			break
		if command.action == "advance":
			var count = command.payload.get("ticks", 0)
			if not Config.finite_number(count, 1, 1000000) or float(count) != floor(float(count)):
				error = "重放步数超出范围"
				break
			while count > 0:
				var portion = mini(62500, int(count))
				error = trial.submit("advance", {"ticks": portion})
				count -= portion
		else:
			error = trial.submit(command.action, command.payload)
	if error.is_empty():
		world.dispose()
		world = trial.world
		trial.world = null
		recipe = trial.recipe
		origin = trial.origin
		journal = trial.journal
		journal_full = trial.journal_full
		selected_id = trial.selected_id
		audio_events.clear()
	trial.dispose()
	return error

func inspect(id: int = -1) -> Dictionary:
	return Inspector.unit_snapshot(world, selected_id if id < 0 else id)

func state() -> Dictionary:
	return Inspector.state(world)

func dispose() -> void:
	if world != null:
		world.dispose()
		world = null
	operations.lab = null
