class_name DefenseSession
extends RefCounted
const Rng = preload("res://src/foundation/rng_set.gd"); const Core = preload("res://src/runtime/core/core_state.gd")
const Units = preload("res://src/features/defense/domain/defense_units.gd"); const Spawn = preload("res://src/features/defense/domain/defense_spawn.gd")
const Choices = preload("res://src/features/defense/domain/defense_choices.gd"); const AI = preload("res://src/features/defense/domain/defense_ai.gd")
const Damage = preload("res://src/features/defense/domain/defense_damage.gd"); const Skills = preload("res://src/features/defense/domain/defense_skills.gd")
const Projectiles = preload("res://src/features/defense/domain/defense_projectiles.gd"); const Status = preload("res://src/features/defense/domain/defense_status.gd")
const Upgrades = preload("res://src/features/defense/domain/defense_upgrades.gd"); const Guard = preload("res://src/features/defense/domain/defense_guard.gd")
const Targets = preload("res://src/features/defense/domain/defense_targets.gd"); const Snapshot = preload("res://src/features/defense/domain/defense_snapshot.gd")
const Passives = preload("res://src/features/defense/domain/defense_passives.gd"); const Space = preload("res://src/features/defense/domain/defense_space.gd")
const Navigation = preload("res://src/features/defense/domain/defense_navigation.gd"); const Result = preload("res://src/features/defense/domain/defense_result.gd")
const Loot = preload("res://src/features/defense/domain/defense_loot.gd"); const Gems = preload("res://src/features/defense/domain/defense_gems.gd")
var catalog; var rng; var core; var factory; var spawn; var choices
var ai; var damage; var skills; var projectiles; var statuses; var upgrades
var targets; var guard; var passives; var space; var navigation; var loot; var gems
var combat: Dictionary
var rules: Dictionary
var attribute_defs: Dictionary
var units: Dictionary = {}
var heroes: Array = []
var missiles: Array = []
var visuals: Array = []
var events: Array = []
var offers: Array = []
var selected: Dictionary = {}
var history: Array = []
var pending: Array = []
var level: Dictionary = {}
var level_id: int = 1
var phase: String = "home"
var choice_kind: String = ""
var paused: bool = false
var speed: int = 1
var muted: bool = false
var next_id: int = 1
var time_ms: int = 0
var spawn_wave: int = 0
var stage: int = 0
var kills: int = 0
var encounters_cleared: Array = []
var wall_hp: float = 3900
var wall_max: float = 3900
var statue_damage_reduction: float = 0.0
var statue_protection_left: int = 0
var statue_immune_until: int = 0
var statue_grace_used: bool = false
var deaths: int = 0
var won: bool = false
var result_level: int = 0
var result: Dictionary = {}
var best_progress: Dictionary = {}
var equipment
var refresh_left: int = 0
var seed: int = 0
var diagnostics: Dictionary = {}
var extra_choices_left: int = 0
func _init(definitions) -> void:
	catalog = definitions
	combat = catalog.combat()
	rules = catalog.rules()
	attribute_defs = catalog.records("attributes")
	core = Core.new()
	rng = Rng.new(seed)
	factory = Units.new(self)
	spawn = Spawn.new(self)
	choices = Choices.new(self)
	loot = Loot.new(self)
	equipment = preload("res://src/features/defense/domain/defense_equipment.gd").new(catalog)
	gems = Gems.new(self)
	ai = AI.new(self)
	damage = Damage.new(self)
	skills = Skills.new(self)
	projectiles = Projectiles.new(self)
	statuses = Status.new(self)
	upgrades = Upgrades.new(self)
	targets = Targets.new(self)
	guard = Guard.new(self)
	passives = Passives.new(self)
	space = Space.new(self)
	navigation = Navigation.new(self)
func submit(intent: String, payload: Dictionary = {}) -> String:
	match intent:
		"equipment_replace", "gem_inlay", "gem_replace", "gem_remove":
			return equipment.submit(intent, payload) if phase == "home" else "请先返回雕像页"
		"select_level":
			if phase != "home":
				return "当前对局尚未结束"
			var next = int(payload.get("level", level_id))
			if catalog.record("levels", next).is_empty():
				return "无效关卡"
			level_id = next
		"start":
			if phase != "home" and phase != "result":
				return "当前对局尚未结束"
			if not payload.has("seed") or not payload.seed is int:
				return "缺少对局种子"
			return start(payload.seed)
		"choose":
			var error: String = choices.choose(int(payload.get("index", -1)))
			loot.advance()
			return error
		"refresh":
			if phase != "choice" or paused or refresh_left <= 0:
				return "本局刷新次数已用完" if refresh_left <= 0 else "当前无法刷新"
			refresh_left -= 1
			choices.offer(choice_kind, true)
		"pause":
			if phase in ["playing", "choice"]:
				paused = not paused
		"speed":
			speed = 2 if speed == 1 else (3 if speed == 2 else 1)
		"sound":
			muted = not muted
		"reward_close":
			return loot.close(int(payload.get("id", -1)))
		"quit":
			if phase in ["playing", "choice", "reward"]:
				finish(false)
		"home":
			if phase != "result":
				return "请先结束当前对局"
			phase = "home"
			paused = false
			units.clear()
			missiles.clear()
			visuals.clear()
			core = Core.new()
		_:
			return "未知操作"
	return ""
func start(run_seed: int) -> String:
	if run_seed <= 0 or run_seed > 0x7fffffff:
		return "无效对局种子"
	seed = run_seed
	rng = Rng.new(seed)
	core = Core.new()
	units.clear()
	heroes.clear()
	missiles.clear()
	visuals.clear()
	loot.reset()
	choices.reset()
	events.clear()
	offers.clear()
	selected.clear()
	history.clear()
	pending.clear()
	diagnostics.clear()
	space.rebuild()
	level = catalog.record("levels", level_id)
	gems.reset()
	wall_max = float(catalog.baseline().wall_hp) + gems.statue_max_bonus()
	wall_hp = wall_max
	statue_damage_reduction = gems._sum("statue_strength", "damage_reduction")
	statue_protection_left = gems.statue_protection_left
	statue_immune_until = 0
	statue_grace_used = false
	next_id = 1
	time_ms = 0
	spawn_wave = 0
	stage = 0
	refresh_left = 2
	extra_choices_left = gems.extra_choice_count()
	kills = 0
	encounters_cleared.clear()
	deaths = 0
	paused = false
	won = false
	result = {}
	spawn.reset()
	skills.reset()
	choices.offer("hero")
	return ""
func step() -> void:
	if phase != "playing" or paused:
		return
	time_ms += 16
	core.advance_tick()
	visuals = visuals.filter(func(v): return time_ms < v.expires)
	skills.thorns.tick()
	gems.tick()
	factory.lifecycle()
	advance_environment()
	statuses.tick()
	space.rebuild()
	navigation.rebuild()
	ai.tick()
	skills.tick()
	projectiles.tick()
	advance_progression()
func advance_environment() -> void:
	spawn.tick()
func advance_progression() -> void:
	if phase != "playing":
		return
	if wall_hp <= 0:
		finish(false)
	elif can_win():
		finish(true)
	else:
		loot.advance()
		if phase == "playing":
			choices.advance()

func can_win() -> bool:
	return spawn.is_complete() and loot.queue.is_empty() and loot.current.is_empty()
func finish(success: bool) -> void:
	result_level = level_id
	if phase == "result":
		return
	result = Result.make(self, snapshot(), success)
	won = success
	phase = "result"
	paused = false
	offers.clear()
	pending.clear()
	missiles.clear()
	loot.reset()
	if success:
		for u: Dictionary in units.values():
			if u.side == 2:
				u.dead = true
	events.append({"type": "finished", "won": success, "level": level_id})
func snapshot() -> Dictionary: return Snapshot.make(self)
func drain_events() -> Array:
	var result = events.duplicate(true)
	events.clear()
	return result
func note(code: String) -> void: diagnostics[code] = int(diagnostics.get(code, 0)) + 1
func cue(kind: String, pos: Vector2, data: Dictionary = {}) -> void:
	var value = data.duplicate(true)
	value.merge({"kind": kind, "pos": pos, "start": time_ms, "expires": time_ms + int(data.get("duration", 600))}, true)
	visuals.append(value)
	if visuals.size() > 200:
		visuals.pop_front()
func dispose() -> void:
	for module in [factory, spawn, choices, ai, damage, skills, projectiles, statuses, upgrades, targets, guard, passives, space, navigation, loot]:
		module.w = null
	if gems != null:
		gems.w = null
	projectiles.effects.w = null
	projectiles.motion.w = null
	projectiles.factory.w = null
	for module in [skills.fire, skills.fireball, skills.thorns, skills.ice, skills.assassination]:
		module.w = null
	skills.actions.w = null
	damage.mitigation.w = null
	damage.traits.w = null
	damage.protection.w = null
	units.clear()
	equipment = null
	gems = null
	core = null
