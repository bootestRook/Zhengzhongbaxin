extends "res://src/features/defense/domain/defense_session.gd"

const LabDamage = preload("res://src/features/defense/domain/lab/lab_damage.gd")
const LabAI = preload("res://src/features/defense/domain/lab/lab_ai.gd")
const LabSkills = preload("res://src/features/defense/domain/lab/lab_skills.gd")
const LabStatus = preload("res://src/features/defense/domain/lab/lab_status.gd")
var settings: Dictionary = {"spawn": false, "progression": false, "respawn": false}
var trace: Array = []
var trace_sequence: int = 0
var trace_dropped: int = 0
var active_skill: int = 0
var step_us: int = 0
var peak_step_us: int = 0
var replacements: Array = []

func _init(definitions) -> void:
	super(definitions)
	damage.mitigation.w = null
	damage.traits.w = null
	damage.protection.w = null
	for module in [damage, ai, statuses, skills, skills.actions, skills.fire, skills.fireball, skills.thorns, skills.ice, skills.assassination]:
		module.w = null
	damage = LabDamage.new(self)
	ai = LabAI.new(self)
	skills = LabSkills.new(self)
	statuses = LabStatus.new(self)

func advance_environment() -> void:
	if settings.spawn or settings.progression:
		super.advance_environment()

func advance_progression() -> void:
	if settings.progression:
		super.advance_progression()
	else:
		loot.reset()
		pending.clear()

func record(kind: String, data: Dictionary = {}) -> void:
	trace_sequence += 1
	var item = data.duplicate(true)
	item.merge({"sequence": trace_sequence, "time_ms": time_ms, "type": kind}, true)
	trace.append(item)
	if trace.size() > 2000:
		trace.pop_front()
		trace_dropped += 1

func allowed(unit: Dictionary, action: String) -> bool:
	return bool(unit.get("lab_actions", {}).get(action, true))

func drain_events() -> Array:
	var batch = super.drain_events()
	for item in batch:
		record(str(item.type), item)
	return batch
